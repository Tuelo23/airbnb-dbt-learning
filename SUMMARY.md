# Project Summary

A step-by-step build log of this learning project: every concept, every command, and every real bug found along the way. Built entirely from scratch — empty folder to a tested, documented, CI-validated dbt project.

## Environment setup

- Created `~/Documents/airbnb-dbt-learning`, ran `git init`, set a **local** (repo-only) author identity.
- Created a Python virtual environment (`venv/`), installed `dbt-core` 1.10.22 + `dbt-duckdb` 1.10.0.
- Ran `dbt init` to scaffold the project, choosing DuckDB as the adapter (file-based, zero infrastructure).

## Learning the core dbt loop

- Ran the example placeholder models (`dbt run`), then `dbt test` — hit a **real failing test**: `not_null` caught a deliberately-null row. Fixed the model, reran, watched it go green. This was the first red→green cycle.
- Removed the placeholder `models/example/` once the loop was understood; updated `dbt_project.yml` materialization defaults (staging → view, marts → table).

## Bringing in data: seeds vs. sources

- **`neighbourhoods`** (116 rows) → loaded as a dbt **seed** (small, static, safe to commit to git).
- **`listings`** (26,304 rows), **`calendar`** (9.6M rows), **`reviews`** (649,125 rows) → too large/external to commit, so defined as dbt **sources** using `dbt-duckdb`'s `external_location` + `read_csv_auto`. Raw files live in a gitignored `data_raw/` folder.

## Staging models — cleaning, with real bugs found and fixed

- `stg_neighbourhoods`: ported pandas cleaning logic (trim, collapse whitespace, title-case, dedupe, surrogate key) into SQL. **Found DuckDB has no `initcap()` function** — built title-casing manually with `string_split` + `list_transform`.
- `stg_listings`: cleaned `price` (`"$1,234.00"` string → decimal, blanks → null — 17.6% of rows). **Found `bathrooms` (numeric) is far less complete than `bathrooms_text`** (4,384 vs. 213 nulls) — derived `bathrooms` from the text column instead, mapping `"half-bath"` variants to `0.5`.
- `stg_calendar`: materialized as a **table**, not the staging default view — re-parsing a 9.6M-row CSV on every query would be too slow. **Found `price`/`adjusted_price` are 100% null** in this Inside Airbnb snapshot — dropped rather than carried forward as dead columns.
- `stg_reviews`: stripped legacy HTML `<br/>` tags from review text.

## Marts — the star schema

- `dim_neighbourhoods` + `fact_listings`: while building the join, **found a real bug** — `listings.neighbourhood` is free-text host-entered data that doesn't match the official ward classification at all. The correct join key is `neighbourhood_cleansed`, not `neighbourhood`. Fixed `stg_listings` before the join, verified zero unmatched rows.
- `fact_calendar`: one row per listing per day, joined to `fact_listings` for a neighbourhood FK, with a derived `is_booked` column for occupancy analysis.

## Testing

- **Generic tests**: `unique`, `not_null`, `accepted_values`, `relationships` (referential integrity / FK checks) across every model.
- **Singular tests**: custom SQL files in `tests/` for checks generic tests can't express — e.g. verifying `(listing_id, date)` is a unique grain in `stg_calendar` and `fact_calendar`.
- Fixed a dbt deprecation warning along the way (`accepted_values`/`relationships` arguments needed nesting under `arguments:`).
- Final state: **27 passing tests**, zero warnings, across the whole project.

## CI/CD

- `.github/workflows/dbt_ci.yml`: on every push/PR, a clean Ubuntu runner installs pinned dependencies, **re-downloads all raw data from Inside Airbnb** (since `data_raw/` is gitignored and wouldn't exist on a fresh clone), and runs `dbt build`.
- Added a project-local `profiles.yml` — the original connection config only lived in `~/.dbt/profiles.yml`, which doesn't exist on a CI runner.
- `gh` CLI and Homebrew weren't available/installable (no sudo access), so the GitHub repo was created manually via the browser and pushed over SSH (already configured) after HTTPS credential prompts failed non-interactively.
- Verified every CI run via the GitHub REST API (`curl` + the public `actions/runs` endpoint) since `gh` wasn't available locally either.

## Documentation

- `dbt docs generate` + `dbt docs serve` — explored the auto-generated lineage graph, built entirely from `ref()`/`source()` calls (not hand-drawn).
- Added `description:` text for every model and every column across `staging/schema.yml` and `marts/schema.yml`.
- Wrote a project README: data source table, model-layer diagram, data-quality findings, local run instructions, CI badge.

## Sample analysis

- `analyses/top_neighbourhoods_by_occupancy.sql` — a BI-style query (compiled via `dbt compile`, not run as part of the pipeline). Two real analytical lessons baked into it:
  1. A minimum-listing-count filter, because ranking by raw booking rate let single fully-booked listings look like "top neighbourhoods."
  2. An explicit caveat that `fact_calendar` is mostly forward-looking (2025-06-25 to 2026-07-01), so this measures forward booking pace, not historical occupancy.

## Final state

- 7 models (4 staging, 3 marts), 1 seed, 3 sources, 1 analysis, 27 tests — all green.
- Public repo: https://github.com/Tuelo23/airbnb-dbt-learning, with **6 consecutive passing CI runs**.
- Every commit, including this one, made and pushed incrementally with an explained "why" at each step.
