class ReportsController < ApplicationController
  def categories
    @title = "Product Category Monthly Income"
    @product_category = ProductCategory.where(name: params[:product_category]).first

    @product_categories = ProductCategory.all

    if @product_category.nil?
      return
    end

    @view_type = params[:view_type] || "total"

    # Hash of YYYYMM -> count of items for that month
    @counts = {}
    # Hash of YYYYMM -> count of items for that month that have been paid for
    @paid_counts = {}
    min_date = nil
    descriptions = @product_category.product_category_descriptions.map {|pcd| pcd.description}
    InvoiceItem.where(description: descriptions).each do |item|
      if item.invoice.status != "Sent"
        next
      end
      if min_date.nil? or min_date > item.invoice.date
        min_date = item.invoice.date
      end
      yearmonth = item.invoice.date.strftime("%Y%m")
      if @counts[yearmonth].nil?
        @counts[yearmonth] = 0
        @paid_counts[yearmonth] = 0
      end

      value = @view_type == "total" ? item.subtotal.to_f : 1
      @counts[yearmonth] += value
      if ! item.invoice.bank_account_entry_id.nil?
        @paid_counts[yearmonth] += value
        puts "#{yearmonth}  PAID  #{item.invoice.contact} #{item.description}"
      else
        puts "#{yearmonth} UNPAID #{item.invoice.contact} #{item.description}"
      end
    end

    # Hash of count -> the last month in which the count was at this level
    @last_months = {}
    # Hash of YYYYMM -> YYYYMM (current month -> last month with same count)
    @month_lasts = {}
    @ordered_months = []

    # if min_date is nil then we have no data
    while min_date
      yearmonth = min_date.strftime("%Y%m")
      @ordered_months << yearmonth
      if @counts[yearmonth].nil?
        @counts[yearmonth] = 0
        @paid_counts[yearmonth] = 0
      end
      if @last_months[@counts[yearmonth]]
        @month_lasts[yearmonth] = @last_months[@counts[yearmonth]]
      else
        @month_lasts[yearmonth] = ""
      end
      @last_months[@counts[yearmonth]] = yearmonth
      if min_date > Date.today
        break
      end
      min_date = min_date >> 1
    end

    begin
      skiplast = Integer(params[:skiplast])
    rescue Exception
      skiplast = 0
    end
    begin
      showlast = Integer(params[:showlast])
    rescue Exception
      showlast = 0
    end

    @ordered_months = @ordered_months.take(@ordered_months.length-skiplast)
    if showlast > 0 and showlast < @ordered_months.length
      @ordered_months = @ordered_months.drop(@ordered_months.length-showlast)
    end

    respond_to do |format|
      format.html
      format.xls {
        book = Spreadsheet::Workbook.new
        sheet = book.create_worksheet name: "Items"
        sheet.update_row 0, "Month", "Count", "Paid Count"
        @ordered_months.each_index do |i|
          yearmonth = @ordered_months[i]
          sheet.update_row i+1, yearmonth, @counts[yearmonth], @paid_counts[yearmonth]
        end
        file_contents = StringIO.new
        book.write file_contents
        render body: file_contents.string
      }
    end
  end

  def service_users
    @title = "Service Users by Category"
    @categories = params[:categories] || []
    @categories = @categories.map { |c| c = c.to_i }
    @invoice_status = params[:invoice_status] || "Sent"

    begin
      @start_date = Date.parse(params[:start_date])
    rescue Exception
      @start_date = Invoice.minimum(:date)
    end
    begin
      @end_date = Date.parse(params[:end_date])
    rescue Exception
      @end_date = Date.today
    end

    #select contact, date from invoices where date > '2016-08-01' and  id in (select invoice_id from invoice_items where description = 'Registered Business Address and Mailbox');

    @invoices = Invoice.where(["`date` >= ? AND `date` <= ? AND status = ? AND id IN (SELECT invoice_id FROM invoice_items WHERE description IN ( SELECT description FROM product_category_descriptions WHERE product_category_id IN ( ? ) ) )", @start_date, @end_date, @invoice_status, @categories ]).order(`date DESC`).group(:contact)

  end

  def income_distribution
    @title = "Income Distribution"

    categories_calculator = CategoriesCalculator.new
    exclusions = params[:exclusions] || []

    start_date = params[:all_time].nil? ? params[:start_date] : nil
    end_date = params[:all_time].nil? ? params[:end_date] : nil

    begin
      @start_date = Date.parse(start_date)
    rescue Exception
      @start_date = Invoice.minimum(:date)
    end
    begin
      @end_date = Date.parse(end_date)
    rescue Exception
      @end_date = Date.today
    end

    @totals = {}
    @bank_accounts = BankAccountEntry.distinct.pluck(:bank_account_name)
    @bank_accounts.unshift("All")

    if params[:bank_account].nil?
      @categories = []
      @periods = []
      return
    end

    UnknownCategory.delete_all
    periods_hash = {}
    scope = BankAccountEntry.includes(invoice: :invoice_items).where(["description NOT LIKE 'Transfer from %' AND entry_type != 'Payment to Director Loan Account' AND bank_account_entries.`date` >= ? AND bank_account_entries.`date` < ?", @start_date, @end_date])
    if params[:bank_account] != "All"
      scope = scope.where(["bank_account_name = ?", params[:bank_account]])
    end
    scope.each do |entry|
      if entry.gross_value < 0
        next
      end
      value_items = []
      if entry.invoice && entry.invoice.invoice_items.length > 0
        invoice_total = entry.invoice.invoice_items.reduce(0) do
          |sum, item|
          sum + item.subtotal
        end
        entry.invoice.invoice_items.each do |item|
          # Assign a proportional amount of the bank entry to this
          # item's category, should usually be the same as the item
          # subtotal but covers where the currency differs or
          # if this entry only covers part of the invoice
          category_name = categories_calculator.find_category(item.description, entry.gross_value)
          proportional_value = (item.subtotal / invoice_total) * entry.gross_value
          value_items << { category: category_name, value: proportional_value, description: item.description }
        end
      else
        category_name = categories_calculator.find_category(entry.description, entry.gross_value)
        value_items << { category: category_name, value: entry.gross_value, description: entry.description }
      end
      period = AccountingPeriod.which(entry.date).description
      periods_hash[period] = 1
      value_items.each do |item|
        # category_name = categories_calculator.find_category(item[:category], item[:value])
        category_name = item[:category]
        value = item[:value]
        if exclusions.include?(category_name)
          next
        end
        if @totals[category_name].nil?
          @totals[category_name] = {"Total" => 0}
        end
        if @totals[category_name][period].nil?
          @totals[category_name][period] = 0
        end
        @totals[category_name][period] += value
        @totals[category_name]["Total"] += value
      end
    end
    @categories = @totals.keys
    @periods = periods_hash.keys.sort
  end
end
