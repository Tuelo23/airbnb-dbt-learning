with source as (

    select
        id as listing_id,
        host_id,
        neighbourhood as neighbourhood_raw_text,
        neighbourhood_cleansed as neighbourhood_clean,
        latitude,
        longitude,
        property_type,
        room_type,
        accommodates,
        bedrooms,
        bathrooms as bathrooms_numeric,
        bathrooms_text,
        price as raw_price,
        minimum_nights,
        maximum_nights,
        number_of_reviews,
        reviews_per_month,
        review_scores_rating
    from {{ source('raw', 'listings') }}

)

select
    listing_id,
    host_id,
    neighbourhood_raw_text,
    neighbourhood_clean,
    latitude,
    longitude,
    property_type,
    room_type,
    accommodates,
    bedrooms,

    case
        when bathrooms_text ilike '%half%' then 0.5
        when bathrooms_text is not null
            then cast(regexp_extract(bathrooms_text, '^[0-9]+(\.[0-9]+)?') as decimal(4, 1))
        else bathrooms_numeric
    end as bathrooms,

    case
        when raw_price is null or trim(raw_price) = '' then null
        else cast(replace(replace(raw_price, '$', ''), ',', '') as decimal(10, 2))
    end as price,

    minimum_nights,
    maximum_nights,
    number_of_reviews,
    reviews_per_month,
    review_scores_rating
from source
