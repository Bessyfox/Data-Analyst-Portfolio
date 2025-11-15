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

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

SELECT race, -- раса персонажа
       SUM (payer) AS payers_count, -- количество платящих игроков этой расы
       COUNT (id) AS total_users, -- общее количество зарегистрированных игроков этой расы
       SUM (payer) :: NUMERIC / COUNT (id) AS payers_share -- доля платящих игроков среди всех зарегистрированных игроков этой расы
FROM fantasy.users AS u 
JOIN fantasy.race AS r USING (race_id)
GROUP BY race;

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

-- 2.2: Аномальные нулевые покупки:

SELECT COUNT (transaction_id) AS null_transactions_count, -- количество покупок с нулевой стоимостью
       COUNT (transaction_id) :: NUMERIC / (
                                            SELECT COUNT (transaction_id) -- общее число покупок
                                            FROM fantasy.events) AS null_transactions_share -- доля покупок с нулевой стоимостью от общего числа покупок
FROM fantasy.events
WHERE amount = 0;

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
ORDER BY transactions_count DESC;

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