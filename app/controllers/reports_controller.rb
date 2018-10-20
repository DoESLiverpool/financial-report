class ReportsController < ApplicationController
  def categories
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
    # Permanent Desk,Hot Desk,Monthly Hot Desk with storage,John McKerrell Hot desk with storage,Darryl Bayliss Hot Desk,Permanent Desk (For Student),Permanent Desk - August and September,Steven Hassall Hot Desk
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
    while true
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
    @categories = params[:categories] || []
    @categories = @categories.map { |c| c = c.to_i }

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

    @invoices = Invoice.where(["`date` >= ? AND `date` <= ? AND id IN (SELECT invoice_id FROM invoice_items WHERE description IN ( SELECT description FROM product_category_descriptions WHERE product_category_id IN ( #{@categories.join(", ")} ) ) )", @start_date, @end_date]).order(`date DESC`).group(:contact)

  end

  def income_distribution
    categories_hash = {}
    exclusions = params[:exclusions] || []
    ProductCategoryDescription.all.each do |pcd|
      category = pcd.product_category.name
      categories_hash[pcd.description] = category
    end

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

    @totals = {}
    periods_hash = {}
    InvoiceItem.joins(:invoice).where(["`date` >= ? AND `date` < ?", @start_date, @end_date]).each do |item|
      category_name = categories_hash[item.description]
      if exclusions.include?(category_name)
        next
      end
      if item.subtotal < 0
        next
      end
      puts "Unknown category: #{item.description} #{item.subtotal}"
      if category_name.nil?
        category_name = "Other"
      end
      period = AccountingPeriod.which(item.invoice.date).description
      periods_hash[period] = 1
      if @totals[category_name].nil?
        @totals[category_name] = {"Total" => 0}
      end
      if @totals[category_name][period].nil?
        @totals[category_name][period] = 0
      end
      @totals[category_name][period] += item.subtotal
      @totals[category_name]["Total"] += item.subtotal
    end
    @categories = @totals.keys
    @periods = periods_hash.keys.sort
  end
end
