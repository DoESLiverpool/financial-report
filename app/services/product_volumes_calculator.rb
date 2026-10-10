# app/services/product_volumes_calculator.rb
#
# Counts how many of each product we sold over a period, so that next year's
# prices can be worked back from next year's costs.
#
# Units, not money, are the answer we want, and invoice line items carry a real
# quantity.  Two things get in the way:
#
#   * Not every invoice is paid, and cancelled and draft invoices aren't sales
#     at all, so units are counted twice -- once as invoiced, once as actually
#     paid for.  Paid is the headline figure; showing both makes the gap
#     visible rather than silently applying it.
#   * Plenty of income never gets invoiced.  Hot desk days in particular never
#     have an invoice raised, and a good number of Friends pay by standing
#     order.  That money is reported per category, and turned into an implied
#     number of units only where a unit price has been set on the category.
#
# Categories without a unit price aren't itemised at all -- they're reported as
# money, which is all you can say about a donation.
class ProductVolumesCalculator
  # Item types that say how much time was sold.  Anything else ('Services',
  # 'Products', '-no unit-' ...) is one of whatever the category normally
  # sells, so it folds into that category's main unit.
  DURATION_UNITS = %w[Months Years Days Hours].freeze
  UNITLESS = "each".freeze

  # Money held on behalf of others rather than earned, excluded on both sides
  # exactly as the Cost of Doing Epic poster excludes it.
  # Fiscal Host Funds is money we only hold and pass on.  The hosting fee is
  # genuinely ours, but it is a fee rather than a product, so it tells us
  # nothing about prices -- the poster still counts it as income.
  EXCLUDED_CATEGORIES = [ "Fiscal Host Funds", "Fiscal Hosting Fee" ].freeze
  # Contra account movements are money we are holding to hand back -- payments
  # made in error, awaiting refund -- rather than anything we sold.
  EXCLUDED_ENTRY_TYPES = [
    "Circular Arts Network Holding",
    "Receipt into Contra Account",
    "Payment from Contra Account"
  ].freeze
  INTERNAL_TRANSFER = /Transfer.*Another Account/

  # FreeAgent's export has no "paid" status -- the only values are Sent,
  # Cancelled and Draft -- so payment is inferred from a matched bank receipt.
  SOLD_STATUS = "Sent".freeze

  Row = Struct.new(
    :category, :unit, :units_invoiced, :units_paid, :value_received,
    :discounts, :value_uninvoiced, :unit_price, :implied_units, :total_units,
    :main_unit, keyword_init: true
  ) do
    def priced?
      !unit_price.nil?
    end

    def value_total
      value_received + value_uninvoiced
    end
  end

  OtherEntry = Struct.new(:description, :count, :value)

  Result = Struct.new(
    :start_date, :end_date, :rows, :other_breakdown, :unpaid, :total_counted,
    :total_bank_income, :unpriced_with_uninvoiced, :multi_unit_priced,
    :price_mismatches, keyword_init: true
  )

  # Below this much received, a percentage difference isn't worth reporting.
  MISMATCH_FLOOR = 100.0
  MISMATCH_TOLERANCE = 0.1

  # The twelve complete months before this one.  Whole months so a part-finished
  # month doesn't understate every recurring category, and leaving out the
  # current month also drops the invoices that simply haven't been paid yet.
  def self.default_start_date
    (Date.today << 12).beginning_of_month
  end

  def self.default_end_date
    Date.today.beginning_of_month - 1
  end

  # Both dates are inclusive.
  def initialize(start_date:, end_date:)
    @start_date = start_date
    @end_date = end_date
    @categories_calculator = CategoriesCalculator.new
    @unit_prices = ProductCategory.pluck(:name, :unit_price).to_h

    # category => unit (nil until folded) => tallies
    @tallies = Hash.new { |cats, name| cats[name] = Hash.new { |units, unit| units[unit] = new_tally } }
    @discounts = Hash.new(0.0)
    @uninvoiced = Hash.new(0.0)
    @other_descriptions = {}
  end

  def call
    tally_invoice_items
    tally_bank_entries
    fold_unitless_tallies

    rows = build_rows.sort_by { |row| -row.value_total }

    Result.new(
      start_date: @start_date,
      end_date: @end_date,
      rows: rows,
      other_breakdown: @other_descriptions.values.sort_by { |entry| -entry.value },
      unpaid: unpaid_tail,
      total_counted: rows.sum(&:value_total),
      total_bank_income: total_bank_income,
      unpriced_with_uninvoiced: rows.reject(&:priced?).select { |r| r.value_uninvoiced > 0 }
                                    .sort_by { |r| -r.value_uninvoiced }
                                    .map { |r| [ r.category, r.value_uninvoiced ] },
      multi_unit_priced: multi_unit_priced(rows),
      price_mismatches: price_mismatches(rows)
    )
  end

  private

  def new_tally
    { units_invoiced: 0.0, units_paid: 0.0, value_received: 0.0 }
  end

  def period
    @start_date..@end_date
  end

  def paid_invoice_ids
    @paid_invoice_ids ||= BankAccountEntry.where.not(invoice_id: nil).distinct.pluck(:invoice_id).to_set
  end

  def tally_invoice_items
    items = InvoiceItem.joins(:invoice).where(invoices: { date: period, status: SOLD_STATUS })

    items.includes(:invoice).find_each do |item|
      subtotal = item.subtotal.to_f
      category = @categories_calculator.find_category(item.description, item.subtotal)
      next if EXCLUDED_CATEGORIES.include?(category)

      # A negative line is a discount.  item_type isn't a reliable signal for
      # this -- most discounts are typed the same as the thing they discount --
      # but the sign always is.  Counting them as units would roughly double
      # every category that offers a member discount.
      if subtotal < 0
        @discounts[category] += subtotal
        next
      end

      paid = paid_invoice_ids.include?(item.invoice_id)
      record_other(item.description, subtotal) if paid && other?(category)

      tally = @tallies[category][unit_for(item)]
      quantity = item.quantity.to_f
      tally[:units_invoiced] += quantity
      next unless paid

      tally[:units_paid] += quantity
      tally[:value_received] += subtotal
    end
  end

  def unit_for(item)
    DURATION_UNITS.include?(item.item_type) ? item.item_type : nil
  end

  def tally_bank_entries
    entries = BankAccountEntry.where(date: period, invoice_id: nil)

    entries.find_each do |entry|
      gross = entry.gross_value.to_f
      next unless gross > 0
      next if excluded_entry_type?(entry)

      category = @categories_calculator.find_category(entry.description, entry.gross_value)
      next if EXCLUDED_CATEGORIES.include?(category)

      @uninvoiced[category] += gross
      record_other(entry.description, gross) if other?(category)
    end
  end

  def excluded_entry_type?(entry)
    entry_type = entry.entry_type.to_s
    entry_type.match?(INTERNAL_TRANSFER) || EXCLUDED_ENTRY_TYPES.include?(entry_type)
  end

  def other?(category)
    category == CategoriesCalculator::FALLBACK_CATEGORY
  end

  # Everything that lands in Other is worth seeing in full: it's the raw
  # material for improving the regexes in categories.csv.
  def record_other(description, value)
    entry = (@other_descriptions[description] ||= OtherEntry.new(description, 0, 0.0))
    entry.count += 1
    entry.value += value
  end

  # Items with no duration item type belong to whichever unit the category
  # mostly sells, otherwise a single product ends up split across three rows.
  def fold_unitless_tallies
    @tallies.each do |_category, units|
      unitless = units.delete(nil)
      next if unitless.nil?

      destination = dominant_unit(units) || UNITLESS
      tally = units[destination]
      unitless.each { |key, value| tally[key] += value }
    end
  end

  def dominant_unit(units)
    units.max_by { |_unit, tally| [ tally[:value_received], tally[:units_invoiced] ] }&.first
  end

  def build_rows
    (@tallies.keys | @uninvoiced.keys).flat_map { |category| rows_for(category) }
  end

  # Units are worth counting whether or not a price is set -- how many days the
  # events room went out for is useful even when the day rate varies too much
  # to be worth configuring.  The price only adds the implied units.
  def rows_for(category)
    units = @tallies[category]
    return [ row_for(category, nil, nil, main: true) ] if units.empty?

    main_unit = dominant_unit(units)
    units.map { |unit, tally| row_for(category, unit, tally, main: unit == main_unit) }
  end

  # Uninvoiced money and discounts belong to the category rather than to any one
  # unit, so they're attributed to its main unit -- anywhere else would double
  # count them in the totals.
  def row_for(category, unit, tally, main:)
    unit_price = @unit_prices[category]
    uninvoiced = main ? @uninvoiced[category] : 0.0
    implied = (uninvoiced / unit_price.to_f if unit_price.present? && uninvoiced > 0)
    units_paid = tally && tally[:units_paid]

    Row.new(
      category: category,
      unit: unit,
      units_invoiced: tally && tally[:units_invoiced],
      units_paid: units_paid,
      value_received: tally ? tally[:value_received] : 0.0,
      discounts: main ? @discounts[category] : 0.0,
      value_uninvoiced: uninvoiced,
      unit_price: unit_price&.to_f,
      implied_units: implied,
      total_units: (units_paid.to_f + implied.to_f if unit_price.present?),
      main_unit: main
    )
  end

  # Where a priced category sells in more than one unit, attributing its
  # uninvoiced money to the main unit is a guess worth flagging.
  def multi_unit_priced(rows)
    rows.select(&:priced?)
        .group_by(&:category)
        .select { |_category, category_rows| category_rows.length > 1 && category_rows.sum(&:value_uninvoiced) > 0 }
        .keys
  end

  # The unit count and the money ought to tell the same story: quantity times
  # price should be roughly what came in.  Where they disagree the price is out
  # of date, or the quantities don't mean what we think -- event hire bookings,
  # for instance, are sometimes logged as one unit whatever their length.
  def price_mismatches(rows)
    rows.select(&:priced?).group_by(&:category).filter_map do |category, category_rows|
      received = category_rows.sum(&:value_received)
      next if received < MISMATCH_FLOOR

      counted = category_rows.sum { |row| row.units_paid.to_f }
      next if counted.zero?

      from_value = received / category_rows.first.unit_price
      next if (from_value - counted).abs / counted <= MISMATCH_TOLERANCE

      [ category, counted, from_value ]
    end
  end

  def unpaid_tail
    invoices = Invoice.where(date: period)
    sent_unpaid = invoices.where(status: SOLD_STATUS).reject { |i| paid_invoice_ids.include?(i.id) }

    {
      sent: { count: sent_unpaid.length, value: sent_unpaid.sum { |i| i.total_value.to_f } },
      cancelled: summarise(invoices.where(status: "Cancelled")),
      draft: summarise(invoices.where(status: "Draft"))
    }
  end

  def summarise(invoices)
    { count: invoices.count, value: invoices.sum(:total_value).to_f }
  end

  # What the bank actually saw over the period, for comparison with the total
  # this report counted.  They differ: invoices are counted on their own date
  # and receipts on the date the money landed.
  def total_bank_income
    BankAccountEntry.where(date: period).where("gross_value > 0").reject { |entry| excluded_entry_type?(entry) }
                    .sum { |entry| entry.gross_value.to_f }
  end
end
