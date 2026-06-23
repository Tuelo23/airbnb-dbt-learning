with calendar as (

    select * from {{ ref('stg_calendar') }}

),

listings as (

    select listing_id, neighbourhood_id from {{ ref('fact_listings') }}

)

select
    calendar.listing_id,
    listings.neighbourhood_id,
    calendar.date,
    calendar.available,
    not calendar.available as is_booked,
    calendar.minimum_nights,
    calendar.maximum_nights
from calendar
left join listings
    on calendar.listing_id = listings.listing_id
