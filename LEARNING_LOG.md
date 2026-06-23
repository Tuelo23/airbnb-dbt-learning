# Learning Log — Step by Step

This is the full step-by-step build log of this project, in the order it was actually done. Each step includes what command ran, why, and what it taught. `SUMMARY.md` is the condensed version of this; this file keeps the granularity of how the project was actually built, one explained step at a time.

## Step 1 — Create the project folder
```bash
mkdir -p ~/Documents/airbnb-dbt-learning
```
Every other step needs a working directory. Kept fully separate from the existing `Airbnb_case_study` project.

## Step 2 — Initialize git with a local identity
```bash
git init
git config user.name "Tuelo Setshedi"
git config user.email "pricesetshedi@gmail.com"
```
Local (not global) config — every commit here is attributed correctly without touching global git settings.

## Step 3 — Set up the Python virtual environment
```bash
python3 -m venv venv
```
Isolates this project's dependencies from system Python and from other projects.

## Step 4 — Install dbt-core and dbt-duckdb
```bash
venv/bin/pip install dbt-core dbt-duckdb
```
`dbt-core` is the CLI/engine (Jinja templating, DAG resolution, testing). `dbt-duckdb` is the adapter that lets dbt talk to DuckDB — an embedded, file-based analytical database requiring zero infrastructure. First install attempt failed mid-download (`ConnectionResetError`); retried and succeeded.

## Step 5 — Scaffold the dbt project
```bash
dbt init airbnb_dbt_learning
```
Interactive — selected DuckDB as the only available adapter. Created `dbt_project.yml`, placeholder `models/example/`, and wrote connection config to `~/.dbt/profiles.yml` (global, since no local one existed yet).

## Step 6 — Verify the connection
```bash
dbt debug
```
Confirmed `profiles.yml`/`dbt_project.yml` are valid and the connection to `dev.duckdb` works, before writing any models.

## Step 7 — First commit
Added a root `.gitignore` (`venv/`, `*.duckdb`, `logs/`, `.DS_Store`) and committed the scaffold. First checkpoint.

## Step 8 — Run the example models
```bash
dbt run
```
Learned `ref()` — `my_second_dbt_model` references `my_first_dbt_model`, and dbt resolved the correct build order automatically from that dependency, not from file order.

## Step 9 — Run the example tests, watch one fail
```bash
dbt test
```
`not_null_my_first_dbt_model_id` **failed** — deliberately, by design of dbt's starter template (the model has a null `id` row). Learned that `unique` and `not_null` are separate, single-purpose tests: `unique` passed even with the null present, because it doesn't check nullability at all.

## Step 10 — Fix it, rerun, commit
Uncommented `where id is not null` in `my_first_dbt_model.sql`, reran `dbt run` then `dbt test` — all green. First red→green cycle. Committed as its own change.

## Step 11 — Clean up the placeholders
Removed `models/example/`, dropped the now-orphaned `my_first_dbt_model`/`my_second_dbt_model` objects directly from DuckDB (dbt doesn't auto-drop removed models), and set real materialization defaults in `dbt_project.yml` (`staging: view`).

## Step 12 — Bring in `neighbourhoods` as a seed
Downloaded the raw `neighbourhoods.csv` from Inside Airbnb directly (not the pre-cleaned version from the other project), ran `dbt seed`. Learned: **seeds** are for small, static, project-owned data that's safe to commit to git — 116 rows qualified.

## Step 13 — Build `stg_neighbourhoods`
Ported the cleaning logic from `pipeline.py`'s pandas transform (trim, collapse whitespace, title-case, dedupe, surrogate key) into SQL.
**Real bug found:** DuckDB has no `initcap()` function (unlike Postgres/Snowflake). Built title-casing manually with `string_split` + `list_transform` + a lambda.

## Step 14 — Add schema tests
`unique` + `not_null` on `neighbourhood_id`, `not_null` on `neighbourhood_clean`. All passed.

## Step 15 — Bring in `listings` as a source
26,304 rows — too large/external for a seed. Used `dbt-duckdb`'s `external_location: "read_csv_auto(...)"` to define a **source** instead — DuckDB reads the file live, nothing copied into the project. Verified it worked using `dbt show --inline` before writing any model on top.

## Step 16 — Build `stg_listings`
**Real bug found #1:** `price` is a text string (`"$2,315.00"`), 17.6% blank. Cleaned with `replace()` + `cast()`, blanks → `null`.
**Real bug found #2:** the numeric `bathrooms` column has 4,384 nulls, but `bathrooms_text` only has 213 — derived `bathrooms` from the text field instead (regex-extracting the leading number, mapping `"half-bath"` variants to `0.5`), falling back to the numeric column only when text was also missing.

## Step 17 — Add schema tests, fix a deprecation warning
Checked actual data first (distinct `room_type` values, null counts) rather than guessing test rules. Hit a dbt deprecation warning on `accepted_values` — fixed by nesting `values` under `arguments:`, the newer required syntax.

## Step 18 — Build the marts: `dim_neighbourhoods` + `fact_listings`
**Real bug found:** before joining, checked whether `stg_listings.neighbourhood` actually matched the `Ward N` values in the neighbourhoods dimension — it didn't. `neighbourhood` is free-text, host-entered address data. The correct join key is `neighbourhood_cleansed`, a separate column entirely. Fixed `stg_listings` to expose `neighbourhood_clean` from the correct source column, verified zero unmatched rows, then built the star schema.

## Step 19 — Add a `relationships` test
First use of `relationships` — dbt's referential-integrity check, verifying every `fact_listings.neighbourhood_id` exists in `dim_neighbourhoods`. This is the kind of test that would have caught the join-key bug automatically had it existed first.

## Step 20 — Generate and serve dbt docs
```bash
dbt docs generate
dbt docs serve --port 8089
```
Explored the lineage graph — built entirely from `ref()`/`source()` calls, not hand-drawn. Learned `dbt docs serve` just serves static files locally; nothing leaves the machine.

## Step 21 — Bring in `calendar` (9.6M rows)
Same source pattern as listings, but materialized `stg_calendar` as a **table**, not the staging default view — re-parsing 9.6M CSV rows on every query would be slow; pay the cost once at build time instead.
**Real bug found:** `price`/`adjusted_price` are 100% null in this Inside Airbnb snapshot. Dropped them rather than carry forward dead columns.
Introduced **singular tests** — a raw SQL file in `tests/` (`assert_calendar_grain_is_unique.sql`) to check `(listing_id, date)` uniqueness, something the generic `unique` test can't express across two columns.

## Step 22 — Bring in `reviews` (649,125 rows)
Stripped legacy HTML `<br/>` tags from `comments`. Added a `relationships` test from `stg_reviews.listing_id` to `fact_listings.listing_id` — and confirmed dbt still built `fact_listings` first, proving `ref()` inside a *test* creates a real DAG edge regardless of which folder the YAML lives in.

## Step 23 — Set up GitHub Actions CI
Three real gaps found and fixed before the workflow could work:
1. No project-local `profiles.yml` — connection config only existed in `~/.dbt/`, which won't exist on a CI runner. Committed one inside the project (safe — no secrets, just a local file path) and used `--profiles-dir .`.
2. No `requirements.txt` pinning `dbt-core`/`dbt-duckdb` versions.
3. `data_raw/` is gitignored — a fresh CI checkout won't have the raw CSVs. Added a CI step that re-downloads all three datasets from Inside Airbnb before `dbt build` runs. This isn't a workaround; it's the realistic pattern — a pipeline should never assume data sitting uncommitted in git.

## Step 24 — Create the GitHub repo and push
`gh` CLI wasn't installed; Homebrew wasn't either, and installing it was blocked by missing sudo/admin access (no interactive password prompt possible in this environment). Created the repo manually via the GitHub web UI instead. HTTPS push failed (`could not read Username` — no interactive credential prompt available), but SSH was already configured and authenticated as `Tuelo23` — switched the remote to SSH and pushed successfully.

## Step 25 — Verify CI via the API
No `gh` CLI available, so checked workflow run status with the public GitHub REST API directly:
```bash
curl -s "https://api.github.com/repos/Tuelo23/airbnb-dbt-learning/actions/runs?per_page=5"
```
First run: green, on a completely clean Ubuntu runner.

## Step 26 — Build `fact_calendar` for occupancy
Joined `stg_calendar` to `fact_listings` for a `neighbourhood_id` FK, derived `is_booked` (`not available`). Kept it at the same row-per-day grain as the source — aggregation belongs downstream, not baked into the fact table.
**Real analytical trap caught:** the "top neighbourhoods by occupancy" preview showed several wards at exactly 100% with only 365 listing-days — i.e. a single fully-booked listing each, not genuine demand. Flagged this before it became a misleading number anyone relied on.

## Step 27 — Documentation pass
Added `description:` text for every model and every column across `staging/schema.yml` and `marts/schema.yml` — including columns with no tests attached, which had been silently skipped earlier. Regenerated docs to confirm everything parsed and rendered.

## Step 28 — Write the README
Data source table, model-layer diagram, a dedicated "data-quality findings" section listing every real bug caught above, local run instructions, and a CI badge. Trimmed the dbt-generated boilerplate inner README down to a pointer at the real one.

## Step 29 — Sample BI analysis
`analyses/top_neighbourhoods_by_occupancy.sql` — used dbt's `analyses/` folder specifically because it's compiled (full `ref()` support) but never run as part of `dbt build`, the right home for an ad-hoc query. Two deliberate corrections baked into the SQL itself:
1. A minimum-listing-count filter (≥ 5), directly addressing the small-sample trap found in Step 26.
2. An explicit comment noting `fact_calendar` spans mostly *future* dates (2025-06-25 to 2026-07-01) relative to the scrape date — so this measures forward booking pace, not historical occupancy, since there's no prior period in this dataset to measure that.

## Step 30 — Verify the CI badge
Checked both the badge image URL and its link target return `200 OK`, and confirmed the SVG's embedded status text actually reads "passing" — not just that the markdown renders, but that it reflects real CI state.

## Step 31 — Final summary and this log
Wrote `SUMMARY.md` (condensed) and this file (step-by-step), committed and pushed both, confirmed via the GitHub API that CI stayed green throughout.

## Final state
7 models (4 staging, 3 marts), 1 seed, 3 sources, 1 analysis, 27 tests, all green, 6+ consecutive passing CI runs, fully documented, public at https://github.com/Tuelo23/airbnb-dbt-learning.
