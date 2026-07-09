-- Проект «Секреты Тёмнолесья»


-- Часть 1. Исследовательский анализ данных

-- Задача 1. Исследование доли платящих игроков

-- Дополнительная проверка поля payer: в поле должны быть только значения 0 и 1.
SELECT
    payer,
    COUNT(id) AS players_count
FROM fantasy.users
GROUP BY payer
ORDER BY payer;

-- 1.1. Доля платящих игроков по всем данным.
SELECT
    COUNT(id) AS total_players,
    SUM(payer) AS paying_players_count,
    (AVG(payer::numeric) * 100)::numeric(5, 2) AS paying_players_share_percent
FROM fantasy.users;

-- 1.2. Доля платящих игроков в разрезе расы персонажа.
SELECT
    r.race,
    SUM(u.payer) AS paying_players_count,
    COUNT(u.id) AS total_players,
    (AVG(u.payer::numeric) * 100)::numeric(5, 2) AS paying_players_share_percent
FROM fantasy.users AS u
JOIN fantasy.race AS r
    ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY paying_players_share_percent DESC;


-- Задача 2. Исследование внутриигровых покупок

-- 2.1. Статистические показатели по полю amount по всем покупкам.
SELECT
    COUNT(transaction_id) AS total_purchases,
    SUM(amount) AS total_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount,
    AVG(amount::numeric)::numeric(10, 2) AS avg_amount,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,
    STDDEV(amount::numeric)::numeric(10, 2) AS stddev_amount
FROM fantasy.events;

-- 2.1.1. Дополнительная проверка: статистика только по покупкам с ненулевой стоимостью.
SELECT
    COUNT(transaction_id) AS total_purchases_without_zero,
    SUM(amount) AS total_amount_without_zero,
    MIN(amount) AS min_amount_without_zero,
    MAX(amount) AS max_amount_without_zero,
    AVG(amount::numeric)::numeric(10, 2) AS avg_amount_without_zero,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount_without_zero,
    STDDEV(amount::numeric)::numeric(10, 2) AS stddev_amount_without_zero
FROM fantasy.events
WHERE amount > 0;

-- 2.2. Количество и доля покупок с нулевой стоимостью.
SELECT
    COUNT(transaction_id) FILTER (WHERE amount = 0) AS zero_amount_purchases,
    COUNT(transaction_id) AS total_purchases,
    (
        COUNT(transaction_id) FILTER (WHERE amount = 0)::numeric
        / COUNT(transaction_id) * 100
    )::numeric(5, 2) AS zero_amount_purchases_share_percent
FROM fantasy.events;

-- 2.2.1. Какие предметы приобретали за 0 райских лепестков.
SELECT
    i.game_items,
    COUNT(e.transaction_id) AS zero_amount_purchases,
    COUNT(DISTINCT e.id) AS zero_amount_buyers
FROM fantasy.events AS e
JOIN fantasy.items AS i
    ON e.item_code = i.item_code
WHERE e.amount = 0
GROUP BY i.game_items
ORDER BY zero_amount_purchases DESC, zero_amount_buyers DESC;

-- 2.2.2. Проверка, сколько нулевых покупок приходилось на одного игрока.
SELECT
    e.id AS player_id,
    COUNT(e.transaction_id) AS zero_amount_purchases
FROM fantasy.events AS e
WHERE e.amount = 0
GROUP BY e.id
ORDER BY zero_amount_purchases DESC, player_id;

-- 2.3. Популярность эпических предметов.
-- Покупки с нулевой стоимостью исключены.
WITH filtered_events AS (
    SELECT
        transaction_id,
        id,
        item_code,
        amount
    FROM fantasy.events
    WHERE amount > 0
),
totals AS (
    SELECT
        COUNT(transaction_id) AS total_purchases,
        COUNT(DISTINCT id) AS total_buyers
    FROM filtered_events
)
SELECT
    i.game_items,
    COUNT(fe.transaction_id) AS item_purchases_count,
    (
        COUNT(fe.transaction_id)::numeric
        / MAX(t.total_purchases) * 100
    )::numeric(5, 2) AS item_purchases_share_percent,
    COUNT(DISTINCT fe.id) AS item_buyers_count,
    (
        COUNT(DISTINCT fe.id)::numeric
        / MAX(t.total_buyers) * 100
    )::numeric(5, 2) AS item_buyers_share_percent
FROM filtered_events AS fe
JOIN fantasy.items AS i
    ON fe.item_code = i.item_code
CROSS JOIN totals AS t
GROUP BY i.game_items
ORDER BY item_buyers_share_percent DESC, item_purchases_count DESC;

-- 2.3.1. Предметы, которые ни разу не покупали за ненулевую стоимость.
SELECT
    i.item_code,
    i.game_items
FROM fantasy.items AS i
LEFT JOIN fantasy.events AS e
    ON i.item_code = e.item_code
    AND e.amount > 0
WHERE e.transaction_id IS NULL
ORDER BY i.game_items;



-- Часть 2. Решение ad hoc-задачи

-- Задача: зависимость активности игроков от расы персонажа.
-- Покупки с нулевой стоимостью исключены.
WITH registered_players AS (
    SELECT
        r.race_id,
        r.race,
        COUNT(u.id) AS total_players
    FROM fantasy.users AS u
    JOIN fantasy.race AS r
        ON u.race_id = r.race_id
    GROUP BY r.race_id, r.race
),
purchase_metrics AS (
    SELECT
        u.race_id,
        COUNT(DISTINCT u.id) AS buyers_count,
        COUNT(DISTINCT u.id) FILTER (WHERE u.payer = 1) AS paying_buyers_count,
        COUNT(e.transaction_id) AS purchases_count,
        SUM(e.amount) AS total_amount
    FROM fantasy.users AS u
    JOIN fantasy.events AS e
        ON u.id = e.id
    WHERE e.amount > 0
    GROUP BY u.race_id
)
SELECT
    rp.race,
    rp.total_players,
    COALESCE(pm.buyers_count, 0) AS buyers_count,
    (
        COALESCE(pm.buyers_count, 0)::numeric
        / NULLIF(rp.total_players, 0) * 100
    )::numeric(5, 2) AS buyers_share_percent,
    (
        COALESCE(pm.paying_buyers_count, 0)::numeric
        / NULLIF(pm.buyers_count, 0) * 100
    )::numeric(5, 2) AS paying_buyers_share_percent,
    (
        pm.purchases_count::numeric
        / NULLIF(pm.buyers_count, 0)
    )::numeric(10, 2) AS avg_purchases_per_buyer,
    (
        pm.total_amount::numeric
        / NULLIF(pm.purchases_count, 0)
    )::numeric(10, 2) AS avg_amount_per_purchase,
    (
        pm.total_amount::numeric
        / NULLIF(pm.buyers_count, 0)
    )::numeric(10, 2) AS avg_total_amount_per_buyer
FROM registered_players AS rp
LEFT JOIN purchase_metrics AS pm
    ON rp.race_id = pm.race_id
ORDER BY avg_purchases_per_buyer DESC NULLS LAST;



-- Дополнительные запросы для проверки выводов

-- Размах доли платящих игроков по расам.
WITH race_payer_share AS (
    SELECT
        r.race,
        COUNT(u.id) AS total_players,
        SUM(u.payer) AS paying_players_count,
        AVG(u.payer::numeric) * 100 AS paying_players_share_percent
    FROM fantasy.users AS u
    JOIN fantasy.race AS r
        ON u.race_id = r.race_id
    GROUP BY r.race
)
SELECT
    race,
    total_players,
    paying_players_count,
    paying_players_share_percent::numeric(5, 2) AS paying_players_share_percent,
    (
        paying_players_share_percent
        - AVG(paying_players_share_percent) OVER ()
    )::numeric(5, 2) AS deviation_from_avg_pp
FROM race_payer_share
ORDER BY paying_players_share_percent DESC;

-- Проверка дорогих покупок через межквартильный размах.
WITH quartiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY amount) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount) AS q3
    FROM fantasy.events
    WHERE amount > 0
),
bounds AS (
    SELECT
        q1,
        q3,
        q3 - q1 AS iqr,
        q3 + 1.5 * (q3 - q1) AS upper_bound
    FROM quartiles
)
SELECT
    COUNT(e.transaction_id) AS expensive_outlier_purchases,
    MIN(e.amount) AS min_outlier_amount,
    MAX(e.amount) AS max_outlier_amount,
    MAX(b.upper_bound)::numeric(10, 2) AS upper_bound
FROM fantasy.events AS e
CROSS JOIN bounds AS b
WHERE e.amount > b.upper_bound;