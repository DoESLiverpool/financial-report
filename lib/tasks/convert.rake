require 'csv'
class String
  def strip_money
    gsub(/[^0-9.-]/, '')
  end
end
class NilClass
  def strip_money
    nil
  end
end
namespace :convert do

  desc "Convert from a co-op transaction excel to CSV"
  task :bank_statement => :environment do |t, args|
    filename = File.expand_path(ARGV[1])
    puts "Reading from #{filename}"
    book = Roo::Spreadsheet.open(filename)

    csv_filename = "#{filename}.csv"
    csv = CSV.open(csv_filename, "w")
    csv << ["Customer:", "DOES LIVERPOOL CIC(B11UQO)"]
    transactions_sheet = book.sheet "CustomCurrentMiniStatementRepor"
    puts "#{transactions_sheet.count} rows"

    account_number = transactions_sheet.cell('B', 4).gsub(/Account: /, '')
    csv << ["Account:", "#{account_number}-DOES LIVERPOOL"]

    date_to = transactions_sheet.cell('B', 13)
    date_from = transactions_sheet.cell('B', transactions_sheet.count)
    csv << ["Date Range:", "From : #{date_from}", "To : #{date_to}"]
    csv << ["Today's Cleared Balance:", transactions_sheet.cell('I', 6).strip_money]
    csv << ["Today's Uncleared Balance:", transactions_sheet.cell('P', 6).strip_money]
    csv << ["Transactions", '', '', '', '', '', transactions_sheet.cell('I', 8)]
    csv << ["Date","Description","Bank     Reference","Customer  Reference","Credit","Debit","Additional Information","Running  Balance"]
    # Starts from B13
    (13..transactions_sheet.count).each do |row|
      debit = transactions_sheet.cell('Q', row)
      debit = debit.strip_money.to_f * -1 unless debit.nil?
      references = [
        transactions_sheet.cell('E', row),
        transactions_sheet.cell('J', row),
      ].compact.sort.join(' - ')
      csv << [
        transactions_sheet.cell('B', row),
        transactions_sheet.cell('K', row),
        references,
        references,
        (transactions_sheet.cell('N', row)||'').strip_money,
        debit,
        "#{transactions_sheet.cell('E', row)}#{transactions_sheet.cell('J', row)}",
        transactions_sheet.cell('R', row).gsub(/£ ?/, ''),
      ]
    end

<<EOF
Transaction date			Bank reference					Customer reference	Type of payment			Credit amount (GBP)			Debit amount (GBP)	Balance (GBP)
																
																
15/06/2022			THE DUNCAN REID CO					DUNCANREID	Faster Payment			£ 10.00				£ 1,583.90
EOF

    csv.close
    puts File.read(csv_filename)
  end

end
