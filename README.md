# IKONic | Mountain Operations

A static, responsive ski retail and operations ERP demo. GitHub Pages hosts the frontend; Supabase remains the shared database, authentication service, and realtime backend.

## Files

- `docs/index.html` — page shell and CDN-loaded libraries
- `docs/app.css` — ERP, storefront, and responsive styles
- `docs/app.js` — ERP workflows and Supabase data/realtime logic
- `docs/config.js` — Supabase project URL and publishable browser key
- `docs/assets/` — mountain and product imagery
- `sql/schema.sql` — database schema and row-level security policies

## Publish on GitHub Pages

1. Upload the visible `README.md`, `docs` folder, and `sql` folder to the top level of your repository on the `main` branch. Keep the folders intact.
2. In GitHub, open **Settings → Pages**.
3. Under **Build and deployment**, choose **Deploy from a branch**.
4. Select branch **main** and folder **/docs**, then click **Save**. GitHub publishes the files in `docs/` whenever you push changes to that branch.
5. After GitHub provides the Pages URL, add it to Supabase **Authentication → URL Configuration** as the Site URL and an allowed redirect URL. A project URL usually looks like `https://YOUR-USERNAME.github.io/YOUR-REPOSITORY/`.

The files use relative paths, so the site works under a GitHub project URL or custom domain.

## Supabase

`docs/config.js` is already set to the existing IKONic Supabase project. The `sb_publishable_...` key is browser-visible by design. Never place a Supabase `service_role` key or other secret key in this project. Keep Row Level Security enabled.

If continuing with the existing IKONic database, moving the frontend to GitHub Pages does **not** require rerunning `sql/schema.sql`. Run it only when setting up a separate new Supabase project.

## Editing

Edit files inside `docs/`, then commit and push. GitHub Pages will publish the update from `main` → `/docs`. To use a different Supabase project, update `docs/config.js` and set up that project's database and authentication URLs.

GitHub Pages serves static files, while Supabase supplies shared records and realtime updates. The demo has synthetic sales history and fictional customer profiles.
