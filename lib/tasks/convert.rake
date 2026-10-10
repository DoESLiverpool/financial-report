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
    transactions_sheet = book.sheet(0)
    puts "#{transactions_sheet.count} rows"

    account_number = transactions_sheet.cell('B', 4).gsub(/Account: /, '')
    csv << ["Account:", "#{account_number}-DOES LIVERPOOL"]

    # The current account and deposit account exports have different layouts,
    # so find the header row and look up the columns by their headings
    header_row = (1..transactions_sheet.last_row).find { |row| transactions_sheet.cell('B', row) == 'Transaction date' }
    columns = (transactions_sheet.first_column..transactions_sheet.last_column).each_with_object({}) do |col, hash|
      heading = transactions_sheet.cell(header_row, col)
      hash[heading] = col unless heading.nil?
    end
    col = ->(heading) { columns.fetch(heading) }
    balance_as_of_row = (1..header_row).find { |row| transactions_sheet.cell('D', row).to_s =~ /balance as of/i }
    transaction_rows = ((header_row + 1)..transactions_sheet.last_row).reject { |row| transactions_sheet.cell('B', row).nil? }

    date_to = transactions_sheet.cell('B', transaction_rows.first)
    date_from = transactions_sheet.cell('B', transaction_rows.last)
    csv << ["Date Range:", "From : #{date_from}", "To : #{date_to}"]
    csv << ["Today's Cleared Balance:", transactions_sheet.cell('I', 6).strip_money]
    csv << ["Today's Uncleared Balance:", transactions_sheet.cell('P', 6).strip_money]
    csv << ["Transactions", '', '', '', '', '', transactions_sheet.cell('I', balance_as_of_row)]
    csv << ["Date","Description","Bank     Reference","Customer  Reference","Credit","Debit","Additional Information","Running  Balance"]
    transaction_rows.each do |row|
      bank_reference = transactions_sheet.cell(row, col['Bank reference'])
      customer_reference = transactions_sheet.cell(row, col['Customer reference'])
      debit = transactions_sheet.cell(row, col['Debit amount (GBP)'])
      debit = debit.strip_money.to_f * -1 unless debit.nil?
      references = [
        bank_reference,
        customer_reference,
      ].compact.sort.join(' - ')
      csv << [
        transactions_sheet.cell('B', row),
        transactions_sheet.cell(row, col['Type of payment']),
        references,
        references,
        (transactions_sheet.cell(row, col['Credit amount (GBP)'])||'').strip_money,
        debit,
        "#{bank_reference}#{customer_reference}",
        transactions_sheet.cell(row, col['Balance (GBP)']).gsub(/£ ?/, ''),
      ]
    end

<<EOF
Transaction date			Bank reference					Customer reference	Type of payment			Credit amount (GBP)			Debit amount (GBP)	Balance (GBP)
																
																
15/06/2022			THE DUNCAN REID CO					DUNCANREID	Faster Payment			£ 10.00				£ 1,583.90
EOF

    csv.close
  end

end
