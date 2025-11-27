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
    month_year = rows[2][1]
    month_time = Date.parse(month_year)

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
    rows[4..rows.length].each do |row|
      if row[0].nil?
        puts
      elsif row[month_index]
        if first || row[0].to_s.match(/^(add |less |Gross )/)
          print "### "
          first = false
        else
          print "- "
        end
        puts "#{row[0]}: #{ActiveSupport::NumberHelper.number_to_currency(row[month_index], unit: "£", precision: 0)}"
        # Making sure t
        category_detail = summary_detail[row[0]] || {}
        category_detail.keys.sort.each do |k|
          puts "    * #{k}: #{ActiveSupport::NumberHelper.number_to_currency(category_detail[k], unit: "£")}"
        end
      end
    end
    puts "### *#{profit_row[0]}*: #{ActiveSupport::NumberHelper.number_to_currency(profit_row[month_index], unit: "£", precision: 0)}"
    puts <<-EOF

Generated from a FreeAgent report exported on #{File.stat(filename).ctime}, also summary `#{File.basename(summary_filename)}`

More information about this [[FinancialsReport]]

#{links}
EOF
  end

  desc "Generate 'Cost of Doing Epic' poster"
  task :cost_of_doing_epic_poster, [ :filename, :start_date, :end_date ] => :environment do |t, args|
    filename = File.expand_path(args[:filename])
    rows = CSV.parse(File.read(filename))
    year = rows[2][1]
    categories_hash = {}
    ProductCategoryDescription.all.each do |pcd|
      category = pcd.product_category.name
      categories_hash[pcd.description] = category
    end
    begin
      @start_date = Date.parse(args[:start_date])
    rescue Exception
      @start_date = Invoice.minimum(:date)
    end
    begin
      @end_date = Date.parse(args[:end_date])
    rescue Exception
      @end_date = Date.today
    end

    # Work out which column has the totals
    total_col = rows[2].find_index("Total")

    profit_row = rows.pop

    # Collect the set of outgoings
    @outgoings_split = {}
    first = true
    in_an_outgoing_category = false
    rows[4..rows.length].each do |row|
      if row[0].nil?
        # Blank lines mean we've got to the end of a category
        in_an_outgoing_category = false
      elsif row[total_col]
        if first || row[0].to_s.match(/^(add |less )/)
          first = false
          if row[0].to_s.match(/^less/)
            in_an_outgoing_category = true
          else
            in_an_outgoing_category = false
          end
        else
          if in_an_outgoing_category
            @outgoings_split[row[0]] = Float(row[total_col].gsub(',',''))
          end
        end
      end
    end
    STDERR.puts "outgoings:"
    STDERR.puts @outgoings_split

    @income_split = {}
    InvoiceItem.joins(:invoice).where(["`date` >= ? AND `date` < ?", @start_date, @end_date]).each do |item|
      category_name = categories_hash[item.description]
      if item.subtotal < 0
        STDERR.puts "Skipping "+item.inspect
        next
      end
      STDERR.puts "Unknown category: #{item.description} #{item.subtotal}"
      if category_name.nil?
        category_name = "Uncategorized"
      end
      if @income_split[category_name].nil?
        @income_split[category_name] = 0.0
      end
      @income_split[category_name] += Float(item.subtotal)
    end

    # Find totals for incomings and outgoings based on money in or out of the bank
    # rather than invoices raised
    @total_incoming = 0.0
    @total_outgoings = 0.0
    BankAccountEntry.where(["`date` >= ? AND `date` < ?", @start_date, @end_date]).each do |item|
      if item.entry_type.match?("Transfer.*Another Account")
        next
      end
      if Float(item.gross_value) > 0
        # Money in!
        #STDERR.puts item.inspect
        @total_incoming += Float(item.gross_value)
      else
        #STDERR.puts item.inspect
        @total_outgoings += -1*Float(item.gross_value)
      end
    end

    # Combine the two mailbox categories
    if @income_split["Mailbox - Monthly Payment"]
        if @income_split["Mailbox"]
            @income_split["Mailbox"] += @income_split["Mailbox - Monthly Payment"]
        else
            @income_split["Mailbox"] = @income_split["Mailbox - Monthly Payment"]
        end
        @income_split.delete("Mailbox - Monthly Payment")
    end
    # Roll the smaller items into an "other" category
    other_income_split, wanted_income_split = @income_split.partition { |k, v| v < @total_incoming/80 }
    @income_split = wanted_income_split.to_h
    @income_split["Other"] = 0
    @income_split["Other"] += other_income_split.to_h.values.sum unless other_income_split.empty?
    @income_split["Other"] += @income_split["Uncategorized"] unless @income_split["Uncategorized"].nil?
    @income_split.delete("Uncategorized")
    other_outgoings_split, wanted_outgoings_split = @outgoings_split.partition { |k, v| v < @total_outgoings/30 }
    @outgoings_split = wanted_outgoings_split.to_h
    @outgoings_split["Other"] = 0
    @outgoings_split["Other"] += other_outgoings_split.to_h.values.sum unless other_outgoings_split.empty?
    @outgoings_split["Other"] += @outgoings_split["Uncategorized"] unless @outgoings_split["Uncategorized"].nil?
    @outgoings_split.delete("Uncategorized")
    # Fix up a couple of names
    unless @outgoings_split["Internet & Telephone"].nil?
        @outgoings_split["Internet &amp; Telephone"] = @outgoings_split["Internet & Telephone"]
        @outgoings_split.delete("Internet & Telephone")
    end
    unless @outgoings_split["Office Costs"].nil?
        @outgoings_split["Office Costs<br/>(inc. Rates)"] = @outgoings_split["Office Costs"]
        @outgoings_split.delete("Office Costs")
    end

    # Work out split of invoices based on categories in @income_split
    @total_income_split = @income_split.values.sum
    @processed_incomings = @income_split.transform_values do |value|
        (value / @total_income_split) * @total_incoming
    end
    @total_processed_incoming = @processed_incomings.values.sum
    # And similarly for outgoings
    @total_outgoings_split = @outgoings_split.values.sum
    @processed_outgoings = @outgoings_split.transform_values do |value|
        (value / @total_outgoings_split) * @total_outgoings
    end
    @total_processed_incoming = @processed_incomings.values.sum

    # Convert them to a-month's-worth of values
    one_month_multiplier = 31/(@end_date - @start_date).to_f
    @monthly_incomings = @processed_incomings.transform_values { |v| v*one_month_multiplier }
    @monthly_outgoings = @processed_outgoings.transform_values { |v| v*one_month_multiplier }
    @total_monthly_incomings = @monthly_incomings.values.sum
    @total_monthly_outgoings = @monthly_outgoings.values.sum

    # Work out the correct multiplier for their height in the CSS.  We're assuming that the
    # graph will take up 100vw (so the same as the width of the screen, or 71% of the height
    # given our #poster element styling)
    @highest_bar = [@total_monthly_incomings, @total_monthly_outgoings].max
    @scale_graph_multiplier = 90.0/@highest_bar

    STDERR.puts "@monthly_incomings:"
    STDERR.puts @monthly_incomings
    STDERR.puts "@monthly_outgoings:"
    STDERR.puts @monthly_outgoings
    STDERR.puts "@total_monthly_incomings:"
    STDERR.puts @total_monthly_incomings
    STDERR.puts "@total_monthly_outgoings:"
    STDERR.puts @total_monthly_outgoings
    STDERR.puts "@scale_graph_multiplier:"
    STDERR.puts @scale_graph_multiplier
    STDERR.puts
    STDERR.puts "For the website version, strip out the <head> and <body> tags, and past it into the code"
    STDERR.puts "section of the Cost of Doing Epic page"

    puts <<-EOF
<!DOCTYPE html>
<html>
<head>
<style>
    body { font-family: "Transport New", sans-serif; background: #fff; font-size: 1.5vw }
    h1 { text-align: left; font-size: 14vw; margin: 2vw 0; }
    #parameters { background-color: #ddd; border: thin solid black; padding: 1em; }
    div#poster {
        width: calc(100vw-2em);
        height: calc(1.4142857142857144*calc(100vw-2em));
        background: #fff;
        margin: 1em;
        padding: 1em;
    }
    .timestamp { text-align: right; font-size: 1vw }
    .bars {
        display: grid;
        grid-template-columns: 1fr 1fr;
        justify-items: stretch;
        align-items: end;
        column-gap: 5%;
    }
    .expenses-bar {
        display: grid;
        align-items: stretch;
        justify-items: stretch;
        grid-template-rows:
EOF
    @monthly_outgoings.each do |item|
      puts "        calc(#{item[1].round(0)}*#{@scale_graph_multiplier}vw)"
    end
    puts <<-EOF
            5vw;
    }
    .income-bar {
        display: grid;
        align-items: stretch;
        justify-items: stretch;
        grid-template-rows:
EOF
    @monthly_incomings.each do |item|
      puts "        calc(#{item[1].round(0)}*#{@scale_graph_multiplier}vw)"
    end
    puts <<-EOF
            5vw;
    }
    /* For now, just go with two colours, one for income and one for expenses */
    div.e { background-color: #ad0027; }
    div.i { background-color: #64c673; }
    /* Colours generated with https://medialab.github.io/iwanthue/ */
    /*div.e0 { background-color: #ad0027; }
    div.e1 { background-color: #ff9097; }
    div.e2 { background-color: #ff6442; }
    div.e3 { background-color: #ff065c; }
    div.e4 { background-color: #6e0e39; }
    div.e5 { background-color: #763800; }
    div.e6 { background-color: #691226; }
    div.e7 { background-color: #d9347a; }
    div.e8 { background-color: #c36f5c; }
    div.i0 { background-color: #64c673; }
    div.i1 { background-color: #cfa83f; }
    div.i2 { background-color: #45bc8d; }
    div.i3 { background-color: #9d8539; }
    div.i4 { background-color: #91b23e; }
    div.i5 { background-color: #5e8d3d; }*/
    div.caption { border: none; background-color: #fff; color: #000 }
    .item { border: 1px solid #fff; background-color: #f00; color: #fff; text-align: center; align-content: center }
    #content {
        display: grid;
        grid-template-columns: 1fr 1fr;
        justify-items: stretch;
        align-items: start;
        column-gap: 5%;
    }
    /* Tweaks for better printing (and to work round Queen Victoria's quirks) */
    @media print {
        body { border-top: 1px solid #fefefe; }
        div.e { background-color: #f00 !important; }
        div#poster { padding: 5em 1em 1em 1em; }
    }
    /* Tweaks for a version that's included on the website */
    /* (relies on us pasting it into the <div class="entry-content"> element) */
    .entry-content { font-family: "Transport New", sans-serif; background: #fff; }
    .entry-content p { font-size: 1.2vw; }
    .entry-content h1 { text-align: left; font-size: 5vw; margin: 1vw 0; }
</style>
</head>
<body>
<div id="poster">
<h1>The Cost of Doing Epic</h1>
<div id="content">
    <div id="explanation">
        <p>DoES Liverpool is a Community Interest Company, <strong>funded by the members for the members</strong>.  It costs over £7000 each month to keep the space running.</p>
        <p>All the profits go back into expanding the space or getting new kit.</p>
        <h2>We Need More People Taking Desks or Workshop Membership</h2>
        <p>Last year we were running at a loss and used up almost all of our reserves.</p>
        <p>The loss has reduced compared to the previous six months Cost of Doing Epic but we're still spending more than we earn!</p>
        <p>We have plenty of spare desks and workshop capacity, so there's lots of scope for getting back to profit and building up our reserves.  Two people taking desks, for example, would get us to break-even.</p>
        <p>We also need to replace the HVAC units in the main space to give us heating (and cooling) again there.  From the quotes we've had for it, that will need us to raise around £6000.  That's why it's been a bit chilly in that room the past couple of winters, but even then our energy bills are quite high due to the alternate option of fan- and oil-heaters.</p>
        <p>Ideally we'd be steadily building up some reserves to cover the HVAC work <em>and</em> provide a buffer for unexpected expenses.</p>
        <h2>What You Can Do to Help</h2>
        <p>Use our paid services!  Take a desk if you need somewhere to work; get one of the workshop memberships and make things; book the events room for your private meetings.</p>
        <p>If you can afford it and aren't already, become a Member. It's £10/month and lets you support us financially even if you don't need the services we charge for (and if you do, you'll get a discount!).</p>
        <p>Make a one-off donation, either in one of the blue charity boxes in each room, or via Paypal on our website</p>
        <p>Tell all your friends about the great things on offer here!</p>
        <p>Visit <strong>https://doesliverpool.com/help</strong> to find out more.</p>
    </div>
    <div class="bars">
        <div class="income-bar">
EOF
    i = 0
    @monthly_incomings.each do |item|
      puts "            <div class=\"item i i#{i}\">#{item[0]}</div>"
      i += 1
    end
    puts "            <div class=\"item caption\">Monthly Income £#{@total_monthly_incomings.round(0)}</div>"
    puts "        </div>"

    puts "        <div class=\"expenses-bar\">"
    i = 0
    @monthly_outgoings.each do |item|
      puts "            <div class=\"item e e#{i}\">#{item[0]}</div>"
      i += 1
    end
    puts "            <div class=\"item caption\">Monthly Expenses £#{@total_monthly_outgoings.round(0)}</div>"
    puts <<-EOF
        </div>
    </div>
  </div>
  <div class="timestamp">Data compiled #{@end_date}</div>
</div>
</body>
</html>
EOF
  end
end
