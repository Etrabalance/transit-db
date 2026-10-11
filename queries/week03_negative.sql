-- SRSP Week 03: negative tests. Execute ONLY after successful 03_constraints.sql.
-- Deliberately produces 14 ERROR messages. Setup and ALL changes are rolled back.
-- SQLSTATE codes and constraint names printed by VERBOSITY verbose.
\pset pager off
\set VERBOSITY verbose
\set ON_ERROR_STOP on
\echo '=== SRSP WEEK 03: START NEGATIVE TESTS ==='
BEGIN;
SET LOCAL search_path TO transit, public;

-- Use genuine Week 1 parent rows: do not assume their identifiers start at 1.
SELECT id AS depot_id FROM transit.depot ORDER BY id LIMIT 1
\gset
SELECT id AS route_id FROM transit.route ORDER BY id LIMIT 1
\gset
SELECT id AS stop_id FROM transit.stop ORDER BY id LIMIT 1
\gset

-- Synthetic valid fixtures. The final ROLLBACK will remove them.
INSERT INTO transit.bus_model(manufacturer,model_name,capacity,fuel_type)
VALUES ('Week03Demo','Temporary Model',50,'diesel') RETURNING id AS model_id
\gset
INSERT INTO transit.bus(model_id,depot_id,registration_no,year_manufactured,status)
VALUES (:model_id,:depot_id,'KZ-W3-0001',2020,'active') RETURNING id AS bus_id
\gset
INSERT INTO transit.driver(depot_id,last_name,first_name,phone,hire_date,birth_date,experience_years)
VALUES (:depot_id,'DemoDriver','Test','+77012345678','2020-01-01','1985-01-01',15)
RETURNING id AS driver_id
\gset
INSERT INTO transit.shift(name,starts_at,ends_at,crosses_midnight)
VALUES ('Temporary Week03 Day Shift','08:00','16:00',false) RETURNING id AS shift_id
\gset
INSERT INTO transit.assignment(route_id,bus_id,driver_id,shift_id,service_date,status)
VALUES (:route_id,:bus_id,:driver_id,:shift_id,'2026-10-12','completed') RETURNING id AS assignment_id
\gset
INSERT INTO transit.trip(assignment_id,trip_number,planned_start_at,planned_end_at,
                        actual_start_at,actual_end_at,status)
VALUES (:assignment_id,1,'2026-10-12 08:00:00+05','2026-10-12 09:00:00+05',
        '2026-10-12 08:05:00+05','2026-10-12 08:55:00+05','completed') RETURNING id AS trip_id
\gset
INSERT INTO transit.route_stop(route_id,stop_id,stop_order,distance_from_start_km,is_terminal)
VALUES (:route_id,:stop_id,990001,0,false) RETURNING id AS route_stop_id
\gset
INSERT INTO transit.vehicle_position(trip_id,observed_at,latitude,longitude,speed_kmh)
VALUES (:trip_id,'2026-10-12 08:30:00+05',43.250000,76.920000,25)
RETURNING id AS position_id
\gset
INSERT INTO transit.applicant(full_name,phone)
VALUES ('Temporary Applicant','+77071234567') RETURNING id AS applicant_id
\gset
INSERT INTO transit.service_request(applicant_id,route_id,title,description,status)
VALUES (:applicant_id,:route_id,'Delay report','The bus was delayed at the stop','new')
RETURNING id AS request_id
\gset

-- Errors below are EXPECTED. Savepoints allow continuing after each failure.
\set ON_ERROR_STOP off

\echo '[01/14] EXPECT 23503 bus_model_id_fkey (missing bus model)'
SAVEPOINT negative01;
INSERT INTO transit.bus(model_id,depot_id,registration_no,year_manufactured,status)
VALUES (987654321,:depot_id,'KZ-W3-0002',2020,'active');
ROLLBACK TO SAVEPOINT negative01;

\echo '[02/14] EXPECT 23514 stop_latitude_bounds_ck'
SAVEPOINT negative02;
UPDATE transit.stop SET latitude=100 WHERE id=:stop_id;
ROLLBACK TO SAVEPOINT negative02;

\echo '[03/14] EXPECT 23514 stop_longitude_bounds_ck'
SAVEPOINT negative03;
UPDATE transit.stop SET longitude=181 WHERE id=:stop_id;
ROLLBACK TO SAVEPOINT negative03;

\echo '[04/14] EXPECT 23514 bus_model_capacity_ck'
SAVEPOINT negative04;
INSERT INTO transit.bus_model(manufacturer,model_name,capacity,fuel_type)
VALUES ('Week03Demo','Impossible model',0,'diesel');
ROLLBACK TO SAVEPOINT negative04;

\echo '[05/14] EXPECT 23505 bus_active_registration_uq (active plates)'
SAVEPOINT negative05;
INSERT INTO transit.bus(model_id,depot_id,registration_no,year_manufactured,status)
VALUES (:model_id,:depot_id,'KZ-W3-0001',2021,'active');
ROLLBACK TO SAVEPOINT negative05;

\echo '[06/14] EXPECT 23505 route_stop_route_order_uq'
SAVEPOINT negative06;
INSERT INTO transit.route_stop(route_id,stop_id,stop_order,distance_from_start_km)
VALUES (:route_id,:stop_id,990001,2.0);
ROLLBACK TO SAVEPOINT negative06;

\echo '[07/14] EXPECT 23505 assignment_bus_date_shift_uq'
SAVEPOINT negative07;
INSERT INTO transit.assignment(route_id,bus_id,driver_id,shift_id,service_date,status)
VALUES (:route_id,:bus_id,:driver_id,:shift_id,'2026-10-12','scheduled');
ROLLBACK TO SAVEPOINT negative07;

\echo '[08/14] EXPECT 23514 shift_time_rules_ck'
SAVEPOINT negative08;
UPDATE transit.shift SET ends_at='06:00' WHERE id=:shift_id;
ROLLBACK TO SAVEPOINT negative08;

\echo '[09/14] EXPECT 23514 trip_planned_time_ck'
SAVEPOINT negative09;
UPDATE transit.trip SET planned_end_at=planned_start_at - INTERVAL '1 minute' WHERE id=:trip_id;
ROLLBACK TO SAVEPOINT negative09;

\echo '[10/14] EXPECT 23514 vehicle_position_speed_ck'
SAVEPOINT negative10;
UPDATE transit.vehicle_position SET speed_kmh=85 WHERE id=:position_id;
ROLLBACK TO SAVEPOINT negative10;

\echo '[11/14] EXPECT 23514 phone_kz_format_ck (DOMAIN)'
SAVEPOINT negative11;
UPDATE transit.driver SET phone='12345' WHERE id=:driver_id;
ROLLBACK TO SAVEPOINT negative11;

\echo '[12/14] EXPECT 22P02 transit.trip_status (ENUM invalid value)'
SAVEPOINT negative12;
UPDATE transit.trip SET status='flying' WHERE id=:trip_id;
ROLLBACK TO SAVEPOINT negative12;

\echo '[13/14] EXPECT 23514 driver_experience_age_ck'
SAVEPOINT negative13;
UPDATE transit.driver SET experience_years=90 WHERE id=:driver_id;
ROLLBACK TO SAVEPOINT negative13;

\echo '[14/14] EXPECT 23514 request_compensation_nonnegative_ck'
SAVEPOINT negative14;
UPDATE transit.service_request SET compensation_amount=-500 WHERE id=:request_id;
ROLLBACK TO SAVEPOINT negative14;

\set ON_ERROR_STOP on
ROLLBACK;
\echo '=== SRSP WEEK 03: END NEGATIVE TESTS; NO TEST DATA SAVED ==='
