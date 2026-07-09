

-- временной интервал публикации объявлений
SELECT MIN (a.first_day_exposition ),
	MAX(a.first_day_exposition )
FROM  real_estate.advertisement a; 

--распределение объявлений по типу населенного пункта
SELECT t.type,
	count(f.id ) AS count_type
FROM real_estate.flats f 
JOIN real_estate.type t ON f.type_id =t.type_id 
GROUP BY t.TYPE
ORDER  BY count_type DESC;

--время активности объявлений
SELECT MIN(a.days_exposition ) AS min_exposition,
	MAX(a.days_exposition ) AS max_exposition,
	round ((AVG(a.days_exposition )::numeric),2) AS avg_exposition,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY a.days_exposition ) AS mediana_exposition
FROM real_estate.advertisement a;

--процент проданных объектов недвижимости
SELECT round(count(CASE WHEN a.days_exposition IS NOT NULL THEN 1 END)/count(a.id)::NUMERIC*100,2) AS sold_object_percent
FROM real_estate.advertisement a;

--процент объявлений о продаже квартир в Санкт-Петербурге
SELECT round(count(CASE WHEN c.city= 'Санкт-Петербург' THEN 1 END)/count(f.id)::NUMERIC*100,2) AS sp_advertisment
FROM real_estate.flats f 
JOIN real_estate.city c ON c.city_id =f.city_id; 

--стоимость квадратного метра
WITH sq_m AS (
			SELECT (a.last_price::NUMERIC/f.total_area) AS cost_sq_m
			FROM real_estate.flats f
			JOIN real_estate.advertisement a ON a.id=f.id)
SELECT round(MIN(cost_sq_m )::NUMERIC,2) AS min_cost_sq_m,
		round(MAX(cost_sq_m )::NUMERIC,2)AS max_cost_sq_m,
		round(AVG(cost_sq_m)::NUMERIC,2) AS avg_cost_sq_m,
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY cost_sq_m ) AS mediana_cost_sq_m	
FROM sq_m;

--статистические показатели
SELECT 
-- статистические показатели: общая площадь квартиры, в кв. метрах.
	MIN(f.total_area ) AS min_total_area,
	MAX(f.total_area) AS max_total_area,
	round(AVG(f.total_area)::NUMERIC,2) AS avg_total_area,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.total_area ) AS mediana_total_area,
	round(PERCENTILE_CONT (0.99) WITHIN GROUP (ORDER BY f.total_area)::NUMERIC,2) AS p99_total_area,
--статистические показатели: количество комнат
	MIN(f.rooms ) AS min_rooms,
	MAX(f.rooms) AS max_rooms,
	round(AVG(f.rooms)::NUMERIC ,2) AS avg_rooms,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.rooms ) AS mediana_rooms,
	round(PERCENTILE_CONT (0.99) WITHIN GROUP (ORDER BY f.rooms)::NUMERIC,2) AS p99_rooms,
--статистические показатели: количество балконов
	MIN(f.balcony ) AS min_balcony,
	MAX(f.balcony) AS max_balcony,
	round(AVG(f.balcony)::NUMERIC ,2) AS avg_balcony,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.balcony) AS mediana_balcony,
	round(PERCENTILE_CONT (0.99) WITHIN GROUP (ORDER BY f.balcony)::NUMERIC, 2)AS p99_balcony,
--статистические показатели:высота потолков
	MIN(f.ceiling_height ) AS min_ceiling_height,
	MAX(f.ceiling_height) AS max_ceiling_height,
	round(AVG(f.ceiling_height)::NUMERIC ,2) AS avg_ceiling_height,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.ceiling_height) AS mediana_ceiling_height,
	round(PERCENTILE_CONT (0.99) WITHIN GROUP (ORDER BY f.ceiling_height)::NUMERIC,2) AS p99_ceiling_height,
--статистические показатели: этаж
	MIN(f.floor ) AS min_floor,
	MAX(f.floor) AS max_floor,
	round(AVG(f.floor)::NUMERIC ,2) AS avg_floor,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.floor) AS mediana_floor,
	round(PERCENTILE_CONT (0.99) WITHIN GROUP (ORDER BY f.floor)::NUMERIC,2) AS p99_floor
FROM real_estate.flats f



--РЕШЕНИЕ AD HOC ЗАДАЧ


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выведем объявления без выбросов:
filtered_flats AS (
    SELECT f.id, f.total_area, f.rooms, f.balcony, f.floor, f.ceiling_height, f.city_id, f.type_id
    FROM real_estate.flats f
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND (
            (ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
             AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) 
            OR ceiling_height IS NULL
        )
        AND total_area > 0   -- исключаем квартиры с площадью = 0
),
prepared AS (
    SELECT 
        a.id,
        c.city,
        CASE WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург' ELSE 'ЛенОбл' END AS region,
        CASE 
            WHEN a.days_exposition BETWEEN 1 AND 30 THEN 'Месяц'
            WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'Квартал'
            WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'Полгода'
            WHEN a.days_exposition > 180 AND a.days_exposition IS NOT NULL THEN 'Больше полугода'
            ELSE 'Действующие'
        END AS days_category,
        a.last_price,
        f.total_area,
        (a.last_price / f.total_area)::numeric AS price_per_sqm,   -- цена за квадратный метр
        f.rooms,
        f.balcony,
        f.floor,
        f.ceiling_height
    FROM real_estate.advertisement a
    JOIN filtered_flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    JOIN real_estate.type t ON f.type_id = t.type_id
    WHERE t.type = 'город'   -- только города
)
SELECT 
    region,
    days_category,
    COUNT(*) AS ads_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY region), 2) AS ads_share_pct, --доля объявлений внутри города
    ROUND(AVG(price_per_sqm)::numeric,2) AS avg_price_per_sqm, --средняя стоимость квадратного метра
    ROUND(AVG(total_area)::numeric,2) AS avg_area, --средняя площадь
    ROUND(AVG(ceiling_height)::numeric,2) AS avg_ceiling, -- средняя высота потолка
    ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms)::numeric,0) AS mediana_rooms,--медиана кол-ва комнат
    ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony)::numeric,0) AS mediana_balconies, --медиана кол-ва балконов
    ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor)::numeric,0) AS mediana_floor --медиана этажности
FROM prepared
GROUP BY region, days_category
ORDER BY region, days_category;


    
 -- Задача 2: Сезонность объявлений по месяцам без учета года. Данные использованы для выводов по сезонности объявлений
--Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered AS (
    SELECT f.id, f.total_area, a.last_price, a.first_day_exposition, a.days_exposition
    FROM real_estate.flats f
    JOIN real_estate.advertisement a ON f.id = a.id
    WHERE f.id IN (
        SELECT id
        FROM real_estate.flats  
        WHERE 
            total_area < (SELECT total_area_limit FROM limits)
            AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
            AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
            AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
                AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
      AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018
),
prepared AS (
    SELECT
        id,
        EXTRACT(MONTH FROM first_day_exposition) AS month_posted,
        EXTRACT(MONTH FROM (first_day_exposition + days_exposition::int)) AS month_closed,
        total_area,
        last_price,
        CASE WHEN total_area > 0 THEN last_price / total_area END AS price_per_sqm
    FROM filtered
),
posted AS (
    SELECT
        month_posted AS month,
        COUNT(*) AS posted_count,
        AVG(price_per_sqm) AS posted_avg_price_per_sqm,
        AVG(total_area) AS posted_avg_area
    FROM prepared
    GROUP BY month_posted
),
closed AS (
    SELECT
        month_closed AS month,
        COUNT(*) AS closed_count,
        AVG(price_per_sqm) AS closed_avg_price_per_sqm,
        AVG(total_area) AS closed_avg_area
    FROM PREPARED
    GROUP BY month_closed
)
SELECT 
    (CASE  WHEN p."month" =1 THEN 'Январь' 
    WHEN p."month" =2 THEN'Февраль'
    WHEN p."month" =3 THEN'Март'
    WHEN p."month" =4 THEN'Апрель'
    WHEN p."month" =5 THEN'Май'
    WHEN p."month" =6 THEN'Июнь'
    WHEN p."month" =7 THEN 'Июль'
    WHEN p."month" =8 THEN  'Август'
    WHEN p."month" =9 THEN 'Сентябрь'
    WHEN p."month" =10 THEN 'Октябрь'
    WHEN p."month" =11 THEN  'Ноябрь'
    WHEN p."month" =12 THEN'Декабрь' END) AS MONTH,
    COALESCE(p.posted_count, 0) AS posted_count,
    COALESCE(c.closed_count, 0) AS closed_count,
    round(p.posted_avg_price_per_sqm::numeric,2) AS posted_avg_price_per_sqm,
    round(c.closed_avg_price_per_sqm::numeric,2) AS closed_avg_price_per_sqm,
    round(p.posted_avg_area::NUMERIC,2) AS posted_avg_area,
    round(c.closed_avg_area::NUMERIC,2) AS closed_avg_area,
    RANK() OVER (ORDER BY COALESCE(posted_count, 0) DESC) AS post_rank,
    RANK() OVER (ORDER BY COALESCE(closed_count, 0) DESC) AS closed_rank
FROM posted p
JOIN closed c ON p.month = c.month
ORDER BY post_rank, closed_rank;



-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
  filtered_city AS (
  	SELECT f.id, f.city_id, c.city, f.type_id, f.total_area
FROM real_estate.flats f
JOIN real_estate.city c ON c.city_id =f.city_id 
WHERE id IN (SELECT * FROM filtered_id) AND c.city <> 'Санкт-Петербург' -- исключаем Питер
  ),
prepared AS (
    SELECT
        fc.id,
        fc.city,
        a.days_exposition,
        fc.total_area,
        a.last_price ,
        (CASE WHEN fc.total_area > 0 THEN a.last_price / fc.total_area END) AS price_per_sqm,
        (a.first_day_exposition + a.days_exposition::int)::date AS date_closed
    FROM filtered_city  fc
    JOIN real_estate.advertisement a ON a.id=fc.id),
agg AS (
    SELECT
        city,
        COUNT(id) AS ad_count, --кол-во объявлений
        round(COUNT(id) FILTER (WHERE date_closed IS NOT NULL) * 100/ COUNT(id)::numeric,2) AS closed_share, --доля объявлений, которые были закрыты
        round(AVG (price_per_sqm)::NUMERIC, 2) AS avg_price_sqm, --средняя стоимость квадратнго метра
        round(AVG(total_area)::NUMERIC,2) AS avg_area, --средняя площадь
        round(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_exposition)::numeric,0) AS mediana_days_active
    FROM prepared 
    GROUP BY city 
    HAVING COUNT(id) > 50
)
SELECT *
FROM agg
ORDER BY ad_count DESC
LIMIT 15;