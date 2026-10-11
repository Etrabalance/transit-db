-- SRSP week 04 / 02: full calendar year 2025, each date / 40 routes / 2 shifts.
-- Six trips per assignment (6 <= trips <= 12). All values deterministic.
-- Safe to re-run via UNIQUE keys. Requires 04_01_reference.sql.
\pset pager off
\timing on
\echo '=== 04/02 FULL YEAR ASSIGNMENTS AND TRIPS ==='
SELECT setseed(0.2025);
INSERT INTO transit.assignment(route_id,bus_id,driver_id,shift_id,service_date,status)
SELECT r.id,
       910001 + (((r.id-900001)*2+(sh.id-930001)+(d.day-DATE '2025-01-01')*80) % 400),
       920001 + (((r.id-900001)*2+(sh.id-930001)+(d.day-DATE '2025-01-01')*80) % 500),
       sh.id,d.day,
       CASE WHEN ((d.day-DATE '2025-01-01')+r.id+sh.id)%97=0
            THEN 'cancelled' ELSE 'completed' END
FROM (SELECT gs::date AS day FROM generate_series(DATE '2025-01-01',DATE '2025-12-31',INTERVAL '1 day') AS gs) d
CROSS JOIN transit.route r
CROSS JOIN transit.shift sh
WHERE r.id BETWEEN 900001 AND 900040 AND sh.id IN (930001,930002)
ON CONFLICT ON CONSTRAINT assignment_bus_date_shift_uq DO UPDATE
SET route_id=EXCLUDED.route_id,driver_id=EXCLUDED.driver_id,status=EXCLUDED.status;
\echo 'Assignments for 2025 (target 365 * 40 * 2 = 29200):'
SELECT count(*) AS assignments_2025 FROM transit.assignment
WHERE service_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
 AND route_id BETWEEN 900001 AND 900040;
INSERT INTO transit.trip(assignment_id,trip_number,planned_start_at,planned_end_at,actual_start_at,actual_end_at,status)
SELECT a.id, seq.i, z.start_at,
 z.start_at + INTERVAL '6 minutes',
 CASE WHEN a.status='cancelled' THEN NULL ELSE z.start_at + INTERVAL '1 minute' END,
 CASE WHEN a.status='cancelled' THEN NULL ELSE z.start_at + INTERVAL '7 minutes' END,
 CASE WHEN a.status='cancelled' THEN 'cancelled'::transit.trip_status
      ELSE 'completed'::transit.trip_status END
FROM transit.assignment a
CROSS JOIN generate_series(1,6) AS seq(i)
CROSS JOIN LATERAL (
 SELECT ((a.service_date + CASE WHEN a.shift_id=930001 THEN TIME '06:00' ELSE TIME '14:00' END)
   AT TIME ZONE 'Asia/Almaty') + (seq.i-1)*INTERVAL '70 minutes' AS start_at
) z
WHERE a.service_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
 AND a.route_id BETWEEN 900001 AND 900040 AND a.shift_id IN (930001,930002)
ON CONFLICT ON CONSTRAINT trip_assignment_number_uq DO UPDATE
SET planned_start_at=EXCLUDED.planned_start_at,
 planned_end_at=EXCLUDED.planned_end_at, actual_start_at=EXCLUDED.actual_start_at,
 actual_end_at=EXCLUDED.actual_end_at,status=EXCLUDED.status;
-- For UPDATE ... FROM in 04_04_dml.sql
ALTER TABLE transit.trip ADD COLUMN IF NOT EXISTS actual_duration_minutes numeric(8,2);
CREATE INDEX IF NOT EXISTS trip_planned_start_at_w4_idx ON transit.trip(planned_start_at);
\echo 'Trips for 2025 (target 29200 * 6 = 175200):'
SELECT count(*) AS trips_2025,
 count(*) FILTER(WHERE t.status='cancelled') AS cancelled_2025
FROM transit.trip t JOIN transit.assignment a ON a.id=t.assignment_id
WHERE a.service_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
  AND a.route_id BETWEEN 900001 AND 900040;
