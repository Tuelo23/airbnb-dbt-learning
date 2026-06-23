-- Fails if any (listing_id, date) combination appears more than once.
select
    listing_id,
    date,
    count(*) as row_count
from {{ ref('stg_calendar') }}
group by listing_id, date
having count(*) > 1
