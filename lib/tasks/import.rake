require 'csv'
namespace :import do

#  class ExcelBankAccountEntry < Importex::Base
#    column "Bank Account Name", :required => true
#    column "Description", :required => true
#    column "Date", :type => Date, :required => true
#    column "Type", :required => true
#    column "Gross Value", :format => /^\d+\.\d\d$/, :required => true
#    column "Sales Tax Rate", :type => Integer
#  end

  desc "Import from a FreeAgent export to the database"
  task :freeagent => :environment do |t, args|
    filename = File.expand_path(ARGV[1])
    sheets = ["entries", "invoices"]
    if ARGV[2]
      sheets = ARGV[2].split /,/
    end
    puts "Reading #{sheets.length > 0 ? sheets.join(", ") : "everything"} from #{filename}"
    book = Roo::Spreadsheet.open(filename)

    if sheets.include?("entries")
      bank_account_entries_sheet = book.sheet "Bank Account Entries"
      bank_account_count = 0
      progress = ProgressBar.create(total: bank_account_entries_sheet.count)
      progress.increment
      skipped_first = false
      bank_account_entries_sheet.each(account_name: "Bank Account Name", description: "Description", date: "Date", entry_type: "Type", gross_value: "Gross Value", sales_tax_rate: "Sales Tax Rate") do |row|
        unless skipped_first
          skipped_first = true
          next
        end
        bank_account_count += 1
        entry = BankAccountEntry.new
        entry.bank_account_name = row[:account_name]
        entry.description = row[:description]
        entry.date = row[:date]
        entry.entry_type = row[:entry_type]
        entry.gross_value = row[:gross_value]
        entry.sales_tax_rate = row[:sales_tax_rate]
        entry.save!
        progress.increment
      end
      puts "Found #{bank_account_count} bank account entries"
    end

    if sheets.include?("invoices")
      invoices_sheet = book.sheet "Invoices"
      active_invoice = nil
      invoices_count = 0
      invoice_items_count = 0
      progress = ProgressBar.create(total: invoices_sheet.count)
      progress.increment
      skipped_first = false
      contact_organisation_header = invoices_sheet.cell(1,1)
      contact_name_header = contact_organisation_header == "Contact" ? "Contact" : "Contact Name"
      invoices_sheet.each(
        contact_organisation: contact_organisation_header,
        contact_name: contact_name_header,
        item_type: "Item Type",
        quantity: "Quantity",
        price: "Price",
        description: "Description",
        sales_tax_rate: "Sales Tax Rate",
        subtotal: "Subtotal",
        reference: "Reference",
        date: "Date",
        payment_terms_in_days: "Payment Terms In Days",
        status: "Status",
        currency: "Currency",
        comments: "Comments",
        net_amount: "Net Amount",
        sales_tax_amount: "Sales Tax Amount",
        total_value: "Total Value"
        ) do |row|
        unless skipped_first
          skipped_first = true
          next
        end
        progress.increment

        contact = row[:contact_organisation] || ""
        contact_name = row[:contact_name] || ""
        if contact.length > 0 and contact_name.length > 0
          contact += " - "
        end
        contact += contact_name

        if contact.length == 0
          if active_invoice.nil?
            raise Error.new, "Invoice item without invoice! #{row.inspect}"
            next
          end
          invoice_items_count += 1
          item = InvoiceItem.new
          item.invoice = active_invoice
          item.item_type = row[:item_type]
          item.quantity = row[:quantity]
          item.price = row[:price]
          item.description = row[:description]
          item.sales_tax_rate = row[:sales_tax_rate]
          item.subtotal = row[:subtotal]
          item.save!
        else
          invoices_count += 1
          active_invoice = Invoice.new
          active_invoice.contact = contact
          active_invoice.reference = row[:reference]
          active_invoice.date = row[:date]
          active_invoice.payment_terms_in_days = row[:payment_terms_in_days]
          active_invoice.status = row[:status]
          active_invoice.currency = row[:currency]
          active_invoice.comments = row[:comments]
          active_invoice.net_amount = row[:net_amount]
          active_invoice.sales_tax_amount = row[:sales_tax_amount]
          active_invoice.total_value = row[:total_value]
          active_invoice.save!
        end
      end
      puts "Found #{invoices_count} invoices with #{invoice_items_count} items"
    end
  end

  desc "Import product categories from a CSV into the database"
  task :product_categories => :environment do |t, args|
    filename = File.expand_path(ARGV[1])
    skipped_first = false
    last_category = nil
    progress = ProgressBar.create(total: nil)

    CSV.parse(File.read(filename)).each do |row|
      if !skipped_first
        skipped_first = true
        next
      end
      progress.increment

      # If the first column is empty then use the previous category
      category = nil
      if row[0].nil? || row[0].length == 0
        category = last_category
      else
        category = ProductCategory.where(name: row[0]).first
        if category.nil?
          category = ProductCategory.new
          category.name = row[0]
          category.regex = row[2]
          category.save!
        end
        last_category = category
      end

      # If the first column of the first row is empty then we can't import
      # this row
      if category
        # Check for an existing record, allows importing the same CSV repeatedly
        description = ProductCategoryDescription.where(description: row[1]).first
        if description.nil?
          description = ProductCategoryDescription.new
          description.description = row[1]
        end
        description.product_category = category
        description.save!
      end
    end
    puts
  end
end
