with enrollments_ranked as (
  select
    emission_time,
    org,
    course_name,
    run_name,
    actor_id,
    enrollment_mode,
    enrollment_status,
    rank() over (partition by date(emission_time), org, course_name, run_name, actor_id order by emission_time desc) as event_rank
  from
    {{ DBT_PROFILE_TARGET_DATABASE }}.fact_enrollments
  {% raw -%}
  {% if filter_values('org') != [] %}
    where
      org in {{ filter_values('org') | where_in }}
  {% endif %}
  {%- endraw %}
), enrollment_windows as (
  select
    org,
    course_name,
    run_name,
    actor_id,
    enrollment_status,
    enrollment_mode,
    emission_time as window_start_at,
    lagInFrame(emission_time, 1, now() + interval '1' day) over (partition by org, course_name, run_name, actor_id order by emission_time desc) as window_end_at
  from
    enrollments_ranked
  where
    event_rank = 1
), enrollment_window_dates as (
    select
        org,
        course_name,
        run_name,
        actor_id,
        enrollment_status,
        enrollment_mode,
        date_trunc('day', window_start_at) as window_start_date,
        date_trunc('day', window_end_at) as window_end_date
    from enrollment_windows
)
select
    date(fromUnixTimestamp(
        arrayJoin(
            range(
                toUnixTimestamp(window_start_date),
                toUnixTimestamp(window_end_date),
                86400
            )
        )
    )) as enrollment_status_date,
    org,
    course_name,
    run_name,
    actor_id,
    enrollment_status,
    enrollment_mode
from enrollment_window_dates
