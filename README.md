# IKONic Mountain Operations ERP

Responsive ski retail, distribution, and light manufacturing class demo.

## First run

Open the Site and use the ERP immediately. The default class demo has no login or role restrictions. Changes are saved in the browser's local storage, so use the same browser to continue a demo session. In Settings, choose **Connect shared database** to switch to Supabase mode and sign in. Switch back to demo mode from Settings at any time.

## Demo data and workflows

The app includes 34 barcoded items, five BOM parents, three inventory locations, six suppliers, twelve fictional customers, and twelve months of seasonal sample sales history generated in the browser. It supports POS with receipt printing, scan-to-add and scan-to-receive, location adjustments and transfers, multi-item sales orders, fulfillment, returns/exchanges, BOM production, supplier POs and scorecards, MRP, finance, reports, and customer pickup. Inventory, sales orders, and purchase orders export as CSV files that open in Excel.

The included `sql/schema.sql` defines the Supabase tables and row-level security policies. In shared-database mode, users need an account whose `profiles.role` is `admin`, `manager`, or `staff` to write ERP records; new accounts default to `customer`. The `docs/` folder is the GitHub Pages version with relative asset paths. `dist/` remains the Sites deployment folder. Product descriptions are AI-written and the product tiles use illustrative category icons.
