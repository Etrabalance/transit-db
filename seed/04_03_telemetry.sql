-- SRSP week 04 / 03: >=2,000,000 telemetry rows at exactly 30-sec spacing.
-- 175200 simulated 6-minute shuttle trips * 12 observations = 2,102,400 initially.
-- DELETE of cancelled trip telemetry in Step 4 leaves >2,000,000.
-- Geometry is interpolated between adjacent synthetic route_stop coordinates.
-- This replaces ONLY transit.vehicle_position (Week 03 had no saved telemetry).
\pset pager off
\timing on
\echo '=== 04/03 HEAVY TELEMETRY LOAD; MAY TAKE MINUTES ==='
BEGIN;
SELECT setseed(0.2025);
TRUNCATE TABLE transit.vehicle_position;
INSERT INTO transit.vehicle_position(trip_id,observed_at,latitude,longitude,speed_kmh,source)
SELECT t.id,
       COALESCE(t.actual_start_at,t.planned_start_at)+p.i*INTERVAL '30 seconds',
       ROUND((s0.latitude + (s1.latitude-s0.latitude)*pos.fraction)::numeric,6),
       ROUND((s0.longitude + (s1.longitude-s0.longitude)*pos.fraction)::numeric,6),
       ROUND((12+20*abs(sin((t.trip_number+p.i)::double precision/3.0)))::numeric,2),
       'simulated'
FROM transit.trip t
JOIN transit.assignment a ON a.id=t.assignment_id
CROSS JOIN generate_series(0,11) AS p(i)
CROSS JOIN LATERAL (
 SELECT LEAST(13,floor(p.i*14.0/11)::int) AS seg,
        (p.i*14.0/11 - LEAST(13,floor(p.i*14.0/11)::int))::numeric AS fraction
) AS pos
JOIN transit.route_stop rs0 ON rs0.route_id=a.route_id AND rs0.stop_order=pos.seg+1
JOIN transit.route_stop rs1 ON rs1.route_id=a.route_id AND rs1.stop_order=pos.seg+2
JOIN transit.stop s0 ON s0.id=rs0.stop_id
JOIN transit.stop s1 ON s1.id=rs1.stop_id
WHERE a.service_date >= DATE '2025-01-01' AND a.service_date < DATE '2026-01-01'
  AND a.route_id BETWEEN 900001 AND 900040 AND a.shift_id IN (930001,930002);
COMMIT;
CREATE INDEX IF NOT EXISTS vehicle_position_observed_at_w4_idx
 ON transit.vehicle_position(observed_at);
\echo 'Before cancelled-row cleanup:'
SELECT count(*) AS telemetry_rows FROM transit.vehicle_position;
SELECT pg_size_pretty(pg_database_size(current_database())) AS database_size;
