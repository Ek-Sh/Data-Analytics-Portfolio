-- топ-10 категорий с самым большим количеством отменённых заказов 
select c.category_id, c.name, count(distinct o.order_id)
from marketplace.orders as o 
left join marketplace.order_items as oi on o.order_id=oi.order_id
left join marketplace.products as p on oi.product_id=p.product_id
left join marketplace.categories as c on p.category_id=c.category_id
where o.status= 'canceled' and order_date between '2025-04-01' and '2025-06-30'
group by c.category_id, c.name
order by count(distinct o.order_id) desc
limit 10;


--топ-10 пользователей (email) с самой большой суммой заказов без учёта отменённых 
select u.email, sum(o.total_amount)
from marketplace.orders as o
left join marketplace.users as u on o.buyer_id=u.user_id
where o.status != 'canceled' and o.order_date between '2025-03-01' and '2025-05-31'
group by u.email
order by sum(o.total_amount) desc
limit 10;


--для каждого пользователя и каждого месяца считает сумму заказов нарастающий итог по месяцам
with monthly_sum as (
    SELECT 
        buyer_id,
        DATE_TRUNC('month', order_date) AS month,
        SUM(total_amount) AS monthly_sum
    FROM marketplace.orders
    WHERE status IN ('paid', 'shipped')
    GROUP BY 
        buyer_id,
        DATE_TRUNC('month', order_date)
)
SELECT 
    buyer_id,
    month,
    monthly_sum,
    SUM(monthly_sum) OVER (PARTITION BY buyer_id ORDER BY month) AS running_total
FROM  monthly_sum
ORDER BY 
    buyer_id, 
    month;


--конверсия — долю пользователей, которые сделали хотя бы один заказ
WITH 
    all_users AS (
        SELECT COUNT(DISTINCT user_id)::NUMERIC AS total_users 
        FROM marketplace.users
    ),
    buying_users AS (
        SELECT COUNT(DISTINCT buyer_id)::NUMERIC AS buyers 
        FROM marketplace.orders
    )
SELECT 
    ROUND(buyers::NUMERIC / total_users::NUMERIC, 1) AS conversion_percent
FROM all_users 
CROSS JOIN buying_users;


--средний чек 
select round((sum(total_amount)::NUMERIC/count(distinct order_id)::NUMERIC),2)
from marketplace.orders;


--количество товаров купленных в среднем в одном заказе
with s as (select sum(quantity) as sumq
from marketplace.order_items
group by order_id)
select round(avg(sumq),2)
from s;


--Retention Rate первого месяца для каждой когорты
WITH cohort_users AS (
  SELECT
    DATE_TRUNC('month', registration_date) AS cohort_month,
    COUNT(DISTINCT user_id) AS total_users
  FROM marketplace.users
  GROUP BY cohort_month
),
active_first_month AS (
  SELECT
    DATE_TRUNC('month', u.registration_date) AS cohort_month,
    COUNT(DISTINCT o.buyer_id) AS active_users
  FROM marketplace.users u
  JOIN marketplace.orders o ON u.user_id = o.buyer_id
  WHERE o.order_date >= u.registration_date
    AND o.order_date < u.registration_date + INTERVAL '1 month'
  GROUP BY cohort_month
)
SELECT
  c.cohort_month,
  c.total_users,
  COALESCE(a.active_users, 0) AS active_users_first_month,
  ROUND(a.active_users::numeric / c.total_users::numeric, 4) AS retention_rate
FROM cohort_users c
LEFT JOIN active_first_month a ON c.cohort_month = a.cohort_month
ORDER BY c.cohort_month;


--LTV на пользователя для каждой когорты
WITH cohort_users AS (
 SELECT
   DATE_TRUNC('month', registration_date) AS cohort_month,
   COUNT(DISTINCT user_id) AS total_users
 FROM marketplace.users
 GROUP BY cohort_month
),
cohort_revenue AS (
 SELECT
   DATE_TRUNC('month', u.registration_date) AS cohort_month,
   SUM(o.total_amount::NUMERIC) AS revenue_first_3_months
 FROM marketplace.users u
 JOIN marketplace.orders o ON u.user_id = o.buyer_id
 WHERE o.order_date >= u.registration_date
   AND o.order_date < u.registration_date + INTERVAL '3 months'
 GROUP BY cohort_month
)
SELECT
 c.cohort_month,
 c.total_users,
 COALESCE(r.revenue_first_3_months, 0) AS revenue_first_3_months,
 COALESCE(ROUND(r.revenue_first_3_months::numeric / c.total_users::numeric, 2),0) AS LTV_per_user
FROM cohort_users c
LEFT JOIN cohort_revenue r ON c.cohort_month = r.cohort_month
ORDER BY c.cohort_month;


--АRPU — средний доход на одного зарегистрированного покупателя
WITH 
    total_revenue AS (
        -- Суммарная выручка за период (только не отменённые заказы)
        SELECT 
            SUM(total_amount) AS revenue
        FROM marketplace.orders
        WHERE order_date BETWEEN '2025-01-01' AND '2025-05-31'
          AND status != 'canceled'
    ),
    total_buyers AS (
        -- Количество зарегистрированных покупателей на конец периода
        SELECT 
            COUNT(DISTINCT user_id) AS buyers_count
        FROM marketplace.users
        WHERE registration_date <= '2025-05-31'
          
    )
SELECT
    ROUND(
        tr.revenue::NUMERIC / tb.buyers_count::NUMERIC, 
        0
    ) AS ARPU
FROM total_revenue tr
CROSS JOIN total_buyers tb;


--DAU — количество уникальных активных пользователей по дням
SELECT
  order_date::date AS order_dttm,
  COUNT(DISTINCT buyer_id) AS dau
FROM marketplace.orders
WHERE order_date BETWEEN '2025-05-01' AND '2025-05-31'
GROUP BY order_dttm
ORDER BY order_dttm;


--ARPPU — среднюю выручку на одного платящего пользователя
WITH paying_users AS (
  SELECT DISTINCT buyer_id
  FROM marketplace.orders
  WHERE order_date BETWEEN '2025-05-01' AND '2025-05-31'
    AND status != 'canceled'
),
revenue AS (
  SELECT
    SUM(total_amount::NUMERIC) AS total_revenue
  FROM marketplace.orders
  WHERE order_date BETWEEN '2025-05-01' AND '2025-05-31'
    AND status != 'canceled'
)
SELECT
  r.total_revenue,
  COUNT(p.buyer_id) AS paying_users_count,
  ROUND(r.total_revenue::numeric / COUNT(p.buyer_id)::numeric, 2) AS arppu
FROM revenue r, paying_users p
group by r.total_revenue;





-- запрос для единого датасета в Superset
with ord as (
 select
   o.order_id,
      o.order_date,
      o.status,
      o.buyer_id,
      o.total_amount
 from marketplace.orders o
 WHERE o.order_date between '01-06-2024' and '31-05-2025'
), cte as
(
    select
      -- orders
      o.order_id,
      o.order_date,
      o.status AS order_status,
      o.total_amount AS order_total_amount,
    
      -- order_items
      oi.order_item_id,
      oi.quantity,
      oi.price_at_order_time,
    
        -- products
      p.product_id,
      p.title AS product_title,
      p.description AS product_description,
      p.price AS product_price,
      p.stock_quantity,
    
      -- categories
      c.category_id,
      c.name AS category_name,
    --    c.parent_category_id,
    
      -- buyer
      ub.user_id AS buyer_user_id,
      ub.name AS buyer_name,
      ub.email AS buyer_email,
    --    ub.phone AS buyer_phone,
      ub.registration_date AS buyer_registration_date,
      ub.is_active AS buyer_is_active,
    
      -- seller
      us.user_id AS seller_user_id,
      us.name AS seller_name,
      us.email AS seller_email,
    --    us.phone AS seller_phone,
      us.registration_date AS seller_registration_date,
      us.is_active AS seller_is_active,
      
      -- reviews
      r.review_id,
      r.rating,
      r.comment,
      r.review_date
      
    FROM ord o
    -- Покупатель
    LEFT JOIN marketplace.users ub ON o.buyer_id = ub.user_id
    -- Позиции заказа
    LEFT JOIN marketplace.order_items oi ON o.order_id = oi.order_id
    -- Продукты
    LEFT JOIN marketplace.products p ON oi.product_id = p.product_id
    -- Продавец
    LEFT JOIN marketplace.users us ON p.seller_id = us.user_id
    -- Категория товара
    LEFT JOIN marketplace.categories c ON p.category_id = c.category_id
    -- Отзывы
    LEFT JOIN marketplace.reviews r on r.user_id = ub.user_id and r.product_id = p.product_id
)
select
order_id,
order_date,
order_status,
order_total_amount,
order_item_id,
quantity,
price_at_order_time,
product_id,
product_description,
product_title,
product_price,
stock_quantity,
category_id,
category_name,
buyer_user_id,
buyer_name,
buyer_email,
buyer_registration_date,
buyer_is_active,
seller_user_id,
seller_name,
seller_email,
seller_registration_date,
seller_is_active,
review_id,
rating,
comment,
review_date,
case
    when order_id is null then null
    else ROW_NUMBER() OVER (PARTITION BY order_id)
end AS rn_order_id,
     case
    when review_id is null then null
    else ROW_NUMBER() OVER (PARTITION BY review_id)
end AS rn_review_id,
SUM(quantity) OVER (PARTITION BY order_id) as items_per_order,
AVG(rating) OVER (PARTITION BY product_id) AS avg_product_rating
from cte;


with ord as (
 select
   o.order_id,
      o.order_date,
      o.status,
      o.buyer_id,
      o.total_amount
 from marketplace.orders o
 WHERE o.order_date between '01-06-2024' and '31-05-2025'
), usr as (
 select
    u.user_id,
    u.name,
    u.email,
    u.registration_date,
    u.user_type,
    u.is_active
 from marketplace.users u
 WHERE u.registration_date <= '31-05-2025'
), cte as
(select
    u.user_id,
    u.name,
    u.email,
    u.registration_date,
    u.user_type,
    u.is_active,
    o.order_id,
    o.order_date,
    o.total_amount,
    o.status
from usr u
LEFT JOIN ord o on o.buyer_id = u.user_id)
select
 user_id,
    name,
    email,
    user_type,
    registration_date,
    is_active,
    order_id,
    order_date,
    status,
    total_amount
from cte