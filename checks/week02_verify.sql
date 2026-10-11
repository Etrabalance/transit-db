-- Week 02 verification. No data changes.
\pset pager off
\echo '=== transit tables (expect 15) ==='
SELECT table_name FROM information_schema.tables
 WHERE table_schema = 'transit' AND table_type = 'BASE TABLE'
 ORDER BY table_name;
\echo '=== table count (expect >= 15) ==='
SELECT count(*) AS transit_tables FROM information_schema.tables
 WHERE table_schema = 'transit' AND table_type = 'BASE TABLE';
\echo '=== Week 1 sample data should remain untouched ==='
SELECT 'depot' AS table_name, count(*) AS rows FROM transit.depot
UNION ALL SELECT 'route', count(*) FROM transit.route
UNION ALL SELECT 'stop', count(*) FROM transit.stop;
\echo '=== Week 2: FK count should be 0 (deliberately deferred) ==='
SELECT count(*) AS foreign_keys FROM pg_constraint c
 JOIN pg_namespace n ON n.oid = c.connamespace
 WHERE n.nspname = 'transit' AND c.contype = 'f';
\echo '=== telemetry fact table exists ==='
SELECT to_regclass('transit.vehicle_position') AS fact_table;
