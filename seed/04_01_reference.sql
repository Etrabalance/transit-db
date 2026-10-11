-- SRSP week 04 / 01: synthetic training reference data for transit (Almaty area).
-- IMPORTANT: these route and stop rows are SIMULATED, NOT official open data.
-- Week 4 requires open-source routes/stops. See seed/04_OPEN_DATA_NOTICE.md.
-- Run only after Week 03 migration. Safe to re-run; existing Week 1 data unchanged.
\pset pager off
\timing on
\echo '=== 04/01 REFERENCE DATA (synthetic training dataset) ==='
BEGIN;
SELECT setseed(0.2025);
-- Additional bus models, IDs reserved for training.
INSERT INTO transit.bus_model(id,manufacturer,model_name,capacity,fuel_type)
OVERRIDING SYSTEM VALUE
SELECT 905000+i, (ARRAY['Yutong','MAN','Mercedes','Ankai','Golden Dragon'])[i],
       'Training-'||i, (ARRAY[65,85,105,55,75])[i],
       (ARRAY['diesel','gas','electric','diesel','gas'])[i]
FROM generate_series(1,5) AS g(i)
WHERE true
ON CONFLICT (id) DO UPDATE SET manufacturer=EXCLUDED.manufacturer,
    model_name=EXCLUDED.model_name, capacity=EXCLUDED.capacity, fuel_type=EXCLUDED.fuel_type;
-- Exactly 40 training routes; deliberately prefixed W4 so they cannot be mistaken for official routes.
INSERT INTO transit.route(id,number,length_km,start_date)
OVERRIDING SYSTEM VALUE
SELECT 900000+i,'W4-'||lpad(i::text,2,'0'),(10+i*0.65)::numeric(6,2),DATE '2025-01-01'
FROM generate_series(1,40) AS g(i)
WHERE true
ON CONFLICT (id) DO UPDATE SET number=EXCLUDED.number,
 length_km=EXCLUDED.length_km,start_date=EXCLUDED.start_date;
-- 600 synthetic stops, 15 stops / 40 routes; coords are near Almaty, not sourced stop geometry.
INSERT INTO transit.stop(id,name,latitude,longitude)
OVERRIDING SYSTEM VALUE
SELECT 800000+i,
 CASE WHEN i%15=1 THEN 'Аль-Фараби (учебная) '||((i-1)/15+1)
      ELSE 'Учебная остановка W4 '||lpad(i::text,3,'0') END,
 round((43.1000+((i-1)/15)*0.005 + ((i-1)%15)*0.0015)::numeric,6),
 round((76.7000+((i-1)/15)*0.004 + ((i-1)%15)*0.002)::numeric,6)
FROM generate_series(1,600) AS g(i)
WHERE true
ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name,
 latitude=EXCLUDED.latitude,longitude=EXCLUDED.longitude;
-- Connect 15 route-appropriate synthetic stops, with stable order and distance.
INSERT INTO transit.route_stop(route_id,stop_id,stop_order,distance_from_start_km,is_terminal)
SELECT 900000+r, 800000+(r-1)*15+s, s, (s-1)*0.75, s=15
FROM generate_series(1,40) AS g(r) CROSS JOIN generate_series(1,15) AS h(s)
WHERE true
ON CONFLICT ON CONSTRAINT route_stop_route_order_uq DO UPDATE
SET stop_id=EXCLUDED.stop_id,distance_from_start_km=EXCLUDED.distance_from_start_km,
    is_terminal=EXCLUDED.is_terminal;
-- 2 shifts (local time) and 400 simulated KZ-format registrations.
INSERT INTO transit.shift(id,name,starts_at,ends_at,crosses_midnight)
OVERRIDING SYSTEM VALUE
VALUES (930001,'W4 Morning','06:00','14:00',false),
       (930002,'W4 Evening','14:00','22:00',false)
ON CONFLICT (id) DO UPDATE SET starts_at=EXCLUDED.starts_at,
ends_at=EXCLUDED.ends_at,crosses_midnight=EXCLUDED.crosses_midnight;
INSERT INTO transit.bus(id,model_id,depot_id,registration_no,year_manufactured,status)
OVERRIDING SYSTEM VALUE
SELECT 910000+i,905001+((i-1)%5), (SELECT id FROM transit.depot ORDER BY id LIMIT 1),
       lpad(i::text,3,'0')||'AAA02',2020+((i-1)%5),'active'
FROM generate_series(1,400) AS g(i)
WHERE true
ON CONFLICT (id) DO UPDATE SET model_id=EXCLUDED.model_id,
 depot_id=EXCLUDED.depot_id, registration_no=EXCLUDED.registration_no,
 year_manufactured=EXCLUDED.year_manufactured,status=EXCLUDED.status;
-- 500 simulated drivers; NULL phone in every tenth row to support Week 05 NULL examples.
INSERT INTO transit.driver(id,depot_id,last_name,first_name,middle_name,phone,hire_date,birth_date,experience_years)
OVERRIDING SYSTEM VALUE
SELECT 920000+i, (SELECT id FROM transit.depot ORDER BY id LIMIT 1),
 (ARRAY['Омаров','Ким','Садыков','Иванов','Ахметов','Жумабаев','Серикбаев','Касымов','Пак','Ибраев'])[(i-1)%10+1],
 (ARRAY['Аян','Данияр','Айбек','Тимур','Руслан','Ермек','Алмас','Арман','Дамир','Азамат'])[(i-1)%10+1],
 NULL,
 CASE WHEN i%10=0 THEN NULL ELSE ('+7701'||lpad(i::text,7,'0'))::transit.phone_kz END,
 DATE '2017-03-01', DATE '1980-01-01', 15
FROM generate_series(1,500) AS g(i)
WHERE true
ON CONFLICT (id) DO UPDATE SET last_name=EXCLUDED.last_name,
 first_name=EXCLUDED.first_name,phone=EXCLUDED.phone,hire_date=EXCLUDED.hire_date,
 birth_date=EXCLUDED.birth_date, experience_years=EXCLUDED.experience_years;
COMMIT;
\echo 'Reference counts (include the Week 01 rows):'
SELECT 'route' AS table_name,count(*) FROM transit.route UNION ALL
SELECT 'stop',count(*) FROM transit.stop UNION ALL
SELECT 'bus',count(*) FROM transit.bus UNION ALL
SELECT 'driver',count(*) FROM transit.driver ORDER BY 1;
