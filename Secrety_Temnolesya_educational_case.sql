/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Наталья Мартынова
 * Дата: 31 июля 2025 года
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:

SELECT *,
       total_payers :: NUMERIC / total_users AS payers_share -- доля платящих игроков от общего количества пользователей
FROM (
    SELECT COUNT (id) AS total_users, -- общее количество игроков, зарегистрированных в игре
           SUM (payer) AS total_payers -- количество платящих игроков
    FROM fantasy.users) AS subquery;

-- total_users|total_payers|payers_share          |
-- -----------+------------+----------------------+
--       22214|        3929|0.17687044206356351850|

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

SELECT race, -- раса персонажа
       SUM (payer) AS payers_count, -- количество платящих игроков этой расы
       COUNT (id) AS total_users, -- общее количество зарегистрированных игроков этой расы
       SUM (payer) :: NUMERIC / COUNT (id) AS payers_share -- доля платящих игроков среди всех зарегистрированных игроков этой расы
FROM fantasy.users AS u 
JOIN fantasy.race AS r USING (race_id)
GROUP BY race;

-- race    |payers_count|total_users|payers_share          |
-- --------+------------+-----------+----------------------+
-- Angel   |         229|       1327|0.17256970610399397136|
-- Elf     |         427|       2501|0.17073170731707317073|
-- Demon   |         238|       1229|0.19365337672904800651|
-- Orc     |         636|       3619|0.17573915446255871788|
-- Human   |        1114|       6328|0.17604298356510745891|
-- Northman|         626|       3562|0.17574396406513194834|
-- Hobbit  |         659|       3648|0.18064692982456140351|

-- Задача 2. Исследование внутриигровых покупок

-- 2.1. Статистические показатели по полю amount:

SELECT COUNT (transaction_id) AS transactions_count, -- общее количество покупок
       SUM (amount) AS total_amount, -- суммарная стоимость всех покупок
       MIN (amount) AS min_amount, -- минимальная стоимость покупки
       MAX (amount) AS max_amount, -- максимальная стоимость покупки
       AVG (amount) AS avg_amount, -- среднее значение стоимости покупки
       PERCENTILE_DISC (0.5) WITHIN GROUP (ORDER BY amount) AS amount_median, -- медиана стоимости покупки
       STDDEV (amount) AS stand_dev_amount -- стандартное отклонение стоимости покупки
FROM fantasy.events;

-- transactions_count|total_amount|min_amount|max_amount|avg_amount       |amount_median|stand_dev_amount |
-- ------------------+------------+----------+----------+-----------------+-------------+-----------------+
--            1307678|   686615040|       0.0|  486615.1|525.6919663589833|        74.86|2517.345444427788|

-- 2.2: Аномальные нулевые покупки:

SELECT COUNT (transaction_id) AS null_transactions_count, -- количество покупок с нулевой стоимостью
       COUNT (transaction_id) :: NUMERIC / (
                                            SELECT COUNT (transaction_id) -- общее число покупок
                                            FROM fantasy.events) AS null_transactions_share -- доля покупок с нулевой стоимостью от общего числа покупок
FROM fantasy.events
WHERE amount = 0;

-- null_transactions_count|null_transactions_share|
-- -----------------------+-----------------------+
--                     907| 0.00069359582404842782|

-- 2.3: Популярные эпические предметы:

SELECT game_items, -- название эпического предмета
       COUNT (transaction_id) AS transactions_count, -- общее количество внутриигровых продаж эпического предмета
       COUNT (transaction_id) :: NUMERIC / (
                                            SELECT COUNT (transaction_id) -- общее число продаж
                                            FROM fantasy.events AS e 
                                            JOIN fantasy.items AS i USING (item_code)
                                            WHERE amount <> 0) AS game_item_transactions_share, -- доля продаж эпического предмета от всех продаж
       COUNT (DISTINCT id) :: NUMERIC / (
                                            SELECT COUNT (DISTINCT id) -- общее число внутриигровых покупателей
                                            FROM fantasy.events AS e 
                                            JOIN fantasy.items AS i USING (item_code)
                                            WHERE amount <> 0) AS game_item_users_share -- доля игроков, которые хотя бы раз покупали этот предмет
FROM fantasy.events AS e 
JOIN fantasy.items AS i USING (item_code)
WHERE amount <> 0 -- исключаем из расчётов покупки с нулевой стоимостью
GROUP BY game_items
ORDER BY transactions_count DESC
LIMIT 5;

-- game_items               |transactions_count|game_item_transactions_share|game_item_users_share     |
-- -------------------------+------------------+----------------------------+--------------------------+
-- Book of Legends          |           1004516|      0.76870086648693611964|    0.88413573085846867749|
-- Bag of Holding           |            271875|      0.20805098980617108889|    0.86774941995359628770|
-- Necklace of Wisdom       |             13828|      0.01058180813623810140|    0.11796693735498839907|
-- Gems of Insight          |              3833|      0.00293318416157077254|    0.06714037122969837587|
-- Treasure Map             |              3183|      0.00243577489858590373|    0.05938225058004640371|


-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:

WITH total_users AS (
SELECT race,
       COUNT (id) AS users_count -- общее количество зарегистрированных игроков
FROM fantasy.users AS u 
JOIN fantasy.race AS r USING (race_id)
GROUP BY race
),
users_with_transactions AS (
SELECT race,
       COUNT (DISTINCT id) AS users_with_transactions_count, -- количество игроков, которые совершают внутриигровые покупки
       COUNT (transaction_id) AS transactions_count, -- общее количество покупок
       SUM (amount) AS total_amount, -- суммарная стоимость покупок
       AVG (amount) AS avg_amount -- средняя стоимость покупки
FROM fantasy.users AS u 
JOIN fantasy.race AS r USING (race_id)
LEFT JOIN fantasy.events AS e USING (id)
WHERE amount <> 0 AND amount IS NOT NULL
GROUP BY race
),
payers_with_transactions AS (
     SELECT race,
            COUNT (DISTINCT id) AS payers_with_transactions_count -- количество платящих игроков с покупками
     FROM fantasy.users AS u 
     JOIN fantasy.race AS r USING (race_id)
     LEFT JOIN fantasy.events AS e USING (id)
     WHERE amount <> 0 
          AND amount IS NOT NULL
          AND payer = 1
     GROUP BY race
) 
SELECT race,
       users_count, -- общее количество зарегистрированных игроков
       users_with_transactions_count, -- количество игроков, которые совершили внутриигровые покупки
       users_with_transactions_count :: NUMERIC / users_count AS users_with_transactions_share, -- доля игроков с покупками от общего количества зарегистрированных игроков
       payers_with_transactions_count :: NUMERIC / users_with_transactions_count AS payers_share, -- доля платящих игроков среди игроков, которые совершили внутриигровые покупки
       transactions_count :: NUMERIC / users_with_transactions_count AS avg_transactions, -- среднее количество покупок на одного игрока, совершившего внутриигровые покупки
       avg_amount AS avg_amount_per_user_with_transactions, -- средняя стоимость одной покупки на одного игрока, совершившего внутриигровые покупки
       total_amount :: NUMERIC / users_with_transactions_count AS avg_sum_amount -- средняя суммарная стоимость всех покупок на одного игрока, совершившего внутриигровые покупки
FROM total_users AS tu 
JOIN users_with_transactions AS uwt USING (race)
JOIN payers_with_transactions AS pwt USING (race);

-- race    |users_count|users_with_transactions_count|users_with_transactions_share|payers_share          |avg_transactions    |avg_amount_per_user_with_transactions|avg_sum_amount    |
-- --------+-----------+-----------------------------+-----------------------------+----------------------+--------------------+-------------------------------------+------------------+
-- Angel   |       1327|                          820|       0.61793519216277317257|0.16707317073170731707|106.8048780487804878|                    455.6781658192919|48665.609756097561|
-- Demon   |       1229|                          737|       0.59967453213995117982|0.19945725915875169607| 77.8697421981004071|                    529.0550736998875|41194.979647218453|
-- Elf     |       2501|                         1543|       0.61695321871251499400|0.16267012313674659754| 78.7906675307841866|                    682.3347716039251|53760.920285158782|
-- Hobbit  |       3648|                         2266|       0.62116228070175438596|0.17696381288614298323| 86.1288614298323036|                    552.9031464449795|47622.683142100618|
-- Human   |       6328|                         3921|       0.61962705436156763590|0.18005610813567967355|121.4021933180311145|                    403.1307966460305|48935.475643968375|
-- Northman|       3562|                         2229|       0.62577203818079730488|0.18214445939883355765| 82.1018393898609242|                    761.5012180548542|62519.964109466128|
-- Orc     |       3619|                         2276|       0.62890301188173528599|0.17398945518453427065| 81.7381370826010545|                    510.9002556814827|41762.565905096661|