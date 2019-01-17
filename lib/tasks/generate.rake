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
  task :profit_and_loss_summary, [ :filename, :summary_filename, :month ] => :environment do |t, args|
    filename = File.expand_path(args[:filename])
    summary_filename = File.expand_path(args[:summary_filename])
    month_index = args[:month].to_i + 1
    rows = CSV.parse(File.read(filename))
    summary = YAML.load_file(summary_filename)
    year = rows[2][1]
    month = rows[3][month_index]
    month_time = Chronic.parse("#{month} #{year}")

    profit_row = rows.pop

    puts <<-EOF
# Financials #{month_time.strftime("%B %Y")}
A breakdown of our finances for the month.

## Summary

The following reflect the overall status of the finances at the end of the month.

EOF
    summary["summary"].each do |category, lines|
      puts "### *#{category}*: £#{lines.values.reduce(:+)}"
      lines.each do |key, val|
        puts "- #{key}: £#{val}"
      end
      puts
    end

    puts <<-EOF

## Notes of interest

#{summary["notes"] || "None specified."}

## Income/Outgoings

EOF

    first = true
    rows[5..rows.length].each do |row|
      if row[0].nil?
        puts
      elsif row[month_index]
        if first || row[0].to_s.match(/^(add |less )/)
          print "### "
          first = false
        else
          print "- "
        end
        puts "#{row[0]}: £#{ActiveSupport::NumberHelper.number_to_delimited(row[month_index])}"
      end
    end
    puts "### *#{profit_row[0]}*: £#{ActiveSupport::NumberHelper.number_to_delimited(profit_row[month_index])}"
    puts <<-EOF

This report is based on an export from a FreeAgent Profit & Loss report which shows figures based on invoices sent rather than funds received, as such it should only be used as an indication rather than an accurate report of DoES Liverpool's income and outgoings.

> Monthly Operating Profit excludes Depreciation and Income/Corporation Taxes

Generated from a FreeAgent report exported on #{File.stat(filename).ctime}, also summary `#{File.basename(summary_filename)}`
EOF
  end

end
