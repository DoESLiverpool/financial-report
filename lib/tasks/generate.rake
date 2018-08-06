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

end
