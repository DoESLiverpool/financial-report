namespace :generate do
  desc "Generate accounting periods from an incorporation date to now"
  task :accounting_periods, [ :start_date ] => :environment do |t, args|
    start_date_string = args[:start_date]
    original_start_date = Time.parse(start_date_string)
    start_date = original_start_date
    end_date = start_date.end_of_month + 1.year
    begin
      ap = AccountingPeriod.where(start_date: start_date, end_date: end_date).first
      if ap.nil?
        ap = AccountingPeriod.new
        ap.start_date = start_date
        ap.end_date = end_date
        ap.save!
      end

      start_date = end_date + 1
      end_date = end_date + 1.year
    end while start_date < Time.now

    puts "Generated accounting periods from #{original_start_date}"
  end

  desc "Parse profit and loss and generate wiki summary"
  task :profit_and_loss_summary, [ :filename, :month ] => :environment do |t, args|
    puts args[:filename].inspect
    filename = File.expand_path(args[:filename])
    month_index = args[:month].to_i + 1
    rows = CSV.parse(File.read(filename))
    year = rows[2][1]
    month = rows[3][month_index]
    month_time = Chronic.parse("#{month} #{year}")

    profit_row = rows.pop

    puts <<-EOF
# Financials #{month_time.strftime("%B %Y")}
A breakdown of our finances for the month.

## Quick Summary

- Turnover: £#{ActiveSupport::NumberHelper.number_to_delimited(rows[5][month_index])}
- Sales: £#{ActiveSupport::NumberHelper.number_to_delimited(rows[6][month_index])}
- #{profit_row[0]}: £#{ActiveSupport::NumberHelper.number_to_delimited(profit_row[month_index])}

Overall Assets: INSERT

**Current Assets: INSERT**
- Current Account: INSERT
- Petty Cash (approximate): INSERT
- Paypal: INSERT
- Deposit Account: INSERT

**Other Assets: INSERT**
- Out of Hours Deposits: INSERT

## Notes of interest

None specified.

## Income/Outgoings

EOF

  rows[8..rows.length].each do |row|
    if row[0].nil?
      puts
    elsif row[month_index]
      puts "- #{row[0]}: £#{ActiveSupport::NumberHelper.number_to_delimited(row[month_index])}"
    end
  end
  end

end
