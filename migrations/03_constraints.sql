-- SRSP Week 03 | Passenger transport | schema transit
-- Designed for Week 02 (15 tables in total, including 3 original Week 1 tables).
-- Introduces applicant and service_request to support service-complaint ENUM and phone domain.
-- Run AFTER migrations/02_schema.sql; execute on a TEST copy before the real transit database.
-- DOES NOT delete existing rows; on schema validation failure the full migration rolls back.
-- All FK actions are explicit; all constraint names are stable.
BEGIN;
SET LOCAL search_path TO transit, public;

-- 1) ENUM types and domain; safe on re-run.
DO $create_types$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                   WHERE n.nspname='transit' AND t.typname='trip_status') THEN
        CREATE TYPE transit.trip_status AS ENUM ('scheduled','in_progress','completed','cancelled');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                   WHERE n.nspname='transit' AND t.typname='request_status') THEN
        CREATE TYPE transit.request_status AS ENUM ('new','in_progress','resolved','rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
                   WHERE n.nspname='transit' AND t.typname='phone_kz') THEN
        CREATE DOMAIN transit.phone_kz AS text
          CONSTRAINT phone_kz_format_ck CHECK (VALUE ~ '^\+7[0-9]{10}$');
    END IF;
END;
$create_types$;

-- 2) Preserve previous values while tightening types.
ALTER TABLE transit.trip ALTER COLUMN status DROP DEFAULT;
ALTER TABLE transit.trip ALTER COLUMN status TYPE transit.trip_status
    USING status::text::transit.trip_status;
ALTER TABLE transit.trip ALTER COLUMN status SET DEFAULT 'scheduled'::transit.trip_status;

-- Real-world archive: retain assignment when its driver is deleted.
ALTER TABLE transit.assignment ALTER COLUMN driver_id DROP NOT NULL;

-- Driver age/experience were absent from Week 02. Keep nullable for old records.
ALTER TABLE transit.driver ADD COLUMN IF NOT EXISTS birth_date date;
ALTER TABLE transit.driver ADD COLUMN IF NOT EXISTS experience_years smallint;
COMMENT ON COLUMN transit.driver.birth_date IS 'Дата рождения; нужна для проверки возраста водителя';
COMMENT ON COLUMN transit.driver.experience_years IS 'Полных лет опыта; не больше возраста минус 18';
ALTER TABLE transit.driver ALTER COLUMN phone TYPE transit.phone_kz USING phone::transit.phone_kz;
COMMENT ON COLUMN transit.driver.phone IS 'Телефон в формате +7XXXXXXXXXX; домен transit.phone_kz';

-- Applicants and their feedback are needed for the assignment's second ENUM.
CREATE TABLE IF NOT EXISTS transit.applicant (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name text NOT NULL,
    phone transit.phone_kz,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE transit.applicant IS 'Заявители, направляющие обращения перевозчику';
COMMENT ON COLUMN transit.applicant.full_name IS 'ФИО заявителя';
COMMENT ON COLUMN transit.applicant.phone IS 'Телефон +7XXXXXXXXXX, необязателен';

CREATE TABLE IF NOT EXISTS transit.service_request (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    applicant_id bigint NOT NULL,
    route_id bigint,
    title text NOT NULL,
    description text NOT NULL,
    status transit.request_status NOT NULL DEFAULT 'new',
    requested_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at timestamptz,
    compensation_amount numeric(12,2) NOT NULL DEFAULT 0
);
COMMENT ON TABLE transit.service_request IS 'Обращения пассажиров: замечания, жалобы и запросы';
COMMENT ON COLUMN transit.service_request.applicant_id IS 'Заявитель обращения';
COMMENT ON COLUMN transit.service_request.route_id IS 'Маршрут, если он определён';
COMMENT ON COLUMN transit.service_request.status IS 'ENUM new/in_progress/resolved/rejected';
COMMENT ON COLUMN transit.service_request.compensation_amount IS 'Компенсация при рассмотрении обращения, тенге';


-- 3) Named FKs: ON UPDATE RESTRICT throughout, ON DELETE selected per dependency.
-- bus.model_id -> bus_model.id: Нельзя удалить модель автобуса, если на неё ссылается парк.
ALTER TABLE transit.bus DROP CONSTRAINT IF EXISTS bus_model_id_fkey;
ALTER TABLE transit.bus ADD CONSTRAINT bus_model_id_fkey FOREIGN KEY (model_id)
  REFERENCES transit.bus_model(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT bus_model_id_fkey ON transit.bus IS 'Нельзя удалить модель автобуса, если на неё ссылается парк. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- bus.depot_id -> depot.id: Нельзя удалить депо, в котором числятся автобусы.
ALTER TABLE transit.bus DROP CONSTRAINT IF EXISTS bus_depot_id_fkey;
ALTER TABLE transit.bus ADD CONSTRAINT bus_depot_id_fkey FOREIGN KEY (depot_id)
  REFERENCES transit.depot(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT bus_depot_id_fkey ON transit.bus IS 'Нельзя удалить депо, в котором числятся автобусы. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- driver.depot_id -> depot.id: Нельзя удалить депо с работающими водителями.
ALTER TABLE transit.driver DROP CONSTRAINT IF EXISTS driver_depot_id_fkey;
ALTER TABLE transit.driver ADD CONSTRAINT driver_depot_id_fkey FOREIGN KEY (depot_id)
  REFERENCES transit.depot(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT driver_depot_id_fkey ON transit.driver IS 'Нельзя удалить депо с работающими водителями. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- driver_license.driver_id -> driver.id: У удалённого водителя не должно оставаться строк допуска.
ALTER TABLE transit.driver_license DROP CONSTRAINT IF EXISTS driver_license_driver_id_fkey;
ALTER TABLE transit.driver_license ADD CONSTRAINT driver_license_driver_id_fkey FOREIGN KEY (driver_id)
  REFERENCES transit.driver(id) ON UPDATE RESTRICT ON DELETE CASCADE;
COMMENT ON CONSTRAINT driver_license_driver_id_fkey ON transit.driver_license IS 'У удалённого водителя не должно оставаться строк допуска. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- driver_license.category_id -> license_category.id: Используемую категорию нельзя удалить из справочника.
ALTER TABLE transit.driver_license DROP CONSTRAINT IF EXISTS driver_license_category_id_fkey;
ALTER TABLE transit.driver_license ADD CONSTRAINT driver_license_category_id_fkey FOREIGN KEY (category_id)
  REFERENCES transit.license_category(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT driver_license_category_id_fkey ON transit.driver_license IS 'Используемую категорию нельзя удалить из справочника. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- route_stop.route_id -> route.id: Связи остановок удаляются вместе с маршрутом.
ALTER TABLE transit.route_stop DROP CONSTRAINT IF EXISTS route_stop_route_id_fkey;
ALTER TABLE transit.route_stop ADD CONSTRAINT route_stop_route_id_fkey FOREIGN KEY (route_id)
  REFERENCES transit.route(id) ON UPDATE RESTRICT ON DELETE CASCADE;
COMMENT ON CONSTRAINT route_stop_route_id_fkey ON transit.route_stop IS 'Связи остановок удаляются вместе с маршрутом. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- route_stop.stop_id -> stop.id: Остановку нельзя удалить, пока её использует маршрут.
ALTER TABLE transit.route_stop DROP CONSTRAINT IF EXISTS route_stop_stop_id_fkey;
ALTER TABLE transit.route_stop ADD CONSTRAINT route_stop_stop_id_fkey FOREIGN KEY (stop_id)
  REFERENCES transit.stop(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT route_stop_stop_id_fkey ON transit.route_stop IS 'Остановку нельзя удалить, пока её использует маршрут. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- route_schedule.route_id -> route.id: Расписание относится к маршруту и удаляется вместе с ним.
ALTER TABLE transit.route_schedule DROP CONSTRAINT IF EXISTS route_schedule_route_id_fkey;
ALTER TABLE transit.route_schedule ADD CONSTRAINT route_schedule_route_id_fkey FOREIGN KEY (route_id)
  REFERENCES transit.route(id) ON UPDATE RESTRICT ON DELETE CASCADE;
COMMENT ON CONSTRAINT route_schedule_route_id_fkey ON transit.route_schedule IS 'Расписание относится к маршруту и удаляется вместе с ним. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- route_schedule.shift_id -> shift.id: Смену с расписаниями нельзя удалить.
ALTER TABLE transit.route_schedule DROP CONSTRAINT IF EXISTS route_schedule_shift_id_fkey;
ALTER TABLE transit.route_schedule ADD CONSTRAINT route_schedule_shift_id_fkey FOREIGN KEY (shift_id)
  REFERENCES transit.shift(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT route_schedule_shift_id_fkey ON transit.route_schedule IS 'Смену с расписаниями нельзя удалить. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- assignment.route_id -> route.id: Маршрут с нарядами сохраняется в истории.
ALTER TABLE transit.assignment DROP CONSTRAINT IF EXISTS assignment_route_id_fkey;
ALTER TABLE transit.assignment ADD CONSTRAINT assignment_route_id_fkey FOREIGN KEY (route_id)
  REFERENCES transit.route(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT assignment_route_id_fkey ON transit.assignment IS 'Маршрут с нарядами сохраняется в истории. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- assignment.bus_id -> bus.id: Автобус с историей нарядов удалять нельзя.
ALTER TABLE transit.assignment DROP CONSTRAINT IF EXISTS assignment_bus_id_fkey;
ALTER TABLE transit.assignment ADD CONSTRAINT assignment_bus_id_fkey FOREIGN KEY (bus_id)
  REFERENCES transit.bus(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT assignment_bus_id_fkey ON transit.assignment IS 'Автобус с историей нарядов удалять нельзя. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- assignment.driver_id -> driver.id: Архивные наряды сохраняются, даже если запись водителя удалена.
ALTER TABLE transit.assignment DROP CONSTRAINT IF EXISTS assignment_driver_id_fkey;
ALTER TABLE transit.assignment ADD CONSTRAINT assignment_driver_id_fkey FOREIGN KEY (driver_id)
  REFERENCES transit.driver(id) ON UPDATE RESTRICT ON DELETE SET NULL;
COMMENT ON CONSTRAINT assignment_driver_id_fkey ON transit.assignment IS 'Архивные наряды сохраняются, даже если запись водителя удалена. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- assignment.shift_id -> shift.id: Нельзя удалить смену, используемую в нарядах.
ALTER TABLE transit.assignment DROP CONSTRAINT IF EXISTS assignment_shift_id_fkey;
ALTER TABLE transit.assignment ADD CONSTRAINT assignment_shift_id_fkey FOREIGN KEY (shift_id)
  REFERENCES transit.shift(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT assignment_shift_id_fkey ON transit.assignment IS 'Нельзя удалить смену, используемую в нарядах. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- trip.assignment_id -> assignment.id: Наряд с рейсами нельзя удалить без явной очистки истории.
ALTER TABLE transit.trip DROP CONSTRAINT IF EXISTS trip_assignment_id_fkey;
ALTER TABLE transit.trip ADD CONSTRAINT trip_assignment_id_fkey FOREIGN KEY (assignment_id)
  REFERENCES transit.assignment(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT trip_assignment_id_fkey ON transit.trip IS 'Наряд с рейсами нельзя удалить без явной очистки истории. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- vehicle_position.trip_id -> trip.id: При удалении рейса его телеметрия удаляется автоматически.
ALTER TABLE transit.vehicle_position DROP CONSTRAINT IF EXISTS vehicle_position_trip_id_fkey;
ALTER TABLE transit.vehicle_position ADD CONSTRAINT vehicle_position_trip_id_fkey FOREIGN KEY (trip_id)
  REFERENCES transit.trip(id) ON UPDATE RESTRICT ON DELETE CASCADE;
COMMENT ON CONSTRAINT vehicle_position_trip_id_fkey ON transit.vehicle_position IS 'При удалении рейса его телеметрия удаляется автоматически. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- bus_maintenance.bus_id -> bus.id: Историю ремонта нельзя потерять при удалении автобуса.
ALTER TABLE transit.bus_maintenance DROP CONSTRAINT IF EXISTS bus_maintenance_bus_id_fkey;
ALTER TABLE transit.bus_maintenance ADD CONSTRAINT bus_maintenance_bus_id_fkey FOREIGN KEY (bus_id)
  REFERENCES transit.bus(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT bus_maintenance_bus_id_fkey ON transit.bus_maintenance IS 'Историю ремонта нельзя потерять при удалении автобуса. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- service_request.applicant_id -> applicant.id: Обращение сохраняет ссылку на заявителя.
ALTER TABLE transit.service_request DROP CONSTRAINT IF EXISTS service_request_applicant_id_fkey;
ALTER TABLE transit.service_request ADD CONSTRAINT service_request_applicant_id_fkey FOREIGN KEY (applicant_id)
  REFERENCES transit.applicant(id) ON UPDATE RESTRICT ON DELETE RESTRICT;
COMMENT ON CONSTRAINT service_request_applicant_id_fkey ON transit.service_request IS 'Обращение сохраняет ссылку на заявителя. ON UPDATE RESTRICT защищает значения идентификаторов.';
-- service_request.route_id -> route.id: Обращение сохраняется при удалении маршрута без привязки к нему.
ALTER TABLE transit.service_request DROP CONSTRAINT IF EXISTS service_request_route_id_fkey;
ALTER TABLE transit.service_request ADD CONSTRAINT service_request_route_id_fkey FOREIGN KEY (route_id)
  REFERENCES transit.route(id) ON UPDATE RESTRICT ON DELETE SET NULL;
COMMENT ON CONSTRAINT service_request_route_id_fkey ON transit.service_request IS 'Обращение сохраняется при удалении маршрута без привязки к нему. ON UPDATE RESTRICT защищает значения идентификаторов.';

-- 4) Business CHECK constraints; none references another table.
ALTER TABLE transit.depot DROP CONSTRAINT IF EXISTS depot_name_meaningful_ck;
ALTER TABLE transit.depot ADD CONSTRAINT depot_name_meaningful_ck CHECK (char_length(btrim(name)) >= 3);
ALTER TABLE transit.depot DROP CONSTRAINT IF EXISTS depot_address_meaningful_ck;
ALTER TABLE transit.depot ADD CONSTRAINT depot_address_meaningful_ck CHECK (char_length(btrim(address)) >= 3);
ALTER TABLE transit.route DROP CONSTRAINT IF EXISTS route_length_positive_ck;
ALTER TABLE transit.route ADD CONSTRAINT route_length_positive_ck CHECK (length_km > 0 AND length_km <= 300);
ALTER TABLE transit.route DROP CONSTRAINT IF EXISTS route_number_meaningful_ck;
ALTER TABLE transit.route ADD CONSTRAINT route_number_meaningful_ck CHECK (char_length(btrim(number)) BETWEEN 1 AND 10);
ALTER TABLE transit.stop DROP CONSTRAINT IF EXISTS stop_latitude_bounds_ck;
ALTER TABLE transit.stop ADD CONSTRAINT stop_latitude_bounds_ck CHECK (latitude BETWEEN -90 AND 90);
ALTER TABLE transit.stop DROP CONSTRAINT IF EXISTS stop_longitude_bounds_ck;
ALTER TABLE transit.stop ADD CONSTRAINT stop_longitude_bounds_ck CHECK (longitude BETWEEN -180 AND 180);
ALTER TABLE transit.bus_model DROP CONSTRAINT IF EXISTS bus_model_capacity_ck;
ALTER TABLE transit.bus_model ADD CONSTRAINT bus_model_capacity_ck CHECK (capacity BETWEEN 1 AND 250);
ALTER TABLE transit.bus_model DROP CONSTRAINT IF EXISTS bus_model_fuel_type_ck;
ALTER TABLE transit.bus_model ADD CONSTRAINT bus_model_fuel_type_ck CHECK (fuel_type IN ('diesel','gas','electric','hybrid'));
ALTER TABLE transit.bus DROP CONSTRAINT IF EXISTS bus_manufacture_year_ck;
ALTER TABLE transit.bus ADD CONSTRAINT bus_manufacture_year_ck CHECK (year_manufactured BETWEEN 1980 AND 2100);
ALTER TABLE transit.bus DROP CONSTRAINT IF EXISTS bus_status_valid_ck;
ALTER TABLE transit.bus ADD CONSTRAINT bus_status_valid_ck CHECK (status IN ('active','maintenance','retired'));
ALTER TABLE transit.bus DROP CONSTRAINT IF EXISTS bus_registration_meaningful_ck;
ALTER TABLE transit.bus ADD CONSTRAINT bus_registration_meaningful_ck CHECK (char_length(btrim(registration_no)) BETWEEN 5 AND 20);
ALTER TABLE transit.driver DROP CONSTRAINT IF EXISTS driver_name_meaningful_ck;
ALTER TABLE transit.driver ADD CONSTRAINT driver_name_meaningful_ck CHECK (char_length(btrim(last_name)) >= 2 AND char_length(btrim(first_name)) >= 2);
ALTER TABLE transit.driver DROP CONSTRAINT IF EXISTS driver_adult_ck;
ALTER TABLE transit.driver ADD CONSTRAINT driver_adult_ck CHECK (birth_date IS NULL OR birth_date <= (CURRENT_DATE - INTERVAL '18 years')::date);
ALTER TABLE transit.driver DROP CONSTRAINT IF EXISTS driver_experience_age_ck;
ALTER TABLE transit.driver ADD CONSTRAINT driver_experience_age_ck CHECK (experience_years IS NULL OR (birth_date IS NOT NULL AND experience_years >= 0 AND experience_years <= EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date)) - 18));
ALTER TABLE transit.driver DROP CONSTRAINT IF EXISTS driver_hire_age_ck;
ALTER TABLE transit.driver ADD CONSTRAINT driver_hire_age_ck CHECK (birth_date IS NULL OR hire_date >= (birth_date + INTERVAL '18 years')::date);
ALTER TABLE transit.driver_license DROP CONSTRAINT IF EXISTS driver_license_date_ck;
ALTER TABLE transit.driver_license ADD CONSTRAINT driver_license_date_ck CHECK (expires_on IS NULL OR expires_on > issued_on);
ALTER TABLE transit.route_stop DROP CONSTRAINT IF EXISTS route_stop_order_ck;
ALTER TABLE transit.route_stop ADD CONSTRAINT route_stop_order_ck CHECK (stop_order >= 1);
ALTER TABLE transit.route_stop DROP CONSTRAINT IF EXISTS route_stop_distance_ck;
ALTER TABLE transit.route_stop ADD CONSTRAINT route_stop_distance_ck CHECK (distance_from_start_km >= 0);
ALTER TABLE transit.shift DROP CONSTRAINT IF EXISTS shift_time_rules_ck;
ALTER TABLE transit.shift ADD CONSTRAINT shift_time_rules_ck CHECK ((NOT crosses_midnight AND ends_at > starts_at) OR (crosses_midnight AND ends_at < starts_at));
ALTER TABLE transit.route_schedule DROP CONSTRAINT IF EXISTS route_schedule_weekday_ck;
ALTER TABLE transit.route_schedule ADD CONSTRAINT route_schedule_weekday_ck CHECK (weekday BETWEEN 0 AND 6);
ALTER TABLE transit.route_schedule DROP CONSTRAINT IF EXISTS route_schedule_period_ck;
ALTER TABLE transit.route_schedule ADD CONSTRAINT route_schedule_period_ck CHECK (valid_to IS NULL OR valid_to >= valid_from);
ALTER TABLE transit.assignment DROP CONSTRAINT IF EXISTS assignment_service_date_ck;
ALTER TABLE transit.assignment ADD CONSTRAINT assignment_service_date_ck CHECK (service_date >= DATE '2000-01-01');
ALTER TABLE transit.assignment DROP CONSTRAINT IF EXISTS assignment_status_ck;
ALTER TABLE transit.assignment ADD CONSTRAINT assignment_status_ck CHECK (status IN ('scheduled','active','completed','cancelled'));
ALTER TABLE transit.trip DROP CONSTRAINT IF EXISTS trip_number_ck;
ALTER TABLE transit.trip ADD CONSTRAINT trip_number_ck CHECK (trip_number >= 1);
ALTER TABLE transit.trip DROP CONSTRAINT IF EXISTS trip_planned_time_ck;
ALTER TABLE transit.trip ADD CONSTRAINT trip_planned_time_ck CHECK (planned_end_at IS NULL OR planned_end_at > planned_start_at);
ALTER TABLE transit.trip DROP CONSTRAINT IF EXISTS trip_actual_time_ck;
ALTER TABLE transit.trip ADD CONSTRAINT trip_actual_time_ck CHECK (actual_end_at IS NULL OR (actual_start_at IS NOT NULL AND actual_end_at > actual_start_at));
ALTER TABLE transit.trip DROP CONSTRAINT IF EXISTS trip_completed_has_times_ck;
ALTER TABLE transit.trip ADD CONSTRAINT trip_completed_has_times_ck CHECK (status <> 'completed' OR (actual_start_at IS NOT NULL AND actual_end_at IS NOT NULL));
ALTER TABLE transit.vehicle_position DROP CONSTRAINT IF EXISTS vehicle_position_latitude_ck;
ALTER TABLE transit.vehicle_position ADD CONSTRAINT vehicle_position_latitude_ck CHECK (latitude BETWEEN -90 AND 90);
ALTER TABLE transit.vehicle_position DROP CONSTRAINT IF EXISTS vehicle_position_longitude_ck;
ALTER TABLE transit.vehicle_position ADD CONSTRAINT vehicle_position_longitude_ck CHECK (longitude BETWEEN -180 AND 180);
ALTER TABLE transit.vehicle_position DROP CONSTRAINT IF EXISTS vehicle_position_speed_ck;
ALTER TABLE transit.vehicle_position ADD CONSTRAINT vehicle_position_speed_ck CHECK (speed_kmh BETWEEN 0 AND 60);
ALTER TABLE transit.bus_maintenance DROP CONSTRAINT IF EXISTS bus_maintenance_cost_ck;
ALTER TABLE transit.bus_maintenance ADD CONSTRAINT bus_maintenance_cost_ck CHECK (cost IS NULL OR cost >= 0);
ALTER TABLE transit.applicant DROP CONSTRAINT IF EXISTS applicant_full_name_ck;
ALTER TABLE transit.applicant ADD CONSTRAINT applicant_full_name_ck CHECK (char_length(btrim(full_name)) >= 3);
ALTER TABLE transit.service_request DROP CONSTRAINT IF EXISTS request_title_meaningful_ck;
ALTER TABLE transit.service_request ADD CONSTRAINT request_title_meaningful_ck CHECK (char_length(btrim(title)) >= 5);
ALTER TABLE transit.service_request DROP CONSTRAINT IF EXISTS request_description_meaningful_ck;
ALTER TABLE transit.service_request ADD CONSTRAINT request_description_meaningful_ck CHECK (char_length(btrim(description)) >= 10);
ALTER TABLE transit.service_request DROP CONSTRAINT IF EXISTS request_compensation_nonnegative_ck;
ALTER TABLE transit.service_request ADD CONSTRAINT request_compensation_nonnegative_ck CHECK (compensation_amount >= 0);
ALTER TABLE transit.service_request DROP CONSTRAINT IF EXISTS request_chronology_ck;
ALTER TABLE transit.service_request ADD CONSTRAINT request_chronology_ck CHECK (resolved_at IS NULL OR resolved_at >= requested_at);
ALTER TABLE transit.service_request DROP CONSTRAINT IF EXISTS request_closed_has_time_ck;
ALTER TABLE transit.service_request ADD CONSTRAINT request_closed_has_time_ck CHECK (status NOT IN ('resolved','rejected') OR resolved_at IS NOT NULL);

-- 5) Uniqueness rules.
-- Week 02 made registration_no UNIQUE for ALL buses. Replace with a precise
-- partial unique index: only active buses need unique current plates.
ALTER TABLE transit.bus DROP CONSTRAINT IF EXISTS bus_registration_no_key;
CREATE UNIQUE INDEX IF NOT EXISTS bus_active_registration_uq
  ON transit.bus(registration_no) WHERE status='active';

-- A repeated stop number on one route cannot identify two stop records.
ALTER TABLE transit.route_stop DROP CONSTRAINT IF EXISTS route_stop_route_order_uq;
ALTER TABLE transit.route_stop ADD CONSTRAINT route_stop_route_order_uq UNIQUE(route_id, stop_order);

-- A bus cannot work two assignments on the same day and shift.
ALTER TABLE transit.assignment DROP CONSTRAINT IF EXISTS assignment_bus_date_shift_uq;
ALTER TABLE transit.assignment ADD CONSTRAINT assignment_bus_date_shift_uq UNIQUE(bus_id, service_date, shift_id);

-- Number each trip within an assignment uniquely.
ALTER TABLE transit.trip DROP CONSTRAINT IF EXISTS trip_assignment_number_uq;
ALTER TABLE transit.trip ADD CONSTRAINT trip_assignment_number_uq UNIQUE(assignment_id, trip_number);

COMMIT;

