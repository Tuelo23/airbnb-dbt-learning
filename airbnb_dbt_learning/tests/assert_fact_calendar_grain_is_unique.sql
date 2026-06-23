-- Fails if the join to fact_listings introduced any row duplication.
select
    listing_id,
    date,
    count(*) as row_count
from {{ ref('fact_calendar') }}
group by listing_id, date
having count(*) > 1
