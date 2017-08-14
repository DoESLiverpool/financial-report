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
    book = Spreadsheet.open(filename)

    if sheets.include?("entries")
      bank_account_entries_sheet = book.worksheet "Bank Account Entries"
      bank_account_count = 0
      progress = ProgressBar.create(total: bank_account_entries_sheet.rows.length)
      progress.increment
      bank_account_entries_sheet.each 1 do |row|
        bank_account_count += 1
        entry = BankAccountEntry.new
        entry.bank_account_name = row[0]
        entry.description = row[1]
        entry.date = row[2]
        entry.entry_type = row[3]
        entry.gross_value = row[4]
        entry.sales_tax_rate = row[7]
        entry.save!
        progress.increment
      end
      puts "Found #{bank_account_count} bank account entries"
    end

    if sheets.include?("invoices")
      invoices_sheet = book.worksheet "Invoices"
      active_invoice = nil
      invoices_count = 0
      invoice_items_count = 0
      progress = ProgressBar.create(total: invoices_sheet.rows.length)
      progress.increment
      invoices_sheet.each 1 do |row|
        progress.increment

        if row[0].nil? or row[0].length == 0
          if active_invoice.nil?
            next
          end
          invoice_items_count += 1
          item = InvoiceItem.new
          item.invoice = active_invoice
          item.item_type = row[11]
          item.quantity = row[12]
          item.price = row[13]
          item.description = row[14]
          item.sales_tax_rate = row[15]
          item.subtotal = row[16]
          item.save!
        else
          invoices_count += 1
          active_invoice = Invoice.new
          active_invoice.contact = row[0]
          active_invoice.project = row[1]
          active_invoice.reference = row[2]
          active_invoice.date = row[3]
          active_invoice.payment_terms_in_days = row[4]
          active_invoice.status = row[5]
          active_invoice.currency = row[6]
          active_invoice.comments = row[7]
          active_invoice.net_amount = row[8]
          active_invoice.sales_tax_amount = row[9]
          active_invoice.total_value = row[10]
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
  end
end
