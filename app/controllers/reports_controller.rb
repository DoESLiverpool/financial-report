class ReportsController < ApplicationController
  def desks
    # Hash of YYYYMM -> count of items for that month
    @counts = {}
    # Hash of YYYYMM -> count of items for that month that have been paid for
    @paid_counts = {}
    min_date = nil
    # Permanent Desk,Hot Desk,Monthly Hot Desk with storage,John McKerrell Hot desk with storage,Darryl Bayliss Hot Desk,Permanent Desk (For Student),Permanent Desk - August and September,Steven Hassall Hot Desk
    descriptions = params[:descriptions].split(/,/)
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
  end
end
