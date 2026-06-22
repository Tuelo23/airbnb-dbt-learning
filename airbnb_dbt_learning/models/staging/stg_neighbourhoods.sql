with source as (

    select
        neighbourhood as raw_neighbourhood
    from {{ ref('neighbourhoods') }}

),

cleaned as (

    select
        raw_neighbourhood,
        case
            when trim(raw_neighbourhood) = '' or raw_neighbourhood is null then 'Unknown'
            else array_to_string(
                list_transform(
                    string_split(lower(regexp_replace(trim(raw_neighbourhood), '\s+', ' ', 'g')), ' '),
                    word -> upper(word[1:1]) || word[2:]
                ),
                ' '
            )
        end as neighbourhood_clean
    from source

),

deduped as (

    select
        raw_neighbourhood,
        neighbourhood_clean,
        row_number() over (partition by neighbourhood_clean order by raw_neighbourhood) as dedup_rank
    from cleaned

)

select
    row_number() over (order by neighbourhood_clean) as neighbourhood_id,
    raw_neighbourhood,
    neighbourhood_clean
from deduped
where dedup_rank = 1
