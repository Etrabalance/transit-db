-- SRSP week 05 | Passenger transport | 28 SELECT examples.
-- Execute AFTER complete Week 04, on the same database.
-- Every numbered query has a concrete transport-system question.
-- Read-only: no INSERT/UPDATE/DELETE/TRUNCATE.
\pset pager off
\timing on
SET TIME ZONE 'Asia/Almaty';
\echo '=== SRSP WEEK 05: SELECT, NULL, dates, strings and pagination ==='

-- 01. Какие маршруты длиннее 20 км и какой из них длиннее остальных?
\echo '[01] Routes longer than 20 km, descending'
SELECT id,number,length_km FROM transit.route
WHERE length_km > 20 ORDER BY length_km DESC,id LIMIT 25;

-- 02. Какие остановки начинаются с «Аль» при чувствительном к регистру LIKE?
\echo '[02] LIKE case-sensitive'
SELECT id,name FROM transit.stop WHERE name LIKE 'Аль%' ORDER BY id LIMIT 15;

-- 03. Что изменится, если искать «аль» без учета регистра (ILIKE)?
\echo '[03] ILIKE case-insensitive'
SELECT id,name FROM transit.stop WHERE name ILIKE 'аль%' ORDER BY id LIMIT 15;

-- 04. Какие автобусные модели имеют вместимость от 40 до 90 пассажиров?
-- Capacity lives in bus_model; bus itself references it by model_id.
\echo '[04] Bus models capacity between 40 and 90'
SELECT id,manufacturer,model_name,capacity FROM transit.bus_model
WHERE capacity BETWEEN 40 AND 90 ORDER BY capacity DESC,id LIMIT 20;

-- 05. Сколько водителей не имеют указанного телефона?
\echo '[05] Drivers with NULL phone'
SELECT count(*) AS drivers_without_phone FROM transit.driver WHERE phone IS NULL;

-- 06. Почему сравнение <> с заданным номером не показывает строки NULL?
\echo '[06] Wrong assumption: <> does NOT include NULL phones'
SELECT count(*) AS different_known_phones FROM transit.driver
WHERE phone <> '+77010000001';

-- 07. Как получить и другие номера, и NULL с помощью IS DISTINCT FROM?
\echo '[07] Correct for NULL: IS DISTINCT FROM'
SELECT count(*) AS other_numbers_including_nulls FROM transit.driver
WHERE phone IS DISTINCT FROM '+77010000001';

-- 08. Как вывести подпись вместо неизвестного телефона через COALESCE?
\echo '[08] COALESCE for optional phone'
SELECT id,last_name,first_name,COALESCE(phone::text,'Телефон не указан') AS phone_label
FROM transit.driver ORDER BY id LIMIT 20;

-- 09. Как превратить пустое отчество (после trim) в NULL через NULLIF?
\echo '[09] NULLIF and TRIM'
SELECT id,last_name, NULLIF(btrim(COALESCE(middle_name,'')),'') AS normalized_middle_name
FROM transit.driver ORDER BY id LIMIT 12;

-- 10. Какие маршруты короткие, средние и длинные (CASE)?
\echo '[10] CASE route classification'
SELECT number,length_km, CASE
 WHEN length_km < 12 THEN 'короткий'
 WHEN length_km < 25 THEN 'средний'
 ELSE 'длинный' END AS category
FROM transit.route ORDER BY length_km DESC LIMIT 20;

-- 11. Как вывести английские ENUM-статусы рейса русскими словами?
\echo '[11] CASE trip ENUM labels'
SELECT id, status, CASE status
 WHEN 'scheduled' THEN 'Запланирован'
 WHEN 'in_progress' THEN 'В пути'
 WHEN 'completed' THEN 'Завершён'
 WHEN 'cancelled' THEN 'Отменён'
 END AS status_ru FROM transit.trip ORDER BY id LIMIT 15;

-- 12. Какие рейсы планировались вчера по местному времени?
\echo '[12] Yesterday using CURRENT_DATE'
SELECT id,planned_start_at,status FROM transit.trip
WHERE planned_start_at >= (CURRENT_DATE-1)::timestamp AT TIME ZONE 'Asia/Almaty'
 AND planned_start_at < CURRENT_DATE::timestamp AT TIME ZONE 'Asia/Almaty'
ORDER BY planned_start_at LIMIT 20;

-- 13. Сколько рейсов запланировано в текущем календарном месяце?
\echo '[13] Current month without function on indexed column'
SELECT count(*) AS trips_this_month FROM transit.trip
WHERE planned_start_at >= date_trunc('month',CURRENT_TIMESTAMP)
  AND planned_start_at < date_trunc('month',CURRENT_TIMESTAMP)+INTERVAL '1 month';

-- 14. Сколько рейсов было в последние 7 дней?
\echo '[14] Last seven days'
SELECT count(*) AS trips_last_7days FROM transit.trip
WHERE planned_start_at >= CURRENT_TIMESTAMP-INTERVAL '7 days'
  AND planned_start_at < CURRENT_TIMESTAMP;

-- 15. Сколько фактически длились завершённые рейсы (timestamptz difference)?
\echo '[15] Elapsed trip minutes'
SELECT id,actual_start_at,actual_end_at,
 round(extract(epoch FROM(actual_end_at-actual_start_at))::numeric/60,2) AS actual_minutes
FROM transit.trip
WHERE actual_start_at IS NOT NULL AND actual_end_at IS NOT NULL
ORDER BY id LIMIT 15;

-- 16. Сколько GPS-замеров за каждый час 1 января 2025 (date_trunc)?
\echo '[16] Hourly telemetry aggregation'
SELECT date_trunc('hour',observed_at AT TIME ZONE 'Asia/Almaty') AS local_hour,
       count(*) AS gps_positions
FROM transit.vehicle_position
WHERE observed_at >= TIMESTAMPTZ '2025-01-01 00:00:00+05'
  AND observed_at < TIMESTAMPTZ '2025-01-02 00:00:00+05'
GROUP BY 1 ORDER BY 1;

-- 17. Сколько рейсов по дням недели (EXTRACT(dow)) в первой неделе 2025?
\echo '[17] Trip counts by weekday'
SELECT extract(dow FROM planned_start_at AT TIME ZONE 'Asia/Almaty')::int AS weekday_0_sun,
       count(*) AS trips
FROM transit.trip
WHERE planned_start_at >= TIMESTAMPTZ '2025-01-01 00:00:00+05'
 AND planned_start_at < TIMESTAMPTZ '2025-01-08 00:00:00+05'
GROUP BY 1 ORDER BY 1;

-- 18. Сколько рейсов пришлось на выходные в 2025 году?
\echo '[18] Saturday and Sunday trips'
SELECT count(*) AS weekend_trips_2025 FROM transit.trip
WHERE planned_start_at >= TIMESTAMPTZ '2025-01-01 00:00:00+05'
 AND planned_start_at < TIMESTAMPTZ '2026-01-01 00:00:00+05'
 AND extract(dow FROM planned_start_at AT TIME ZONE 'Asia/Almaty') IN (0,6);

-- 19. Как один момент времени выглядит в UTC и в Алматы (AT TIME ZONE)?
\echo '[19] One timestamptz instant in two time zones'
SELECT id, planned_start_at,
 planned_start_at AT TIME ZONE 'UTC' AS utc_clock,
 planned_start_at AT TIME ZONE 'Asia/Almaty' AS almaty_clock
FROM transit.trip ORDER BY id LIMIT 8;

-- 20. Как показать календарь всех дней текущего месяца, включая дни БЕЗ рейсов?
\echo '[20] Calendar generate_series including empty days'
SELECT g.day::date AS calendar_day,
 (SELECT count(*) FROM transit.trip t
  WHERE t.planned_start_at >= (g.day::date::timestamp AT TIME ZONE 'Asia/Almaty')
    AND t.planned_start_at < ((g.day::date+1)::timestamp AT TIME ZONE 'Asia/Almaty')) AS trips
FROM generate_series(date_trunc('month',CURRENT_DATE::timestamp),
 date_trunc('month',CURRENT_DATE::timestamp)+INTERVAL '1 month'-INTERVAL '1 day',
 INTERVAL '1 day') AS g(day)
ORDER BY 1;

-- 21. Как показать вторую страницу справочника остановок по 20 записей?
\echo '[21] LIMIT/OFFSET page 2'
SELECT id,name FROM transit.stop ORDER BY id LIMIT 20 OFFSET 20;

-- 22. Как получить следующую страницу эффективнее с помощью keyset (id > last_seen)?
\echo '[22] Keyset pagination instead of huge OFFSET'
SELECT id,name FROM transit.stop WHERE id > 800020 ORDER BY id LIMIT 20;

-- 23. Как привести регистр и убрать подряд идущие пробелы в имени остановки?
\echo '[23] Normalize stop name (display only)'
SELECT id,name,
 initcap(regexp_replace(btrim(name),'[[:space:]]+',' ','g')) AS clean_name
FROM transit.stop ORDER BY id LIMIT 15;

-- 24. Как собрать полное ФИО водителя из трёх полей с concat_ws/trim/initcap?
\echo '[24] Concatenate full driver name'
SELECT id,concat_ws(' ',initcap(btrim(last_name)),initcap(btrim(first_name)),
 initcap(NULLIF(btrim(COALESCE(middle_name,'')),''))) AS full_name
FROM transit.driver ORDER BY id LIMIT 15;

-- 25. Как сгруппировать рейсы по месяцу 2025 года (date_trunc)?
\echo '[25] Trips by month'
SELECT date_trunc('month',planned_start_at AT TIME ZONE 'Asia/Almaty')::date AS month,
 count(*) AS trips
FROM transit.trip
WHERE planned_start_at >= TIMESTAMPTZ '2025-01-01 00:00:00+05'
  AND planned_start_at < TIMESTAMPTZ '2026-01-01 00:00:00+05'
GROUP BY 1 ORDER BY 1;

-- 26. Как узнать, насколько фактическое отправление позже планового?
\echo '[26] Delay from two timestamptz values'
SELECT id,
 round(extract(epoch FROM(actual_start_at-planned_start_at))::numeric/60,2) AS delay_minutes
FROM transit.trip WHERE actual_start_at IS NOT NULL
ORDER BY id LIMIT 15;

-- 27. Как сгруппировать наряды по статусу и дате без связи с другими таблицами?
\echo '[27] Assignments on first 3 dates'
SELECT service_date,status,count(*) AS assignments
FROM transit.assignment WHERE service_date BETWEEN DATE '2025-01-01' AND DATE '2025-01-03'
GROUP BY service_date,status ORDER BY service_date,status;

-- 28. Как найти автобусные модели без значения fuel_type (демонстрация IS NULL)?
\echo '[28] NULL in a required field is impossible; shows difference between NULL and empty string'
SELECT count(*) AS null_fuel_types FROM transit.bus_model WHERE fuel_type IS NULL;
\echo '=== END OF SRSP WEEK 05: 28 read-only SELECT queries ==='
