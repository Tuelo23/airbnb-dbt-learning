select
    neighbourhood_id,
    neighbourhood_clean as neighbourhood_name
from {{ ref('stg_neighbourhoods') }}
