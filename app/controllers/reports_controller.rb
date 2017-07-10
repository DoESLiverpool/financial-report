class ReportsController < ApplicationController
  def categories
    product_category = ProductCategory.where(name: params[:product_category]).first

    @product_categories = ProductCategory.all

    if product_category.nil?
      return
    end
    # Hash of YYYYMM -> count of items for that month
    @counts = {}
    # Hash of YYYYMM -> count of items for that month that have been paid for
    @paid_counts = {}
    min_date = nil
    # Permanent Desk,Hot Desk,Monthly Hot Desk with storage,John McKerrell Hot desk with storage,Darryl Bayliss Hot Desk,Permanent Desk (For Student),Permanent Desk - August and September,Steven Hassall Hot Desk
    descriptions = product_category.product_category_descriptions.map {|pcd| pcd.description}
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
      @counts[yearmonth] += 1
      if ! item.invoice.bank_account_entry_id.nil?
        @paid_counts[yearmonth] += 1
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
      min_date = min_date >> 1
      if min_date > Date.today
        yearmonth = min_date.strftime("%Y%m")
        @ordered_months << yearmonth
        break
      end
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
end
