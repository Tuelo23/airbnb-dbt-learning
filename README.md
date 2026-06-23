# Airbnb dbt Learning Project

A from-scratch analytics engineering project built to practice dbt: raw data → tested, documented star schema → CI-validated on every push. Built incrementally, one dbt concept at a time, using real Inside Airbnb data for Cape Town.

[![dbt CI](https://github.com/Tuelo23/airbnb-dbt-learning/actions/workflows/dbt_ci.yml/badge.svg)](https://github.com/Tuelo23/airbnb-dbt-learning/actions/workflows/dbt_ci.yml)

## Stack

- **dbt-core** + **dbt-duckdb** — transformation and testing
- **DuckDB** — embedded analytical database, zero infrastructure
- **GitHub Actions** — CI: re-fetches raw data and runs `dbt build` on every push/PR

## Data sources

[Inside Airbnb](https://insideairbnb.com/), Cape Town, 2025-06-25 snapshot:

| Source | Rows | Brought in as |
|---|---|---|
| `neighbourhoods.csv` | 116 | dbt **seed** (small, static, committed to git) |
| `listings.csv` | 26,304 | dbt **source** (`read_csv_auto`, fetched fresh each run) |
| `calendar.csv` | 9.6M | dbt **source** |
| `reviews.csv` | 649K | dbt **source** |

Raw files are gitignored (`data_raw/`) — too large/external to commit. CI re-downloads them from Inside Airbnb on every run, which also proves the pipeline doesn't depend on anything cached locally.

## Model layers

```
seeds/neighbourhoods.csv ─┐
sources.raw.listings ─────┼─► staging (stg_*, cleaned/typed) ─► marts (dim_/fact_, star schema)
sources.raw.calendar ─────┤
sources.raw.reviews ──────┘
```

- **Staging** (`models/staging/`) — one model per raw source, light cleaning only: type casting, renaming, no business logic. Materialized as views by default.
- **Marts** (`models/marts/`) — the star schema: `dim_neighbourhoods`, `fact_listings`, `fact_calendar`. Materialized as tables.

27 dbt tests cover primary keys, foreign key relationships, accepted values, and custom grain-uniqueness checks (`tests/`).

## Notable data-quality findings

Surfaced while building this, not assumed in advance:

- DuckDB has no `initcap()` function — title-casing was built manually with `string_split` + `list_transform`.
- `listings.neighbourhood` (free text, host-entered) does **not** match the official ward classification — the correct join key is `neighbourhood_cleansed`.
- `listings.price` is ~17.6% blank; cast from a `"$1,234.00"`-style string to decimal, blanks become `null` rather than erroring.
- `listings.bathrooms` (numeric) is far less complete than `bathrooms_text` (4,384 vs. 213 nulls) — `bathrooms` is derived primarily from the text field, with `"half-bath"` variants mapped to `0.5`.
- `calendar.price` / `calendar.adjusted_price` are 100% null in this snapshot (dropped from staging rather than carried forward as dead columns).

## Running locally

```bash
python3 -m venv venv
source venv/bin/activate
cd airbnb_dbt_learning
pip install -r requirements.txt
dbt build --profiles-dir .
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
```

Note: `listings.csv`, `calendar.csv`, and `reviews.csv` must exist under `airbnb_dbt_learning/data_raw/` before running — see `.github/workflows/dbt_ci.yml` for the exact download commands.
