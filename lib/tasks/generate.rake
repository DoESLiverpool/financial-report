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
    summary_detail = summary["detail"] || {}
    year = rows[2][1]
    month = rows[3][month_index]
    month_time = Chronic.parse("#{month} #{year}")

    profit_row = rows.pop
    

    last_month_str = month_time.last_month.strftime("%Y%m")
    next_month_str = month_time.next_month.strftime("%Y%m")
    links = "[< Previous #{last_month_str}](Financials#{last_month_str}) | [Next #{next_month_str} >](Financials#{next_month_str})"

    puts <<-EOF
# Financials #{month_time.strftime("%B %Y")}
A breakdown of our finances for the month.

#{links}

## Summary

The following reflect the overall status of the finances at the end of the month.

EOF
    summary["summary"].each do |category, lines|
      puts "### *#{category}*: #{ActiveSupport::NumberHelper.number_to_currency(lines.values.reduce(:+), unit: "£")}"
      lines.each do |key, val|
        puts "- #{key}: #{ActiveSupport::NumberHelper.number_to_currency(val, unit: "£")}"
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
        puts "#{row[0]}: #{ActiveSupport::NumberHelper.number_to_currency(row[month_index], unit: "£")}"
        # Making sure t
        category_detail = summary_detail[row[0]] || {}
        category_detail.keys.sort.each do |k|
          puts "    * #{k}: #{ActiveSupport::NumberHelper.number_to_currency(category_detail[k], unit: "£")}"
        end
      end
    end
    puts "### *#{profit_row[0]}*: #{ActiveSupport::NumberHelper.number_to_currency(profit_row[month_index], unit: "£")}"
    puts <<-EOF

Generated from a FreeAgent report exported on #{File.stat(filename).ctime}, also summary `#{File.basename(summary_filename)}`

More information about this [[FinancialsReport]]

#{links}
EOF
  end

end
