/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Мартынова Наталья
 * Дата: 22 августа 2025
*/

-- Пример фильтрации данных от аномальных значений
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
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Задача 1: Время активности объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. Какие сегменты рынка недвижимости Санкт-Петербурга и городов Ленинградской области 
--    имеют наиболее короткие или длинные сроки активности объявлений?
-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, 
--    количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
--    Как эти зависимости варьируют между регионами?
-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?

-- Из ревью: стоит также вывести количество объектов по полученным сегментам, это позволит нам точнее оценить доли рынка 
-- (добавлено число квартир и доля каждой категории от общего количества по региону)

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
-- Разделим объявления на категории по длительности размещения
    categories AS (
SELECT *,
       CASE
       	WHEN days_exposition < 30
       	  THEN '1_Краткосрочные объявления'
       	WHEN days_exposition > 95
       	  THEN '3_Долгосрочные объявления'
       	ELSE '2_Среднесрочные объявления'
       	END AS exposition_category
FROM real_estate.advertisement 
WHERE days_exposition IS NOT NULL
)
-- Основной запрос, склеенный из двух таблиц: по СПб и по городам Ленобласти
SELECT 'Санкт-Петербург' AS region,
       exposition_category,
       COUNT (f.id) AS flats_count,
       ROUND (COUNT (f.id) :: numeric / (SELECT COUNT (id) 
                                         FROM real_estate.flats AS f
                                         JOIN real_estate.advertisement AS a USING (id)
                                         JOIN real_estate.city AS ci USING (city_id)
                                         WHERE days_exposition IS NOT NULL
                                         AND id IN (SELECT * FROM filtered_id) 
                                         AND ci.city = 'Санкт-Петербург'), 2) AS share_into_region,
       AVG (last_price ::real / total_area) AS avg_cost_per_meter,
       AVG (total_area) AS avg_total_area,
       AVG (rooms) AS avg_rooms,
       AVG (balcony) AS avg_balcony
FROM categories AS c
JOIN real_estate.flats AS f USING (id)
JOIN real_estate.city AS ci USING (city_id)
WHERE id IN (SELECT * FROM filtered_id) 
   AND ci.city = 'Санкт-Петербург' 
GROUP BY exposition_category 
UNION ALL
SELECT 'города Лен области',
       exposition_category,
       COUNT (f.id) AS flats_count,
       ROUND (COUNT (f.id) :: numeric / (SELECT COUNT (id) 
                               FROM real_estate.flats AS f
                               JOIN real_estate.city AS ci USING (city_id)
                               JOIN real_estate.TYPE AS t USING (type_id)
                               JOIN real_estate.advertisement AS a USING (id)
                               WHERE days_exposition IS NOT NULL
                                   AND id IN (SELECT * FROM filtered_id) 
                                   AND t."type" = 'город'
                                   AND ci.city <> 'Санкт-Петербург'), 2) AS share_into_region,
       AVG (last_price ::real / total_area) AS avg_cost_per_meter,
       AVG (total_area) AS avg_total_area,
       AVG (rooms) AS avg_rooms,
       AVG (balcony) AS avg_balcony
FROM categories AS c
JOIN real_estate.flats AS f USING (id)
JOIN real_estate.TYPE AS t USING (type_id)
JOIN real_estate.city AS ci USING (city_id)
WHERE id IN (SELECT * FROM filtered_id) 
   AND t."type" = 'город'
   AND ci.city <> 'Санкт-Петербург' 
GROUP BY exposition_category 
--ORDER BY exposition_category
;

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

-- Из ревью: Также, как и в первой задаче, стоит добавить фильтр на города (добавлен)
-- Что можно улучшить:
-- стоит учитывать, что у нас могут быть данные за неполные годы (2014 и 2019) - их не стоит учитывать в анализе
-- можно использовать функцию RANK для ранжирования по количеству публикаций и снятий
-- можно также посчитать доли количества публикации и снятия объявлений по месяцам – это значительно упрощает анализ

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
),
last_days_exposition AS (
SELECT *,
      (first_day_exposition + make_interval (days => days_exposition::integer)) :: date AS last_day_exposition
FROM real_estate.advertisement
WHERE days_exposition IS NOT NULL
)
SELECT 'Месяц размещения объявления' AS month_category,
       EXTRACT (MONTH FROM first_day_exposition) AS month,
       COUNT (id) AS adv_count,
       AVG (last_price ::real / total_area) AS avg_cost_per_meter,
       AVG (total_area) AS avg_total_area,
       RANK () OVER (ORDER BY COUNT (id) DESC) AS RANK, -- ранжирование по количеству публикаций
       ROUND (COUNT (id) :: NUMERIC / (SELECT COUNT (id)
                                       FROM real_estate.advertisement AS a 
                                       JOIN real_estate.flats AS f USING (id)
                                       JOIN real_estate.TYPE AS t USING (type_id)
                                       WHERE  t."type" = 'город'
                                          AND EXTRACT (YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
                                          ), 2) AS share_into_month -- доли количества публикаций по месяцам
FROM real_estate.advertisement AS a 
JOIN real_estate.flats AS f USING (id)
JOIN real_estate.TYPE AS t USING (type_id)
WHERE  t."type" = 'город' -- фильтр на города
   AND EXTRACT (YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018 -- исключаем неполные года
GROUP BY EXTRACT (MONTH FROM first_day_exposition)
UNION ALL 
SELECT 'Месяц снятия объявления' AS month_category,
       EXTRACT (MONTH FROM last_day_exposition) AS month,
       COUNT (id) AS adv_count,
       AVG (last_price ::real / total_area) AS avg_cost_per_meter,
       AVG (total_area) AS avg_total_area,
       RANK () OVER (ORDER BY COUNT (id) DESC) AS RANK, -- ранжирование по количеству снятий
       ROUND (COUNT (id) :: NUMERIC / (SELECT COUNT (id)
                                       FROM last_days_exposition AS l
                                       JOIN real_estate.flats AS f USING (id)
                                       JOIN real_estate.TYPE AS t USING (type_id)
                                       WHERE  t."type" = 'город'
                                       AND EXTRACT (YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
                                       ), 2) AS share_into_month -- доли количества снятий объявлений по месяцам
FROM last_days_exposition AS l
JOIN real_estate.flats AS f USING (id)
JOIN real_estate.TYPE AS t USING (type_id)
WHERE  t."type" = 'город' -- фильтр на города
   AND EXTRACT (YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018 -- исключаем неполные года
GROUP BY EXTRACT (MONTH FROM last_day_exposition)
ORDER BY "month", month_category
;

-- Задача 3: Анализ рынка недвижимости Ленобласти
-- Результат запроса должен ответить на такие вопросы:
-- 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
-- 2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? 
--    Это может указывать на высокую долю продажи недвижимости.
-- 3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? 
--    Есть ли вариация значений по этим метрикам?
-- 4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? 
--    То есть где недвижимость продаётся быстрее, а где — медленнее.

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
)
SELECT city,
       COUNT (a.id) AS adv_count,
       ROUND ((COUNT (a.id) FILTER (WHERE days_exposition IS NOT NULL) :: NUMERIC / COUNT (a.id)), 2) AS share_of_removed,
       AVG (days_exposition) AS avg_days_exposition,
       AVG (last_price ::real / total_area) AS avg_cost_per_meter,
       AVG (total_area) AS avg_total_area,
       AVG (rooms) AS avg_rooms,
       AVG (balcony) AS avg_balcony
FROM real_estate.city AS c
JOIN real_estate.flats f USING (city_id)
JOIN real_estate.advertisement a USING (id)
WHERE city <> 'Санкт-Петербург'
   AND a.id IN (SELECT * FROM filtered_id)
GROUP BY city 
ORDER BY adv_count DESC
LIMIT 15;

-- Задача 2: Сезонность объявлений
-- Результат запроса должен ответить на такие вопросы:
-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? 
--    А в какие — по снятию? Это показывает динамику активности покупателей.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, 
--    когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? 
--    Что можно сказать о зависимости этих параметров от месяца?

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
),
last_days_exposition AS (
SELECT *,
      (first_day_exposition + make_interval (days => days_exposition::integer)) :: date AS last_day_exposition
FROM real_estate.advertisement
WHERE days_exposition IS NOT NULL
)
SELECT 'Месяц размещения объявления' AS month_category,
       EXTRACT (MONTH FROM first_day_exposition) AS month,
       COUNT (id) AS adv_count,
       AVG (last_price ::real / total_area) AS avg_cost_per_meter,
       AVG (total_area) AS avg_total_area
FROM real_estate.advertisement AS a 
JOIN real_estate.flats AS f USING (id)
GROUP BY EXTRACT (MONTH FROM first_day_exposition)
UNION ALL 
SELECT 'Месяц снятия объявления' AS month_category,
       EXTRACT (MONTH FROM last_day_exposition) AS month,
       COUNT (id) AS adv_count,
       AVG (last_price ::real / total_area) AS avg_cost_per_meter,
       AVG (total_area) AS avg_total_area
FROM last_days_exposition AS l
JOIN real_estate.flats AS f USING (id)
GROUP BY EXTRACT (MONTH FROM last_day_exposition)
ORDER BY "month", month_category