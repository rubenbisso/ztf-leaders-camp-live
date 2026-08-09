# Imitators of ZTF — Accountability Form

*[Lire en français](README.fr.md)*

A bilingual (English / French) monthly accountability form for
Leaders Camp 2026. Each person's report is linked to their own record by
phone number, so their reports build into one running history over time
rather than sitting as disconnected entries.

**Fill in your form:** https://ztf-imitators-leaders-camp-2026.netlify.app

## Forms

- **Monthly Accountability Form** — 17 sections covering walk with God,
  Bible reading, prayer, soul winning, fasting, finances, and more.
  Submissions are matched to an existing person by phone number (or by
  name + locality when no phone is available), so a person's monthly
  reports build into one running history. A hidden `?entry=goal` URL flag
  lets staff record a trimester's goal separately from its result; this
  is never shown on the form itself.
- **Imitators of ZTF in Finances** — a shorter monthly form for stating
  financial commitments (tithe, offering, savings, debts, fasting).
  Submissions stand on their own and are not linked to a person's
  accountability history.

Both forms auto-save a draft to the browser's local storage as you type,
and support English/French at any point via the toggle in the top bar.

## Admin dashboard

`/admin.html` — a token-gated dashboard for browsing submissions:

- **People** — every person who has submitted a Monthly Accountability
  Form, with their full history grouped by month.
- **Finances** — every Imitators of ZTF in Finances submission, listed
  flat (no person linkage).

The token is the `MIGRATE_TOKEN` environment variable, passed either
through the on-page prompt or as `?token=...` in the URL.

CSV exports of the raw data are available at `/api/export` and
`/api/export-finances` (same token).

## Stack

- **Front end** — static HTML/CSS/JS in [public/](public/), no build
  step or framework.
- **Back end** — [Netlify Functions](netlify/functions/) (`.mjs`,
  Node.js) behind the `/api/*` routes defined in
  [netlify.toml](netlify.toml).
- **Database** — PostgreSQL, accessed via the [`postgres`](https://github.com/porsager/postgres)
  client. Schema lives in
  [netlify/functions/schema.sql](netlify/functions/schema.sql) and is
  applied by calling `/api/migrate?token=...` — idempotent, safe to run
  again after a schema change.

## Local development

```sh
npm install
cp .env.example .env   # fill in DATABASE_URL and MIGRATE_TOKEN
npm run dev            # netlify dev, http://localhost:8888
```

Then apply the schema once:

```
GET http://localhost:8888/api/migrate?token=<MIGRATE_TOKEN>
```

## Deployment

```sh
npm run deploy   # netlify deploy --prod
```

The deployed site needs `DATABASE_URL` and `MIGRATE_TOKEN` set in the
Netlify site's environment variables (Site configuration → Environment
variables), then the same one-time `/api/migrate?token=...` call against
the production URL to create the tables.
