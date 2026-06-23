with listings as (

    select * from {{ ref('stg_listings') }}

),

neighbourhoods as (

    select * from {{ ref('dim_neighbourhoods') }}

)

select
    listings.listing_id,
    listings.host_id,
    neighbourhoods.neighbourhood_id,
    listings.latitude,
    listings.longitude,
    listings.property_type,
    listings.room_type,
    listings.accommodates,
    listings.bedrooms,
    listings.bathrooms,
    listings.price,
    listings.minimum_nights,
    listings.maximum_nights,
    listings.number_of_reviews,
    listings.reviews_per_month,
    listings.review_scores_rating
from listings
left join neighbourhoods
    on listings.neighbourhood_clean = neighbourhoods.neighbourhood_name
