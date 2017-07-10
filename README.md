# README

# financial-report
A rails app for generating some numbers to go in a financial report.

This README would normally document whatever steps are necessary to get the
application up and running.

**Work in progress** 

## Set up

1. `bundle install`
1. `rake db:migrate`
1. `bin/rails server`
1. `rake import:freeagent ~/Downloads/company-export-2017-06-30-10-14.xls`
1. `rake process:invoices`

Then visit [http://localhost:3010/reports/desks?descriptions=Permanent%20Desk,Hot%20Desk,Monthly%20Hot%20Desk%20with%20storage&skiplast=1&showlast=12](http://localhost:3010/reports/desks?descriptions=Permanent%20Desk,Hot%20Desk,Monthly%20Hot%20Desk%20with%20storage&skiplast=1&showlast=12)




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
