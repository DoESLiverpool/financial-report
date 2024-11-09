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
1. `rake import:product_categories categories.csv`
1. `rake generate:accounting_periods["2011-06-10"]` (replace date with your incorporation date)

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
