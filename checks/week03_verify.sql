-- Verify the migration without changing transit data.
\pset pager off
\timing on
\echo '=== SRSP Week 03: number of tables ==='
SELECT count(*) AS tables_in_transit
FROM information_schema.tables
WHERE table_schema='transit' AND table_type='BASE TABLE';

\echo '=== All foreign keys with explicit actions ==='
SELECT conrelid::regclass AS child_table, conname AS name,
  CASE confdeltype WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL'
   WHEN 'a' THEN 'NO ACTION' WHEN 'd' THEN 'SET DEFAULT' END AS on_delete,
  CASE confupdtype WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL'
   WHEN 'a' THEN 'NO ACTION' WHEN 'd' THEN 'SET DEFAULT' END AS on_update
FROM pg_constraint WHERE connamespace='transit'::regnamespace AND contype='f'
ORDER BY 1,2;

\echo '=== Constraint counts ==='
SELECT CASE contype WHEN 'f' THEN 'FOREIGN KEY' WHEN 'c' THEN 'CHECK' WHEN 'u' THEN 'UNIQUE'
  WHEN 'p' THEN 'PRIMARY KEY' END AS constraint_type, count(*) AS n
FROM pg_constraint WHERE connamespace='transit'::regnamespace
GROUP BY contype ORDER BY 1;

\echo '=== Exact domain and enum types ==='
SELECT n.nspname AS schema_name, t.typname AS type_name, t.typtype AS kind
FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
WHERE n.nspname='transit' AND t.typname IN ('phone_kz','trip_status','request_status')
ORDER BY t.typname;

\echo '=== Status column, nullable archive driver, domain column ==='
SELECT table_name,column_name,data_type,udt_schema,udt_name,is_nullable
FROM information_schema.columns WHERE table_schema='transit' AND
 (table_name='trip' AND column_name='status'
 OR table_name='assignment' AND column_name='driver_id'
 OR table_name='driver' AND column_name='phone'
 OR table_name='applicant' AND column_name='phone'
 OR table_name='service_request' AND column_name='status')
ORDER BY table_name,column_name;

\echo '=== Initial Week 1 data still present ==='
SELECT (SELECT COUNT(*) FROM transit.depot) AS depots,
 (SELECT COUNT(*) FROM transit.route) AS routes,
 (SELECT COUNT(*) FROM transit.stop) AS stops;

\echo '=== Partial UNIQUE index for active bus registration ==='
SELECT indexname,indexdef FROM pg_indexes
WHERE schemaname='transit' AND indexname='bus_active_registration_uq';
