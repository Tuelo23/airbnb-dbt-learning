-- Sample BI query: top neighbourhoods by booking rate.
--
-- Caveat: fact_calendar spans 2025-06-25 to 2026-07-01 (Inside Airbnb's scrape
-- date forward ~1 year). is_booked therefore reflects forward bookings/host
-- blocks as of the scrape date, not historical occupancy -- there is no prior
-- period in this dataset to measure true past occupancy.
--
-- Neighbourhoods with very few listings are excluded (min_listing_count
-- threshold) to avoid a single fully-booked listing looking like a "top"
-- neighbourhood -- see README data-quality notes.

with calendar_with_neighbourhood as (

    select * from {{ ref('fact_calendar') }}

),

neighbourhood_stats as (

    select
        neighbourhood_id,
        count(distinct listing_id) as listing_count,
        round(avg(case when is_booked then 1.0 else 0.0 end), 4) as booking_rate
    from calendar_with_neighbourhood
    group by neighbourhood_id

)

select
    n.neighbourhood_name,
    s.listing_count,
    s.booking_rate
from neighbourhood_stats s
join {{ ref('dim_neighbourhoods') }} n
    on s.neighbourhood_id = n.neighbourhood_id
where s.listing_count >= 5
order by s.booking_rate desc
limit 10
