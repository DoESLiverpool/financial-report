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

The row that names a category can carry two further columns, both optional and both
ignored on the continuation rows beneath it: a regex used to match descriptions that
aren't listed literally, and a `UnitPrice` used by the product volumes report below.

```
Name,Description,Regex,UnitPrice
Hot Desk Day,1 Hot Desk Day,(.*hot ?desk.*),14.00
,2 Hot Desk Days
,3 Hot Desk Days
Permanent Desk,Permanent Desk,(.*Permanent Desk.*),215.00
,Permanent Desk for Jo
```

Both columns are written on every import, so re-importing an older CSV that lacks them
will clear the regex and the price.

Renaming a category, or splitting one in two, is just an edit to the CSV.  The import
removes any category left with no descriptions, so the old one doesn't linger in the
database with a regex that carries on matching ahead of whatever replaced it.

Descriptions and regexes are matched against text whose runs of whitespace have been
squeezed to single spaces, so you don't have to reproduce the padding the bank puts
between names -- "Joe   Bloggs A" matches a pattern written `joe bloggs`, and a
listed description keeps matching when the statement format changes how many spaces it
uses.  Unmatched descriptions are still recorded in their original spelling.

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


### Product volumes report

How many of each product we sold over the last year, to budget with.  Take the numbers
into a spreadsheet, work out next year's costs, and divide to get the prices needed to
cover them assuming similar volumes.

```
bundle exec rake generate:product_volumes
bundle exec rake generate:product_volumes[2025-09-01,2026-08-31] > volumes.csv
```

With no arguments it covers the twelve complete months before the current month, so
running it in September 2026 reports 1st September 2025 to 31st August 2026.  Both
dates are **inclusive** (unlike the Cost of Doing Epic poster, whose end date is
exclusive).  The table is written to stdout followed by the same figures as CSV, and
everything else goes to stderr, so redirecting the output gives you a file you can
paste straight into a spreadsheet.

#### Where the numbers come from

Units are counted from the quantity on invoice line items, which is a purer figure than
dividing income by an assumed price.  Two adjustments matter:

- **Only invoices that were actually paid count as sales.**  FreeAgent's export has no
  "paid" status, so an invoice counts as paid when `process:invoices` has matched it to
  a bank receipt.  Cancelled and draft invoices are ignored entirely.  The report shows
  both `inv.units` (sent, whether or not they were paid) and `paid.units` (the headline
  figure) so you can see the size of the gap, and stderr lists the unpaid, cancelled and
  draft tail.  Expect the most recent month or two to include invoices that simply
  haven't been paid yet.
- **Plenty of income is never invoiced.**  Hot desk days almost never have an invoice
  raised, and a lot of Friends pay by standing order.  Bank entries with no invoice
  behind them are categorised the same way and reported as `uninvoiced`.  Where the
  category has a `UnitPrice` in `categories.csv`, that money is also divided by the
  price to give `implied` units, and `TOTAL` is the two added together.

Units are counted whether or not a `UnitPrice` is set -- a count of things sold is worth
having even where no single price applies.  The price only adds the `implied` and `TOTAL`
columns, so categories without one appear in a second section showing units and money
but no imputation.  Categories with no invoiced line items at all, like donations, show
money alone.

A category gets a separate row per unit where it genuinely sells in more than one:
Event Hire is booked by the day and occasionally by the hour, and adding those
quantities together would be meaningless.  Line items with no duration unit
(`Services`, `Products`, `-no unit-`) are folded into whichever unit the category mostly
sells, so one product doesn't end up spread over three rows.  Where a priced category
does have more than one unit, its uninvoiced money is attributed to whichever unit earns
the most, which is a guess, and stderr says so.

Where one category covers two things you price separately, split it in `categories.csv`
so each gets its own `UnitPrice`.  Mailboxes are sold at £149/year or £15/month, so
they're `Mailbox (Annual)` and `Mailbox (Monthly)` rather than one category reporting an
uninterpretable mix of years and months; the workshop has two membership levels, so it's
`Workshop (Out of Hours)` at £42/month and `Workshop (Standard)` at £72/month.

Watch the regexes when you split one.  `CategoriesCalculator` takes the first regex that
matches in category id order, so a newly added category sits at the end and can lose
descriptions to an older, broader one -- splitting `Workshop Membership` was enough for
`Friend` to start claiming "Monthly workshop membership - ...".  A negative lookahead on
the broader category fixes it, as in `Friend` and `Mailbox (Annual)`:

```
(?!.*workshop)(.*(membership|friend).*|...)
```

After any edit, check the stderr `Other` list hasn't grown and the total counted hasn't
moved.

Every priced category is cross-checked: quantity times price should be roughly the money
that came in, and stderr flags any category where the two disagree by more than 10%.
That catches a price left at last year's value, and quantities that don't mean one unit
each -- short event hires are sometimes logged as a single unit whatever their length,
which is why the day count and the money should be compared rather than trusted.

Negative line items are treated as discounts, reported in their own column and never
counted as units -- most member discounts are typed the same as the thing they discount,
so the sign is the only reliable signal.

#### Other

Some income is excluded because it can't inform a price, via
`ProductVolumesCalculator::EXCLUDED_ENTRY_TYPES` and `EXCLUDED_CATEGORIES`: internal
transfers, contra account movements (payments made in error awaiting refund), fiscal
hosting funds we merely hold and pass on, and the fiscal hosting fee.  That last one is
genuinely our income and the Cost of Doing Epic poster still counts it -- it's excluded
here only because it's a fee rather than a product, so this report's total is less than
total income by design.

Anything that matches no category lands in `Other`, and is reported as money without any
attempt to turn it into units.  The pot is a mix of real desk and hot desk income and
things that aren't products at all -- refunds, grants, returned deposits, payments made
in error -- so dividing it by a day rate would badly over-count.  stderr lists every
description that fell into `Other`; improving the regexes in `categories.csv` from that
list is the way to shrink it.

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
