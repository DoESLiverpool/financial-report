# README

# financial-report
A rails app for generating some numbers to go in a financial report.

This README would normally document whatever steps are necessary to get the
application up and running.

**Work in progress** 

## Set up

1. Gather data from FreeAgent:
   1. Log into FreeAgent
   1. Go to `DoES Liverpool CIC` and then `Settings`
   1. Choose `Export All Data`, which will then give you the `company-export-YYYY-MM-DD-HH-MM.xls` file to import
1. `bundle install`
1. `bundle exec rake db:migrate`
1. `bundle exec rails server`
1. `bundle exec rake import:freeagent ~/Downloads/company-export-2017-06-30-10-14.xls`
1. `bundle exec rake process:invoices`
1. `bundle exec rake generate:accounting_periods[start_date=2011-06-10]` (This is DoES Liverpool's, replace date with your incorporation date)
1. `bundle exec rake import:product_categories categories.csv`

Then visit [http://localhost:3010/reports/categories](http://localhost:3010/reports/categories)


Your categories CSV should have a header row followed by product category name and description pairs, if the name is left blank then the previous value is used, e.g.:

```
Name,Description
Hot Desk Day,1 Hot Desk Day
,2 Hot Desk Days
,3 Hot Desk Days
Permanent Desk,Permanent Desk
,Permanent Desk for Jo
```

For internal DoES Liverpool use the `categories.csv` we use is in the private `financial-report-summaries` repository.

### Cost of Doing Epic poster

This is generated from a combination of the data in the database and a monthly profit and loss report from FreeAgent.

You will need a recent version of the data in the database.  The easiest way to do that is to re-populate it from scratch.  Delete `db/development.sqlite3` and then follow the steps in "Set up" above.

Then get the profit and loss report:
1. Log into FreeAgent
1. Go to "Accounting" then "Reports"
1. Choose the "Profit &amp; Loss" report
1. Switch to the "Monthly" option and choose a "Custom date range"
1. Enter the desired date range and choose "Apply"
1. Export the report as CSV

For example we've been using 'previous 6 complete months' so on the 23rd April we would do 1st October -> 31st March:
```
bundle exec rake generate:cost_of_doing_epic_poster[~/Downloads/DoES\ Liverpool\ CIC\ monthly\ profit\ and\ loss\ 2025-10-01\ to\ 2026-03-31.csv,2025-10-01,2026-03-31]
```

Some of the logging currently appears in the output, so if you redirect the output of that command to a file, open it and delete everything before the `&lt;!DOCTYPE html&gt;'

Finally, update the narrative in the explanation to reflect where things are.

#### Exclusions

Some transactions should be excluded from the poster as they don't represent DoES Liverpool's own income or outgoings (e.g. money held and passed on as a fiscal host). These are excluded in two ways in `lib/tasks/generate.rake`:

- `excluded_entry_types` — bank entries with these FreeAgent entry types are excluded from both the income and outgoings totals. Currently excludes `Circular Arts Network Holding`.
- `excluded_categories` — invoice items resolved to these product categories are excluded from the income proportions. Currently excludes `Fiscal Host Funds`.

If DoES Liverpool takes on further fiscal hosting arrangements, add the relevant entry type and/or category to these lists.


### Graphs page for WordPress

To generate a combined HTML snippet containing all the key graphs (income distribution charts and per-category monthly charts) ready to paste into a WordPress page:

```
bundle exec rake generate:graphs_page > graphs.html
```

This hits the reports controllers in-process (no server required) and outputs a single HTML fragment with the Google Charts library included once, text descriptions between the relevant charts, and all chart setup code combined.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
