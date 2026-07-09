--Расчёт MAU.
--Здесь MAU будет определяться как количество уникальных пользователей в месяц 
SELECT a.main_author_name, COUNT(DISTINCT au.puid) AS mau 
FROM bookmate.audition AS au
FULL JOIN bookmate.content AS c USING (main_content_id)
FULL JOIN bookmate.author AS a USING (main_author_id)
WHERE CAST(msk_business_dt_str AS DATE) BETWEEN '2024-11-01' AND '2024-11-30'
GROUP BY a.main_author_name
ORDER BY mau DESC
LIMIT 3

--Расчёт MAU произведений

WITH content_mau AS (
    SELECT
        a.main_content_id,
        COUNT(DISTINCT a.puid) AS mau
    FROM bookmate.audition AS a
    WHERE a.msk_business_dt_str >= '2024-11-01'
      AND a.msk_business_dt_str <  '2024-12-01'
    GROUP BY a.main_content_id
)
SELECT
    c.main_content_name,
    c.published_topic_title_list,
    au.main_author_name,
    cm.mau
FROM content_mau AS cm
JOIN bookmate.content AS c
    ON cm.main_content_id = c.main_content_id JOIN bookmate.author AS au
    ON c.main_author_id = au.main_author_id 
    ORDER BY cm.mau DESC LIMIT 3;

--Расчёт Retention Rate
WITH cohort_activity AS (
    SELECT
        a.puid,
        CAST(a.msk_business_dt_str AS DATE)
            - DATE '2024-12-02' AS day_since_install
    FROM bookmate.audition a
    WHERE a.puid IN (
        SELECT DISTINCT puid
        FROM bookmate.audition
        WHERE msk_business_dt_str = '2024-12-02'
    )
      AND CAST(a.msk_business_dt_str AS DATE) >= DATE '2024-12-02'
),

retention AS (
    SELECT
        day_since_install,
        COUNT(DISTINCT puid) AS retained_users
    FROM cohort_activity
    GROUP BY day_since_install
)

SELECT
    day_since_install,
    retained_users,
    ROUND(
        retained_users::numeric
        / MAX(retained_users) OVER (),
        2
    ) AS retention_rate
FROM retention
ORDER BY day_since_install;


--Расчёт LTV
WITH user_months AS (
    -- Количество активных месяцев у каждого пользователя
    SELECT
        a.puid,
        g.usage_geo_id_name AS city,
        COUNT(DISTINCT DATE_TRUNC('month', CAST(a.msk_business_dt_str AS DATE))) AS active_months
    FROM bookmate.audition a
    JOIN bookmate.geo g
        ON a.usage_geo_id = g.usage_geo_id
    WHERE g.usage_geo_id_name IN ('Москва', 'Санкт-Петербург')
    GROUP BY a.puid, g.usage_geo_id_name ),

user_revenue AS (
    -- Доход от каждого пользователя
    SELECT
        puid,
        city,
        active_months * 399 AS revenue
    FROM user_months
)

SELECT
    city,
    COUNT(DISTINCT puid) AS total_users,
    ROUND(
        SUM(revenue)::numeric / COUNT(DISTINCT puid),
        2
    ) AS ltv
FROM user_revenue
GROUP BY city
ORDER BY city;


--Расчёт средней выручки прослушанного часа — аналог среднего чека
WITH monthly_stats AS (
    SELECT
        CAST(DATE_TRUNC('month', CAST(msk_business_dt_str AS DATE)) AS DATE) AS month,
        COUNT(DISTINCT puid) AS mau,
        ROUND(SUM(hours), 2) AS hours
    FROM bookmate.audition
    WHERE CAST(msk_business_dt_str AS DATE)
          BETWEEN DATE '2024-09-01' AND DATE '2024-11-30'
    GROUP BY CAST(DATE_TRUNC('month', CAST(msk_business_dt_str AS DATE)) AS DATE)
)

SELECT
    month,
    mau,
    hours,
    ROUND(
        (mau * 399)::numeric / hours,
        2
    ) AS avg_hour_rev
FROM monthly_stats
ORDER BY month;

--Подготовка данных перед проверкой гипотезы
SELECT
    g.usage_geo_id_name AS city,
    a.puid,
    SUM(a.hours) AS hours
FROM bookmate.audition a
JOIN bookmate.geo g
    ON a.usage_geo_id = g.usage_geo_id
WHERE g.usage_geo_id_name IN ('Москва', 'Санкт-Петербург') GROUP BY
    g.usage_geo_id_name,
    a.puid
ORDER BY
    city,
    puid;








