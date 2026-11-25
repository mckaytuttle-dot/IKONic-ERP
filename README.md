# IKONic Mountain Operations ERP

Responsive ski retail, distribution, and light manufacturing class demo.

## First run

Open the Site and use the ERP immediately. The class demo has no login or role restrictions. Changes are saved in the browser's local storage, so use the same browser to continue a demo session. No account setup or database schema is required.

## Demo data and workflows

The app includes 34 barcoded items, five BOM parents, three inventory locations, six suppliers, twelve fictional customers, and twelve months of seasonal sample sales history generated in the browser. It supports POS with receipt printing, scan-to-add and scan-to-receive, location adjustments and transfers, multi-item sales orders, fulfillment, returns/exchanges, BOM production, supplier POs and scorecards, MRP, finance, reports, and customer pickup. Inventory, sales orders, and purchase orders export as CSV files that open in Excel.

The included `sql/schema.sql` documents the optional Supabase model from the earlier build; the class-demo default does not connect to it. The `docs/` folder is the GitHub Pages version with relative asset paths. `dist/` remains the Sites deployment folder. Product descriptions are AI-written and the product tiles use illustrative category icons.
