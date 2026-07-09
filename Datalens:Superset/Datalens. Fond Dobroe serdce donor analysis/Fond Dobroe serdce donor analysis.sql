-- Динамика MAU
SELECT CAST(DATE_TRUNC('month', "OrderFirstActionDateTimeUtc") AS date) AS "Месяц",
COUNT(DISTINCT "OrderCustomerIdsMindboxId") AS "MAU"
FROM aif_data.order
-- Отбираем только оплаченные заказы
WHERE "OrderLineStatusIdsExternalId" = 'Paid'
GROUP BY "Месяц"



-- Retention Rate по месяцам благотворителей в августе 2022
WITH august_users AS (
SELECT DISTINCT CAST(DATE_TRUNC('month', "OrderFirstActionDateTimeUtc") AS date) AS august_month,
"OrderCustomerIdsMindboxId" AS user_id,
"CustomerSex" AS customer_sex
FROM aif_data.order AS orders
JOIN aif_data.id_donor AS donors
ON orders."OrderCustomerIdsMindboxId" = donors."CustomerIdsMindboxId"
-- Отбираем заказы в августе 2022 (во время кампании)
WHERE "OrderFirstActionDateTimeUtc" BETWEEN '2022-08-01' AND '2022-08-31'
-- Отбираем только оплаченные заказы
AND "OrderLineStatusIdsExternalId" = 'Paid'
-- Убираем заказы без данных о поле благотворителя
AND "CustomerSex" IS NOT NULL),
active_users AS (
SELECT DISTINCT CAST(DATE_TRUNC('month', "OrderFirstActionDateTimeUtc") AS date) AS activity_month,
"OrderCustomerIdsMindboxId" AS user_id,
"CustomerSex" AS customer_sex
FROM aif_data.order AS orders
JOIN aif_data.id_donor AS donors
ON orders."OrderCustomerIdsMindboxId" = donors."CustomerIdsMindboxId"
where "OrderFirstActionDateTimeUtc" >= '2022-08-01'
AND "OrderLineStatusIdsExternalId" = 'Paid'
AND "CustomerSex" IS NOT NULL),
monthly_retention AS (
SELECT n.user_id,
n.customer_sex,
august_month,
-- Используем деление на 30, чтобы преобразовать дни в месяцы
(activity_month::date - august_month::date)/30 AS month_since_install
FROM august_users n
JOIN active_users a
ON n.user_id = a.user_id
AND activity_month >= august_month)
SELECT customer_sex AS "Пол",
month_since_install "Месяц",
COUNT(DISTINCT user_id) AS retained_users,
ROUND((1.0 * COUNT(DISTINCT user_id) / MAX(COUNT(DISTINCT user_id)) OVER (PARTITION BY customer_sex ORDER by month_since_install))::numeric,2) AS retention_rate
FROM monthly_retention
GROUP BY customer_sex, month_since_install
ORDER BY customer_sex, month_since_install



--Средний чек по когортам
SELECT "CustomerSex" AS "Пол",
COUNT(DISTINCT "OrderIdsWebsiteID") AS "Количество заказов",
SUM("OrderTotalPrice") / COUNT(DISTINCT "OrderIdsWebsiteID") AS "Средний чек"
FROM aif_data.order AS orders
JOIN aif_data.id_donor AS donors
ON orders."OrderCustomerIdsMindboxId" = donors."CustomerIdsMindboxId"
-- Убираем заказы без данных о поле благотворителя
WHERE "CustomerSex" IS NOT NULL
-- Отбираем только оплаченные заказы
AND "OrderLineStatusIdsExternalId" = 'Paid'
GROUP BY 1



--LTV благотворителей крупных городов
SELECT "CustomerAreaName" AS "Город",
COUNT(DISTINCT "OrderCustomerIdsMindboxId") "Количество благотворителей",
SUM("OrderTotalPrice") / COUNT(DISTINCT "OrderCustomerIdsMindboxId") AS "LTV"
FROM aif_data.order AS orders
JOIN aif_data.id_donor AS donors
ON orders."OrderCustomerIdsMindboxId" = donors."CustomerIdsMindboxId"
-- Отбираем только заказы благотворителей из Москвы, Санкт-Петербурга и Екатеринбурга
WHERE "CustomerAreaName" IN ('Москва', 'Санкт-Петербург', 'Екатеринбург')
-- Отбираем только оплаченные заказы
AND "OrderLineStatusIdsExternalId" = 'Paid'
GROUP BY 1
ORDER BY 2 DESC