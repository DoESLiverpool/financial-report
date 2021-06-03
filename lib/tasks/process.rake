namespace :process do
  desc "Process invoices to match them to bank transactions"
  task invoices: :environment do
    invoices_hash = {}
    Invoice.all.each do |invoice|
      invoices_hash[invoice.reference] = invoice
    end

    count = 0
    entries = BankAccountEntry.all
    progress = ProgressBar.create(total: entries.length)
    entries.each do |entry|
      matches = entry.description.match(/Invoice receipt against (.*)/)
      if matches
        invoice = invoices_hash[matches[1]]
        invoice.bank_account_entry = entry
        invoice.save!
        entry.invoice = invoice
        entry.save!

        count += 1
      end
      progress.increment
    end

    print "Matched up #{count} entries and invoices"
  end

end
