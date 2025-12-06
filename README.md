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
1. `rake db:migrate`
1. `bin/rails server`
1. `rake import:freeagent ~/Downloads/company-export-2017-06-30-10-14.xls`
1. `rake process:invoices`
1. `rake generate:accounting_periods[start_date=2011-06-10]` (replace date with your incorporation date)
1. `rake import:product_categories categories.csv`

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

For example:
```
bundle exec rake generate:cost_of_doing_epic_poster[~/Downloads/DoES\ Liverpool\ CIC\ monthly\ profit\ and\ loss\ 2024-09-01\ to\ 2025-03-01.csv,2024-09-01,2025-03-01]
```

Some of the logging currently appears in the output, so if you redirect the output of that command to a file, open it and delete everything before the `&lt;!DOCTYPE html&gt;'

Finally, update the narrative in the explanation to reflect where things are.


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
