-- BLOCK increase_ai_date_limit
UPDATE
    assessment_instances AS ai
SET
    date_limit = date_limit + INTERVAL '5 min'
WHERE
    ai.open
    AND ai.id = $assessment_instance_id

-- BLOCK decrease_ai_date_limit
UPDATE
    assessment_instances AS ai
SET
    date_limit = GREATEST(current_timestamp, date_limit - INTERVAL '5 min')
WHERE
    ai.open
    AND ai.id = $assessment_instance_id

-- BLOCK select_assessment_instances
WITH time_remaining AS (
     SELECT ai.id, greatest(0, extract(epoch from (ai.date_limit - current_timestamp))) AS seconds
       FROM assessment_instances AS ai
     )
SELECT
    (aset.name || ' ' || a.number) AS assessment_label,
    u.user_id, u.uid, u.name, coalesce(e.role, 'None'::enum_role) AS role,
    gi.id AS gid, gi.name AS group_name, gi.uid_list,
    substring(u.uid from '^[^@]+') AS username,
    ai.score_perc, ai.points, ai.max_points,
    ai.number,ai.id AS assessment_instance_id,ai.open,
    CASE
        WHEN ai.open AND ai.date_limit IS NOT NULL AND tr.seconds > 120
            THEN floor(tr.seconds / 60)::text || ' min'
        WHEN ai.open AND ai.date_limit IS NOT NULL AND tr.seconds > 60
            THEN '1 min ' || floor(tr.seconds - 60)::text || ' sec'
        WHEN ai.open AND ai.date_limit IS NOT NULL
            THEN floor(tr.seconds)::text || ' sec'
        WHEN ai.open THEN 'Open'
        ELSE 'Closed'
    END AS time_remaining,
    CASE
        WHEN ai.open AND ai.date_limit IS NOT NULL AND tr.seconds < 120
            THEN 1
        WHEN ai.open AND ai.date_limit IS NOT NULL
            THEN tr.seconds::INTEGER % 60
        WHEN ai.open THEN 0
    END AS next_time_remaining_update,
    format_date_full_compact(ai.date, ci.display_timezone) AS date_formatted,
    format_interval(ai.duration) AS duration,
    EXTRACT(EPOCH FROM ai.duration) AS duration_secs,
    EXTRACT(EPOCH FROM ai.duration) / 60 AS duration_mins,
    (row_number() OVER (PARTITION BY u.user_id ORDER BY score_perc DESC, ai.number DESC, ai.id DESC)) = 1 AS highest_score
FROM
    assessments AS a
    JOIN course_instances AS ci ON (ci.id = a.course_instance_id)
    JOIN assessment_sets AS aset ON (aset.id = a.assessment_set_id)
    JOIN assessment_instances AS ai ON (ai.assessment_id = a.id)
    JOIN time_remaining AS tr ON (tr.id = ai.id)
    LEFT JOIN group_info($assessment_id) AS gi ON (gi.id = ai.group_id)
    LEFT JOIN users AS u ON (u.user_id = ai.user_id)
    LEFT JOIN enrollments AS e ON (e.user_id = u.user_id AND e.course_instance_id = a.course_instance_id)
WHERE
    a.id = $assessment_id
ORDER BY
    e.role DESC, u.uid, u.user_id, ai.number, ai.id;

-- BLOCK select_assessment_instance
WITH time_remaining AS (
     SELECT ai.id, greatest(0, extract(epoch from (ai.date_limit - current_timestamp))) AS seconds
       FROM assessment_instances AS ai
     )
SELECT
    (aset.name || ' ' || a.number) AS assessment_label,
    u.user_id, u.uid, u.name, coalesce(e.role, 'None'::enum_role) AS role,
    gi.id AS gid, gi.name AS group_name, gi.uid_list,
    substring(u.uid from '^[^@]+') AS username,
    ai.score_perc, ai.points, ai.max_points,
    ai.number,ai.id AS assessment_instance_id,ai.open,
    CASE
        WHEN ai.open AND ai.date_limit IS NOT NULL AND tr.seconds > 120
            THEN floor(tr.seconds / 60)::text || ' min'
        WHEN ai.open AND ai.date_limit IS NOT NULL AND tr.seconds > 60
            THEN '1 min ' || floor(tr.seconds - 60)::text || ' sec'
        WHEN ai.open AND ai.date_limit IS NOT NULL
            THEN tr.seconds::text || ' sec'
        WHEN ai.open THEN 'Open'
        ELSE 'Closed'
    END AS time_remaining,
    format_date_full_compact(ai.date, ci.display_timezone) AS date_formatted,
    format_interval(ai.duration) AS duration,
    EXTRACT(EPOCH FROM ai.duration) AS duration_secs,
    EXTRACT(EPOCH FROM ai.duration) / 60 AS duration_mins,
    (row_number() OVER (PARTITION BY u.user_id ORDER BY score_perc DESC, ai.number DESC, ai.id DESC)) = 1 AS highest_score
FROM
    assessment_instances AS ai
    JOIN time_remaining AS tr ON (tr.id = ai.id)
    JOIN assessments AS a ON (a.id = ai.assessment_id)
    JOIN course_instances AS ci ON (ci.id = a.course_instance_id)
    JOIN assessment_sets AS aset ON (aset.id = a.assessment_set_id)
    LEFT JOIN group_info(a.id) AS gi ON (gi.id = ai.group_id)
    LEFT JOIN users AS u ON (u.user_id = ai.user_id)
    LEFT JOIN enrollments AS e ON (e.user_id = u.user_id AND e.course_instance_id = a.course_instance_id)
WHERE
    ai.id = $assessment_instance_id
ORDER BY
    e.role DESC, u.uid, u.user_id, ai.number, ai.id;

-- BLOCK open
WITH results AS (
    UPDATE assessment_instances AS ai
    SET
        open = true,
        date_limit = NULL,
        auto_close = FALSE,
        modified_at = now()
    WHERE
        ai.id = $assessment_instance_id
    RETURNING
        ai.open,
        ai.id AS assessment_instance_id
)
INSERT INTO assessment_state_logs AS asl
        (open, assessment_instance_id, auth_user_id)
(
    SELECT
        true, results.assessment_instance_id, $authn_user_id
    FROM
        results
);
