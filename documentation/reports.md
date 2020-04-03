
Reporting
==============


Shopping Cart Report
-----------------------

The "Shopping Cart Report" is a report of how/when we collected
payment for individual datasets.

Run it with a command like:
```
RAILS_ENV=production bundle exec rake identifiers:shopping_cart_report YEAR_MONTH=2020-01
```

Fields in the shopping cart report
- DOI
- Created Date
- Submitted Date
- Size
- Payment Type
- Payment ID
- Institution Name
- Journal Name
- Sponsor Name


Make Data Count / Counter Report
---------------------------------

The "Make Data Count" report runs automatically from the production
server. It uses a mix of python scripts and rake tasks to gather usage
statistics, send them to DataCite, and record copies in our database.

The main control script is `cron/counter.sh`


Administrative screen report
-----------------------------

In the Dryad user interface, administrators may export lists of
datasets from the Admin screen. These reports respect the query
selection that is active on the Admin screen, but they include more
fields than are shown in the user interface.

Fields in the admin screen CSV report
- title
- curation status
- author
- DOI
- last modified date
- last modified by
- size
- publication date
- journal name
- views
- downloads
- citations