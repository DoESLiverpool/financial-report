require 'test_helper'

class ProductVolumesCalculatorTest < ActiveSupport::TestCase
  setup do
    @result = ProductVolumesCalculator.new(
      start_date: Date.new(2025, 9, 1),
      end_date: Date.new(2026, 8, 31)
    ).call
  end

  def row(category, unit = nil)
    @result.rows.find { |r| r.category == category && r.unit == unit }
  end

  test "counts invoiced units from the quantity on positive line items" do
    assert_equal 12, row("Friend", "Months").units_invoiced
    assert_equal 120, row("Friend", "Months").value_received
  end

  test "counts unpaid sent invoices as invoiced but not as paid" do
    desk = row("Monthly Desk", "Months")
    # 2 paid months + 1 paid month typed as Services + 1 month never paid
    assert_equal 4, desk.units_invoiced
    assert_equal 3, desk.units_paid
    assert_equal 645, desk.value_received
  end

  test "excludes cancelled and draft invoices from both counts" do
    # The cancelled invoice carries 9 desk-months, the draft 5 mailbox-months.
    assert_equal 4, row("Monthly Desk", "Months").units_invoiced
    assert_equal 3, row("Mailbox", "Months").units_invoiced
  end

  test "excludes invoices dated outside the period" do
    # The out-of-range invoice carries 99 desk-months.
    assert_equal 4, row("Monthly Desk", "Months").units_invoiced
  end

  test "keeps discount lines out of the unit count and reports them separately" do
    desk = row("Monthly Desk", "Months")
    assert_equal 3, desk.units_paid, "discount line must not be counted as a desk-month"
    assert_equal(-15, desk.discounts)
  end

  test "folds non-duration item types into the category's dominant unit" do
    # The Services line is one desk, not a separate "Services" product.
    assert_nil row("Monthly Desk", "Services")
    assert_equal 3, row("Monthly Desk", "Months").units_paid
  end

  test "keeps genuinely different units apart rather than summing them" do
    assert_equal 1, row("Mailbox", "Years").units_paid
    assert_equal 3, row("Mailbox", "Months").units_paid
    assert_equal 149, row("Mailbox", "Years").value_received
    assert_equal 45, row("Mailbox", "Months").value_received
  end

  test "uses 'each' when a category has no duration item type" do
    assert_equal 1, row("Key Deposit", "each").units_paid
  end

  test "converts uninvoiced money to implied units where a price is set" do
    friend = row("Friend", "Months")
    assert_equal 20, friend.value_uninvoiced
    assert_equal 2, friend.implied_units
    assert_equal 14, friend.total_units
  end

  test "attributes implied units to the highest-value unit of the category" do
    assert_equal 30, row("Mailbox", "Years").value_uninvoiced
    assert_equal 2, row("Mailbox", "Years").implied_units
    assert_equal 3, row("Mailbox", "Years").total_units
    assert_equal 0, row("Mailbox", "Months").value_uninvoiced
    assert_nil row("Mailbox", "Months").implied_units
  end

  test "still counts units for a category with no unit price" do
    event = row("Event Hire", "Days")
    assert_equal 2, event.units_invoiced
    assert_equal 2, event.units_paid
    assert_equal 240, event.value_received
    assert_equal 60, event.value_uninvoiced
    assert_equal 300, event.value_total
  end

  test "implies no units for a category with no unit price" do
    event = row("Event Hire", "Days")
    assert_nil event.unit_price
    assert_nil event.implied_units, "money must not be converted without a price to divide by"
    assert_nil event.total_units
  end

  test "reports a category with no invoiced units as money only" do
    other = row("Other")
    assert_nil other.unit
    assert_nil other.units_invoiced
    assert_nil other.units_paid
    assert_nil other.implied_units
    assert_equal 77, other.value_total
  end

  test "itemises the descriptions that fell into Other" do
    assert_equal [["Some Random Transfer", 1, 77]],
      @result.other_breakdown.map { |d| [d.description, d.count, d.value.to_i] }
  end

  test "excludes fiscal host money from both sides" do
    assert_nil row("Fiscal Host Funds")
    assert_nil row("Fiscal Host Funds", "Months")
  end

  test "excludes internal transfers, outgoings and out-of-period bank entries" do
    # Would otherwise add 5000 + 999 of income and 500 of fiscal holding.
    assert_equal 187, @result.rows.sum { |r| r.value_uninvoiced }
  end

  test "totals the income it counted and the income the bank actually saw" do
    assert_equal 1436, @result.total_counted
    assert_equal 1421, @result.total_bank_income
  end

  test "reports the unpaid, cancelled and draft tail" do
    assert_equal 1, @result.unpaid[:sent][:count]
    assert_equal 215, @result.unpaid[:sent][:value]
    assert_equal 1935, @result.unpaid[:cancelled][:value]
    assert_equal 75, @result.unpaid[:draft][:value]
  end

  test "flags uninvoiced money sitting in categories with no price" do
    flagged = @result.unpriced_with_uninvoiced
    assert_equal [ "Other", "Event Hire" ], flagged.map(&:first), "largest amount first"
    assert_equal [ 77, 60 ], flagged.map { |_category, value| value }
    refute_includes flagged.map(&:first), "Friend", "Friend has a price, so its money is converted"
  end

  test "flags priced categories whose implied units are attributed ambiguously" do
    assert_includes @result.multi_unit_priced, "Mailbox"
    refute_includes @result.multi_unit_priced, "Friend"
  end

  # Mailbox sells 1 year at 149 and 3 months at 15, but carries a single 15
  # price, so the money implies ~13 units against the 4 actually counted.
  test "flags a unit count that disagrees with the money" do
    mismatch = @result.price_mismatches.find { |category, _, _| category == "Mailbox" }
    assert mismatch, "expected Mailbox to be flagged"
    assert_equal 4, mismatch[1]
    assert_in_delta 12.93, mismatch[2], 0.01
  end

  test "does not flag a category whose units and money agree" do
    refute_includes @result.price_mismatches.map(&:first), "Friend"
    refute_includes @result.price_mismatches.map(&:first), "Monthly Desk"
  end

  test "marks only one unit per category as the one the price applies to" do
    mailbox = @result.rows.select { |r| r.category == "Mailbox" }
    assert_equal 1, mailbox.count(&:main_unit)
    assert_equal "Years", mailbox.find(&:main_unit).unit, "the highest-value unit"
  end

  test "defaults to the twelve complete months before the current month" do
    travel_to Date.new(2026, 9, 17) do
      assert_equal Date.new(2025, 9, 1), ProductVolumesCalculator.default_start_date
      assert_equal Date.new(2026, 8, 31), ProductVolumesCalculator.default_end_date
    end
  end
end
