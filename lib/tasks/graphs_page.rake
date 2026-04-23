namespace :generate do
  desc "Generate combined graphs HTML snippet for pasting into WordPress"
  task :graphs_page => :environment do
    session = ActionDispatch::Integration::Session.new(Rails.application)

    items = [
      { text: "The following is a chart of income per DoES Liverpool accounting period, split by category." },
      { path: "/reports/income_distribution?utf8=%E2%9C%93&bank_account=All&start_date=2011-07-15&end_date=2026-04-23&exclusions%5B%5D=Fiscal+Host+Funds&export=on&all_time=All+Time" },
      { text: "The following is a chart of income per DoES Liverpool accounting period, split by category and stacked to show a percentage of income for the year." },
      { path: "/reports/income_distribution?utf8=%E2%9C%93&bank_account=All&start_date=2011-07-15&end_date=2026-04-23&stacked_percent=on&exclusions%5B%5D=Fiscal+Host+Funds&export=on&all_time=All+Time" },
      { text: "The following graphs show a category of income by month over the last 12 months." },
      { path: "/reports/categories?utf8=%E2%9C%93&product_category=Monthly+Desk&view_type=total&skiplast=1&showlast=12&export=on&commit=Show" },
      { path: "/reports/categories?utf8=%E2%9C%93&product_category=Workshop+Membership&view_type=total&skiplast=1&showlast=12&export=on&commit=Show" },
      { path: "/reports/categories?utf8=%E2%9C%93&product_category=Flexidesk&view_type=total&skiplast=1&showlast=12&export=on&commit=Show" },
      { path: "/reports/categories?utf8=%E2%9C%93&product_category=Hot+Desk+Day&view_type=total&skiplast=1&showlast=12&export=on&commit=Show" },
      { path: "/reports/categories?utf8=%E2%9C%93&product_category=Mailbox&view_type=total&skiplast=1&showlast=12&export=on&commit=Show" },
      { path: "/reports/categories?utf8=%E2%9C%93&product_category=Friend&view_type=total&skiplast=1&showlast=12&export=on&commit=Show" },
    ]

    body_parts = []

    items.each do |item|
      if item[:text]
        body_parts << "<p>#{item[:text]}</p>"
      elsif item[:path]
        STDERR.puts "Rendering #{item[:path]}..."
        session.get(item[:path], headers: { 'HOST' => 'localhost:3000' })
        unless session.response.successful?
          STDERR.puts "  Error: HTTP #{session.response.status}"
          next
        end
        body_match = session.response.body.match(/<body[^>]*>(.*?)<\/body>/m)
        if body_match
          body_parts << body_match[1].strip
        else
          STDERR.puts "  Warning: could not extract body content"
        end
      end
    end

    puts <<~HTML
      <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
      <script type="text/javascript">
        var chartLoaders = [];
        google.charts.load('current', {'packages':['corechart']});
        google.charts.setOnLoadCallback(function() {
          for (var i in chartLoaders) {
            chartLoaders[i]();
          }
        });
      </script>
      #{body_parts.join("\n")}
    HTML
  end
end
