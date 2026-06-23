{{ config(materialized='table') }}

select
    id as review_id,
    listing_id,
    date as review_date,
    reviewer_id,
    reviewer_name,
    trim(regexp_replace(comments, '<br\s*/?>', ' ', 'g')) as comments
from {{ source('raw', 'reviews') }}
