{{ config(materialized='table') }}

select
    listing_id,
    date,
    available,
    minimum_nights,
    maximum_nights
from {{ source('raw', 'calendar') }}
