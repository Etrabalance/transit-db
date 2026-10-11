-- SRSP week 04 / 04: COPY, INSERT SELECT, UPSERT, UPDATE FROM, DELETE USING, RETURNING.
-- Run from the transit-db project root on the restored TEST database first.
-- COPY round-trip uses a TEMP staging table, not live transit.stop, because
-- transit.route_stop has FK ON DELETE RESTRICT. This is intentionally safe.
\pset pager off
\timing on
\echo '=== 04/04 COPY round-trip: export entire stop directory ==='
\copy (SELECT id,name,latitude,longitude FROM transit.stop ORDER BY id) TO 'seed/week04_stops_export.csv' WITH (FORMAT csv, HEADER true)
CREATE TEMP TABLE w4_stop_roundtrip(id bigint,name text,latitude numeric(9,6),longitude numeric(9,6));
INSERT INTO w4_stop_roundtrip SELECT id,name,latitude,longitude FROM transit.stop;
TRUNCATE w4_stop_roundtrip;
\copy w4_stop_roundtrip FROM 'seed/week04_stops_export.csv' WITH (FORMAT csv, HEADER true)
\echo 'Compare actual stop counts: original vs restored staging copy:'
SELECT (SELECT count(*) FROM transit.stop) original,
       (SELECT count(*) FROM w4_stop_roundtrip) restored;
\echo '=== Benchmark: exactly 100000 rows via COPY, then 100000 separate SQL INSERT executions ==='
CREATE TEMP TABLE w4_copy_benchmark (id int,payload text);
CREATE TEMP TABLE w4_insert_benchmark (id int,payload text);
\echo 'COPY 100000: note elapsed time printed next to COPY statement'
\copy w4_copy_benchmark(id,payload) FROM 'seed/benchmark_100k.csv' WITH (FORMAT csv, HEADER true)
\echo '100000 separate INSERT commands executed by server-side dynamic SQL in DO loop:'
DO $bench$
BEGIN
 FOR i IN 1..100000 LOOP
  EXECUTE 'INSERT INTO pg_temp.w4_insert_benchmark(id,payload) VALUES ($1,$2)'
  USING i,'demo-row-'||i;
 END LOOP;
END
$bench$;
SELECT (SELECT count(*) FROM w4_copy_benchmark) AS copied,
       (SELECT count(*) FROM w4_insert_benchmark) AS inserted;
\echo '=== UPSERT stop updates from new CSV ==='
CREATE TEMP TABLE w4_stop_updates(id bigint,name text,latitude numeric(9,6),longitude numeric(9,6));
\copy w4_stop_updates(id,name,latitude,longitude) FROM 'seed/week04_stop_updates.csv' WITH (FORMAT csv, HEADER true)
WITH changed AS (
 INSERT INTO transit.stop(id,name,latitude,longitude) OVERRIDING SYSTEM VALUE
 SELECT id,name,latitude,longitude FROM w4_stop_updates
 WHERE true
 ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name
 RETURNING id
) SELECT count(*) AS stop_ids_inserted_or_updated, min(id), max(id) FROM changed;
\echo '=== INSERT SELECT: archive completed trips from previous year ==='
CREATE TABLE IF NOT EXISTS transit.trip_archive (
 trip_id bigint PRIMARY KEY, assignment_id bigint NOT NULL,
 service_date date NOT NULL, status transit.trip_status NOT NULL,
 actual_start_at timestamptz,actual_end_at timestamptz,
 archived_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
WITH archived AS (
 INSERT INTO transit.trip_archive(trip_id,assignment_id,service_date,status,actual_start_at,actual_end_at)
 SELECT t.id,a.id,a.service_date,t.status,t.actual_start_at,t.actual_end_at
 FROM transit.trip t JOIN transit.assignment a ON a.id=t.assignment_id
 WHERE a.service_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
 AND t.status='completed' AND a.route_id BETWEEN 900001 AND 900040
 ON CONFLICT (trip_id) DO UPDATE SET status=EXCLUDED.status,
 actual_start_at=EXCLUDED.actual_start_at,actual_end_at=EXCLUDED.actual_end_at
 RETURNING trip_id
) SELECT count(*) AS archived_trip_ids FROM archived;
\echo '=== UPDATE FROM: compute actual duration from telemetry ==='
WITH p AS (
 SELECT trip_id, min(observed_at) AS first_obs, max(observed_at) AS last_obs
 FROM transit.vehicle_position GROUP BY trip_id
)
UPDATE transit.trip t
SET actual_duration_minutes=round(extract(epoch FROM (p.last_obs-p.first_obs+INTERVAL '30 seconds'))::numeric/60,2)
FROM p WHERE t.id=p.trip_id AND t.status='completed';
\echo '=== DELETE USING and RETURNING: purge cancelled-trip telemetry ==='
WITH deleted AS (
 DELETE FROM transit.vehicle_position vp USING transit.trip t
 WHERE vp.trip_id=t.id AND t.status='cancelled'
 RETURNING vp.id
) SELECT count(*) AS deleted_cancelled_positions FROM deleted;
\echo 'Rows remaining (must be >=2000000):'
SELECT count(*) AS positions_after_delete FROM transit.vehicle_position;
\echo '=== 04 DML finished. Record the TWO benchmark timings from above for report. ==='
