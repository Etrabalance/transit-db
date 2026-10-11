-- SRSP, week 02: Passenger transport in Almaty (schema transit)
-- Source: reconstructed Week 1 schema from the student's 'Задание 1.docx', page 3.
-- Week 2 requires DDL for 12-15 entities WITHOUT foreign-key constraints.
-- IMPORTANT: this script never drops tables or deletes/updates rows.
-- CREATE TABLE IF NOT EXISTS protects the 3 pre-existing Week 1 tables and sample data.
-- Logical relationships are documented in COMMENT / DBML and can receive FK constraints in Week 3.
-- This is not a migration audit: ensure the real Week 1 columns match the document.

BEGIN;
CREATE SCHEMA IF NOT EXISTS transit;

-- depot: Автобусное депо
CREATE TABLE IF NOT EXISTS transit.depot (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL,
    address text NOT NULL
);
COMMENT ON TABLE transit.depot IS 'Автобусное депо';
COMMENT ON COLUMN transit.depot.id IS 'Суррогатный идентификатор депо';
COMMENT ON COLUMN transit.depot.name IS 'Название депо';
COMMENT ON COLUMN transit.depot.address IS 'Адрес депо';

-- route: Маршрут пассажирского транспорта
CREATE TABLE IF NOT EXISTS transit.route (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    number text NOT NULL,
    length_km numeric(6,2) NOT NULL,
    start_date date NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE transit.route IS 'Маршрут пассажирского транспорта';
COMMENT ON COLUMN transit.route.id IS 'Суррогатный идентификатор маршрута';
COMMENT ON COLUMN transit.route.number IS 'Публичный номер маршрута; может измениться';
COMMENT ON COLUMN transit.route.length_km IS 'Протяжённость маршрута в километрах';
COMMENT ON COLUMN transit.route.start_date IS 'Дата начала работы маршрута';
COMMENT ON COLUMN transit.route.created_at IS 'Момент создания записи';

-- stop: Остановка общественного транспорта
CREATE TABLE IF NOT EXISTS transit.stop (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL,
    latitude numeric(9,6) NOT NULL,
    longitude numeric(9,6) NOT NULL
);
COMMENT ON TABLE transit.stop IS 'Остановка общественного транспорта';
COMMENT ON COLUMN transit.stop.id IS 'Суррогатный идентификатор остановки';
COMMENT ON COLUMN transit.stop.name IS 'Название остановки';
COMMENT ON COLUMN transit.stop.latitude IS 'Широта в десятичных градусах';
COMMENT ON COLUMN transit.stop.longitude IS 'Долгота в десятичных градусах';

-- bus_model: Справочник моделей автобусов
CREATE TABLE IF NOT EXISTS transit.bus_model (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    manufacturer text NOT NULL,
    model_name text NOT NULL,
    capacity integer NOT NULL,
    fuel_type text NOT NULL
);
COMMENT ON TABLE transit.bus_model IS 'Справочник моделей автобусов';
COMMENT ON COLUMN transit.bus_model.id IS 'Суррогатный идентификатор модели';
COMMENT ON COLUMN transit.bus_model.manufacturer IS 'Изготовитель автобуса';
COMMENT ON COLUMN transit.bus_model.model_name IS 'Обозначение модели';
COMMENT ON COLUMN transit.bus_model.capacity IS 'Пассажировместимость модели';
COMMENT ON COLUMN transit.bus_model.fuel_type IS 'Тип энергии: diesel, gas, electric и т. п.';

-- bus: Парк автобусов
CREATE TABLE IF NOT EXISTS transit.bus (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    model_id bigint NOT NULL,
    depot_id bigint NOT NULL,
    registration_no text NOT NULL UNIQUE,
    year_manufactured integer NOT NULL,
    status text NOT NULL DEFAULT 'active'
);
COMMENT ON TABLE transit.bus IS 'Парк автобусов';
COMMENT ON COLUMN transit.bus.id IS 'Суррогатный идентификатор автобуса';
COMMENT ON COLUMN transit.bus.model_id IS 'Логическая связь с bus_model.id; FK будет добавлен на неделе 3';
COMMENT ON COLUMN transit.bus.depot_id IS 'Логическая связь с depot.id';
COMMENT ON COLUMN transit.bus.registration_no IS 'Государственный номер автобуса; может измениться при перерегистрации';
COMMENT ON COLUMN transit.bus.year_manufactured IS 'Год выпуска автобуса';
COMMENT ON COLUMN transit.bus.status IS 'Текущий статус автобуса';

-- driver: Водители транспортного предприятия
CREATE TABLE IF NOT EXISTS transit.driver (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    depot_id bigint NOT NULL,
    last_name text NOT NULL,
    first_name text NOT NULL,
    middle_name text,
    phone text,
    hire_date date NOT NULL
);
COMMENT ON TABLE transit.driver IS 'Водители транспортного предприятия';
COMMENT ON COLUMN transit.driver.id IS 'Суррогатный идентификатор водителя';
COMMENT ON COLUMN transit.driver.depot_id IS 'Логическая связь с depot.id';
COMMENT ON COLUMN transit.driver.last_name IS 'Фамилия водителя';
COMMENT ON COLUMN transit.driver.first_name IS 'Имя водителя';
COMMENT ON COLUMN transit.driver.middle_name IS 'Отчество, если имеется';
COMMENT ON COLUMN transit.driver.phone IS 'Телефон; может быть неизвестен (NULL)';
COMMENT ON COLUMN transit.driver.hire_date IS 'Дата приёма на работу';

-- license_category: Справочник водительских категорий
CREATE TABLE IF NOT EXISTS transit.license_category (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code text NOT NULL UNIQUE,
    description text
);
COMMENT ON TABLE transit.license_category IS 'Справочник водительских категорий';
COMMENT ON COLUMN transit.license_category.id IS 'Суррогатный идентификатор категории';
COMMENT ON COLUMN transit.license_category.code IS 'Буквенное обозначение категории (например, D)';
COMMENT ON COLUMN transit.license_category.description IS 'Описание категории';

-- driver_license: Связь M:N водителей и водительских категорий
CREATE TABLE IF NOT EXISTS transit.driver_license (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    driver_id bigint NOT NULL,
    category_id bigint NOT NULL,
    document_no text NOT NULL,
    issued_on date NOT NULL,
    expires_on date
);
COMMENT ON TABLE transit.driver_license IS 'Связь M:N водителей и водительских категорий';
COMMENT ON COLUMN transit.driver_license.id IS 'Суррогатный идентификатор допуска';
COMMENT ON COLUMN transit.driver_license.driver_id IS 'Логическая связь с driver.id';
COMMENT ON COLUMN transit.driver_license.category_id IS 'Логическая связь с license_category.id';
COMMENT ON COLUMN transit.driver_license.document_no IS 'Номер документа, подтверждающего категорию';
COMMENT ON COLUMN transit.driver_license.issued_on IS 'Дата выдачи категории';
COMMENT ON COLUMN transit.driver_license.expires_on IS 'Дата окончания срока действия, если установлена';

-- route_stop: Связь M:N маршрутов и остановок с порядком прохождения
CREATE TABLE IF NOT EXISTS transit.route_stop (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_id bigint NOT NULL,
    stop_id bigint NOT NULL,
    stop_order integer NOT NULL,
    distance_from_start_km numeric(7,2) NOT NULL,
    is_terminal boolean NOT NULL DEFAULT FALSE
);
COMMENT ON TABLE transit.route_stop IS 'Связь M:N маршрутов и остановок с порядком прохождения';
COMMENT ON COLUMN transit.route_stop.id IS 'Суррогатный идентификатор строки маршрута';
COMMENT ON COLUMN transit.route_stop.route_id IS 'Логическая связь с route.id';
COMMENT ON COLUMN transit.route_stop.stop_id IS 'Логическая связь с stop.id';
COMMENT ON COLUMN transit.route_stop.stop_order IS 'Порядковый номер остановки внутри маршрута';
COMMENT ON COLUMN transit.route_stop.distance_from_start_km IS 'Расстояние от начала маршрута в километрах';
COMMENT ON COLUMN transit.route_stop.is_terminal IS 'Является ли остановка конечной для маршрута';

-- shift: Справочник смен
CREATE TABLE IF NOT EXISTS transit.shift (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL UNIQUE,
    starts_at time NOT NULL,
    ends_at time NOT NULL,
    crosses_midnight boolean NOT NULL DEFAULT FALSE
);
COMMENT ON TABLE transit.shift IS 'Справочник смен';
COMMENT ON COLUMN transit.shift.id IS 'Суррогатный идентификатор смены';
COMMENT ON COLUMN transit.shift.name IS 'Наименование смены';
COMMENT ON COLUMN transit.shift.starts_at IS 'Плановое локальное время начала смены';
COMMENT ON COLUMN transit.shift.ends_at IS 'Плановое локальное время окончания смены';
COMMENT ON COLUMN transit.shift.crosses_midnight IS 'Признак перехода через полночь';

-- route_schedule: Повторяемое расписание отправлений маршрутов
CREATE TABLE IF NOT EXISTS transit.route_schedule (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_id bigint NOT NULL,
    shift_id bigint NOT NULL,
    weekday smallint NOT NULL,
    planned_departure time NOT NULL,
    valid_from date NOT NULL,
    valid_to date
);
COMMENT ON TABLE transit.route_schedule IS 'Повторяемое расписание отправлений маршрутов';
COMMENT ON COLUMN transit.route_schedule.id IS 'Суррогатный идентификатор расписания';
COMMENT ON COLUMN transit.route_schedule.route_id IS 'Логическая связь с route.id';
COMMENT ON COLUMN transit.route_schedule.shift_id IS 'Логическая связь с shift.id';
COMMENT ON COLUMN transit.route_schedule.weekday IS 'День недели: 0 = воскресенье, 1 = понедельник, ..., 6 = суббота';
COMMENT ON COLUMN transit.route_schedule.planned_departure IS 'Плановое локальное время отправления';
COMMENT ON COLUMN transit.route_schedule.valid_from IS 'Первый день действия расписания';
COMMENT ON COLUMN transit.route_schedule.valid_to IS 'Последний день действия, если известен';

-- assignment: Наряд: назначение водителя и автобуса на маршрут и смену
CREATE TABLE IF NOT EXISTS transit.assignment (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_id bigint NOT NULL,
    bus_id bigint NOT NULL,
    driver_id bigint NOT NULL,
    shift_id bigint NOT NULL,
    service_date date NOT NULL,
    status text NOT NULL DEFAULT 'scheduled',
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE transit.assignment IS 'Наряд: назначение водителя и автобуса на маршрут и смену';
COMMENT ON COLUMN transit.assignment.id IS 'Суррогатный идентификатор наряда';
COMMENT ON COLUMN transit.assignment.route_id IS 'Логическая связь с route.id';
COMMENT ON COLUMN transit.assignment.bus_id IS 'Логическая связь с bus.id';
COMMENT ON COLUMN transit.assignment.driver_id IS 'Логическая связь с driver.id';
COMMENT ON COLUMN transit.assignment.shift_id IS 'Логическая связь с shift.id';
COMMENT ON COLUMN transit.assignment.service_date IS 'Дата работы по наряду';
COMMENT ON COLUMN transit.assignment.status IS 'Состояние наряда';
COMMENT ON COLUMN transit.assignment.created_at IS 'Момент регистрации наряда';

-- trip: Фактический или запланированный рейс по наряду
CREATE TABLE IF NOT EXISTS transit.trip (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    assignment_id bigint NOT NULL,
    trip_number integer NOT NULL,
    planned_start_at timestamptz NOT NULL,
    planned_end_at timestamptz,
    actual_start_at timestamptz,
    actual_end_at timestamptz,
    status text NOT NULL DEFAULT 'scheduled'
);
COMMENT ON TABLE transit.trip IS 'Фактический или запланированный рейс по наряду';
COMMENT ON COLUMN transit.trip.id IS 'Суррогатный идентификатор рейса';
COMMENT ON COLUMN transit.trip.assignment_id IS 'Логическая связь с assignment.id';
COMMENT ON COLUMN transit.trip.trip_number IS 'Порядковый номер рейса в рамках наряда';
COMMENT ON COLUMN transit.trip.planned_start_at IS 'Запланированный момент начала рейса';
COMMENT ON COLUMN transit.trip.planned_end_at IS 'Запланированный момент окончания рейса';
COMMENT ON COLUMN transit.trip.actual_start_at IS 'Реальный момент начала рейса';
COMMENT ON COLUMN transit.trip.actual_end_at IS 'Реальный момент завершения рейса';
COMMENT ON COLUMN transit.trip.status IS 'Состояние рейса';

-- vehicle_position: Таблица-факт телеметрии движения автобуса; 2+ млн строк на неделе 4
CREATE TABLE IF NOT EXISTS transit.vehicle_position (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    trip_id bigint NOT NULL,
    observed_at timestamptz NOT NULL,
    latitude numeric(9,6) NOT NULL,
    longitude numeric(9,6) NOT NULL,
    speed_kmh numeric(5,2) NOT NULL,
    source text NOT NULL DEFAULT 'simulated'
);
COMMENT ON TABLE transit.vehicle_position IS 'Таблица-факт телеметрии движения автобуса; 2+ млн строк на неделе 4';
COMMENT ON COLUMN transit.vehicle_position.id IS 'Суррогатный идентификатор замера';
COMMENT ON COLUMN transit.vehicle_position.trip_id IS 'Логическая связь с trip.id; автобус определяется по наряду';
COMMENT ON COLUMN transit.vehicle_position.observed_at IS 'Момент получения геопозиции';
COMMENT ON COLUMN transit.vehicle_position.latitude IS 'Широта GPS-позиции';
COMMENT ON COLUMN transit.vehicle_position.longitude IS 'Долгота GPS-позиции';
COMMENT ON COLUMN transit.vehicle_position.speed_kmh IS 'Скорость автобуса в км/ч';
COMMENT ON COLUMN transit.vehicle_position.source IS 'Источник измерения, например simulated';

-- bus_maintenance: История обслуживания и ремонта автобусов
CREATE TABLE IF NOT EXISTS transit.bus_maintenance (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bus_id bigint NOT NULL,
    service_date date NOT NULL,
    maintenance_type text NOT NULL,
    cost numeric(12,2),
    description text
);
COMMENT ON TABLE transit.bus_maintenance IS 'История обслуживания и ремонта автобусов';
COMMENT ON COLUMN transit.bus_maintenance.id IS 'Суррогатный идентификатор обслуживания';
COMMENT ON COLUMN transit.bus_maintenance.bus_id IS 'Логическая связь с bus.id';
COMMENT ON COLUMN transit.bus_maintenance.service_date IS 'Дата обслуживания';
COMMENT ON COLUMN transit.bus_maintenance.maintenance_type IS 'Тип обслуживания или ремонта';
COMMENT ON COLUMN transit.bus_maintenance.cost IS 'Стоимость работ, если известна';
COMMENT ON COLUMN transit.bus_maintenance.description IS 'Примечания по обслуживанию';

COMMIT;
