-- Week 04 read-only final verification. Use after all 4 seed files completed.
\pset pager off
\timing on
\echo '=== ALL TABLE EXACT ROW COUNTS ==='
SELECT 'applicant' AS table_name,count(*) AS rows FROM transit.applicant UNION ALL
SELECT 'assignment',count(*) FROM transit.assignment UNION ALL
SELECT 'bus',count(*) FROM transit.bus UNION ALL
SELECT 'bus_maintenance',count(*) FROM transit.bus_maintenance UNION ALL
SELECT 'bus_model',count(*) FROM transit.bus_model UNION ALL
SELECT 'depot',count(*) FROM transit.depot UNION ALL
SELECT 'driver',count(*) FROM transit.driver UNION ALL
SELECT 'driver_license',count(*) FROM transit.driver_license UNION ALL
SELECT 'license_category',count(*) FROM transit.license_category UNION ALL
SELECT 'route',count(*) FROM transit.route UNION ALL
SELECT 'route_schedule',count(*) FROM transit.route_schedule UNION ALL
SELECT 'route_stop',count(*) FROM transit.route_stop UNION ALL
SELECT 'service_request',count(*) FROM transit.service_request UNION ALL
SELECT 'shift',count(*) FROM transit.shift UNION ALL
SELECT 'stop',count(*) FROM transit.stop UNION ALL
SELECT 'trip',count(*) FROM transit.trip UNION ALL
SELECT 'trip_archive',count(*) FROM transit.trip_archive UNION ALL
SELECT 'vehicle_position',count(*) FROM transit.vehicle_position
ORDER BY table_name;
\echo '=== MINIMUMS ASSERTION: exception on failure ==='
DO $verify$
BEGIN
 IF (SELECT count(*) FROM transit.route)<40 OR
    (SELECT count(*) FROM transit.stop)<600 OR
    (SELECT count(*) FROM transit.bus)<400 OR
    (SELECT count(*) FROM transit.driver)<500 OR
    (SELECT count(*) FROM transit.vehicle_position)<2000000
 THEN RAISE EXCEPTION 'Week 4 minimum counts NOT achieved'; END IF;
 IF (SELECT count(*) FROM transit.assignment
   WHERE service_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
     AND route_id BETWEEN 900001 AND 900040) <> 29200
 THEN RAISE EXCEPTION 'Wrong assignment count for complete 2025 calendar year'; END IF;
 IF (SELECT count(*) FROM transit.trip t JOIN transit.assignment a ON t.assignment_id=a.id
    WHERE a.service_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
       AND a.route_id BETWEEN 900001 AND 900040) <> 175200
 THEN RAISE EXCEPTION 'Wrong number of 2025 trips'; END IF;
END $verify$;
\echo '=== Year and telemetry summary ==='
SELECT count(*) AS total_positions,min(observed_at) AS first_gps,
 max(observed_at) AS last_gps,min(speed_kmh) AS min_speed,max(speed_kmh) AS max_speed,
 count(*) FILTER(WHERE speed_kmh>60 OR speed_kmh<0) AS invalid_speed
FROM transit.vehicle_position;
\echo '=== Thirty-second spacing on one randomly selected recorded trip ==='
WITH first_trip AS (SELECT min(trip_id) AS id FROM transit.vehicle_position),
 samples AS (SELECT observed_at, observed_at - lag(observed_at) OVER (ORDER BY observed_at) AS delta
 FROM transit.vehicle_position WHERE trip_id=(SELECT id FROM first_trip))
SELECT count(*) AS points, count(*) FILTER(WHERE delta<>INTERVAL '30 seconds') AS wrong_spacing
FROM samples;
\echo '=== Reproducibility fingerprint (business values, not sequence ID) ==='
SELECT md5(string_agg(trip_id::text||'|'||observed_at::text||'|'||latitude::text||'|'||longitude::text,
  ';' ORDER BY trip_id,observed_at)) AS fingerprint_1000
FROM (SELECT trip_id,observed_at,latitude,longitude FROM transit.vehicle_position
 ORDER BY trip_id,observed_at LIMIT 1000) q;
\echo '=== Database size ==='
SELECT pg_database_size(current_database()) AS bytes,
 pg_size_pretty(pg_database_size(current_database())) AS human_size;
\echo '=== End of verification ==='
