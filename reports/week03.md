# СРСП — Неделя 3. Ограничения целостности

**Проект:** Городской пассажирский транспорт (`transit`)  
**СУБД:** PostgreSQL 18.6  
**Основа:** `migrations/02_schema.sql` недели 2 (15 таблиц).  
**Состояние:** миграция успешно применена сначала к тестовой базе `transit_test3`, затем к основной базе `transit` (обе транзакции завершились `COMMIT`, код завершения `0`). Все 14 негативных тестов выполнены на `transit_test3` и дали ожидаемые SQLSTATE и названия ограничений.

## 1. Задача и изменения

Задача — не дать базе принять неверные данные даже тогда, когда приложение допускает ошибку. В миграции `migrations/03_constraints.sql` установлены **18 внешних ключей**, **37 CHECK**, четыре новых правила уникальности (одно — частичный уникальный индекс), **два ENUM** и домен `transit.phone_kz`. Даты, скоростные ограничения, координаты и правила нарядов проверяются непосредственно в БД. Изменения находятся внутри `BEGIN ... COMMIT`.

В модели недели 2 было 15 таблиц. Для части задания про **статус обращения и телефон заявителя** добавлены `applicant` и `service_request`; теперь таблиц **17**. Поля `driver.birth_date` и `driver.experience_years` добавлены для проверки стажа. Поле `assignment.driver_id` разрешает `NULL` ради архивных нарядов, если запись водителя удалена. **Старые строки миграция не удаляет.**

## 2. Внешние ключи и действия при удалении

| Дочерняя таблица → родительская | `ON DELETE` | Обоснование |
|---|---|---|
| `bus.model_id → bus_model.id` | `RESTRICT` | Нельзя удалить модель, которую использует автобус. |
| `bus.depot_id → depot.id` | `RESTRICT` | Парк с автобусами нельзя удалить. |
| `driver.depot_id → depot.id` | `RESTRICT` | Нельзя удалить парк, пока за ним закреплены водители. |
| `driver_license.driver_id → driver.id` | `CASCADE` | Вместе с водителем убирают вспомогательные записи допусков. |
| `driver_license.category_id → license_category.id` | `RESTRICT` | Категория с выданными допусками остаётся в справочнике. |
| `route_stop.route_id → route.id` | `CASCADE` | При удалении маршрута исчезают только его строки остановок. |
| `route_stop.stop_id → stop.id` | `RESTRICT` | Общая остановка не должна исчезнуть из других маршрутов. |
| `route_schedule.route_id → route.id` | `CASCADE` | Расписание удалённого маршрута не нужно. |
| `route_schedule.shift_id → shift.id` | `RESTRICT` | Используемую смену нельзя удалить. |
| `assignment.route_id → route.id` | `RESTRICT` | История нарядов удерживает маршрут. |
| `assignment.bus_id → bus.id` | `RESTRICT` | История назначения автобуса сохраняется. |
| `assignment.driver_id → driver.id` | `SET NULL` | Архивный наряд сохраняется даже без карточки водителя. |
| `assignment.shift_id → shift.id` | `RESTRICT` | Используемая смена не должна исчезать. |
| `trip.assignment_id → assignment.id` | `RESTRICT` | Нельзя удалить наряд с рейсами. |
| `vehicle_position.trip_id → trip.id` | `CASCADE` | При удалении рейса исчезает его телеметрия. |
| `bus_maintenance.bus_id → bus.id` | `RESTRICT` | История ремонта не должна теряться. |
| `service_request.applicant_id → applicant.id` | `RESTRICT` | Обращение сохраняет заявителя. |
| `service_request.route_id → route.id` | `SET NULL` | Обращение останется в системе, если маршрут удалён. |

Для **всех** этих связей выбран `ON UPDATE RESTRICT`, чтобы нельзя было произвольно менять идентификатор, на который ссылаются другие записи. `CASCADE` применён только к зависимым записям, а не ко всей системе.

## 3. CHECK: правила транспортной предметной области

Миграция добавляет **37 именованных CHECK**; более 12 из них проверяют содержательные правила, например:

| Ограничение | Правило |
|---|---|
| `route_length_positive_ck` | Длина маршрута от 0 до 300 км, без нулевых/отрицательных значений. |
| `stop_latitude_bounds_ck` | Широта от −90 до 90. |
| `stop_longitude_bounds_ck` | Долгота от −180 до 180. |
| `bus_model_capacity_ck` | Вместимость автобуса от 1 до 250 пассажиров. |
| `bus_model_fuel_type_ck` | Топливо: diesel / gas / electric / hybrid. |
| `bus_manufacture_year_ck` | Год выпуска 1980–2100. |
| `bus_status_valid_ck` | Статус active / maintenance / retired. |
| `driver_adult_ck` | Водитель не младше 18 лет, если дата рождения известна. |
| `driver_experience_age_ck` | Стаж не больше возраста минус 18 лет. |
| `driver_hire_age_ck` | Приём на работу не ранее 18-летия. |
| `driver_license_date_ck` | Категория не истекает до даты выдачи. |
| `route_stop_order_ck` | Порядок остановки начинается с 1. |
| `route_stop_distance_ck` | Расстояние от начала маршрута неотрицательно. |
| `shift_time_rules_ck` | Обычная смена заканчивается позже начала, ночная — переходит через полночь. |
| `route_schedule_weekday_ck` | День недели от 0 до 6. |
| `route_schedule_period_ck` | Дата окончания расписания не раньше начала. |
| `trip_planned_time_ck` | Плановое окончание рейса позже начала. |
| `trip_actual_time_ck` | Фактическое окончание после фактического начала. |
| `trip_completed_has_times_ck` | Завершённый рейс содержит оба фактических времени. |
| `vehicle_position_latitude_ck` | Широта GPS в допустимых пределах. |
| `vehicle_position_longitude_ck` | Долгота GPS в допустимых пределах. |
| `vehicle_position_speed_ck` | Скорость от 0 до 60 км/ч. |
| `bus_maintenance_cost_ck` | Стоимость ремонта неотрицательна. |
| `request_compensation_nonnegative_ck` | Сумма компенсации неотрицательна. |
| `request_chronology_ck` | Обращение закрывается не раньше его создания. |
| `request_closed_has_time_ck` | Закрытое обращение имеет дату завершения. |

Часть ограничений использует дату на текущий момент (`driver_adult_ck`, `driver_experience_age_ck`). Значения `birth_date` и `experience_years` в старой схеме отсутствовали, поэтому были добавлены как необязательные. Для постоянной строгой проверки изменений возраста в реальной системе лучше использовать отдельную логику приложения или триггер.

## 4. UNIQUE, ENUM, DOMAIN

**Уникальность:**

- `bus_active_registration_uq` — частичный уникальный индекс `registration_no` только для `status='active'`. Старое ограничение `bus_registration_no_key`, запрещавшее повторы вообще, заменено на это более точное правило. У снятых с эксплуатации автобусов номера могут повторяться с действующими.
- `route_stop_route_order_uq` — `UNIQUE(route_id,stop_order)` предотвращает две разные остановки с одним номером в одном маршруте.
- `assignment_bus_date_shift_uq` — `UNIQUE(bus_id,service_date,shift_id)` запрещает назначать автобус в два наряда на одну дату и смену.
- `trip_assignment_number_uq` — `UNIQUE(assignment_id,trip_number)` запрещает одинаковые номера рейсов внутри наряда.

**ENUM:** `transit.trip_status` (`scheduled`, `in_progress`, `completed`, `cancelled`) и `transit.request_status` (`new`, `in_progress`, `resolved`, `rejected`). Первый используется в `trip.status`, второй — в `service_request.status`.

**DOMAIN:** `transit.phone_kz AS text CHECK (VALUE ~ '^\+7[0-9]{10}$')` — формат `+7` и 10 цифр. Используется в `driver.phone` и `applicant.phone`, `NULL` допускается, если номер неизвестен.

**ENUM или таблица-справочник?** ENUM хорош для маленького редко меняющегося набора состояний: база не принимает неизвестное значение. Изменение набора ENUM требует команды `ALTER TYPE`, удалять старые значения сложно. Таблица-справочник удобнее, если статусы добавляются часто, имеют описания или управляются пользователями через обычные DML-команды.

## 5. Негативные тесты

`queries/week03_negative.sql` содержит **14 заведомо неверных INSERT/UPDATE**. Перед тестами в транзакции создаются временные учебные записи; после каждого ожидаемого сбоя выполняется `ROLLBACK TO SAVEPOINT`, в конце всей проверки — `ROLLBACK`. **Данные тестов не остаются в базе.**

| № | Сценарий | Ожидаемый SQLSTATE | Ожидаемое имя |
|---:|---|---|---|
| 1 | Несуществующая модель автобуса | 23503 | bus_model_id_fkey |
| 2 | Широта = 100 | 23514 | stop_latitude_bounds_ck |
| 3 | Долгота = 181 | 23514 | stop_longitude_bounds_ck |
| 4 | Вместимость = 0 | 23514 | bus_model_capacity_ck |
| 5 | Повтор госномера активного автобуса | 23505 | bus_active_registration_uq |
| 6 | Повтор номера остановки на маршруте | 23505 | route_stop_route_order_uq |
| 7 | Два наряда для автобуса в одну смену | 23505 | assignment_bus_date_shift_uq |
| 8 | Некорректная дневная смена | 23514 | shift_time_rules_ck |
| 9 | Конец рейса раньше начала | 23514 | trip_planned_time_ck |
| 10 | Скорость = 85 км/ч | 23514 | vehicle_position_speed_ck |
| 11 | Телефон неправильного формата | 23514 | phone_kz_format_ck (DOMAIN) |
| 12 | Неизвестный статус рейса flying | 22P02 | transit.trip_status (ENUM) |
| 13 | Стаж больше допустимого | 23514 | driver_experience_age_ck |
| 14 | Отрицательная компенсация | 23514 | request_compensation_nonnegative_ck |

### Фактический вывод сервера PostgreSQL

**Тестовая база:** `transit_test3`, PostgreSQL 18.6. После исполнения `queries/week03_negative.sql` все 14 намеренно неправильных операций были отклонены сервером. Ниже приведены фактически наблюдавшиеся строки `psql`, коды SQLSTATE и имена ограничений. Русские части диагностик в CMD отображались с нарушенной кодировкой, поэтому приведены машинно-читаемые части реального вывода. `...` означает только пропуск нечитаемого текста сообщения.

```text
[01/14] psql:queries/week03_negative.sql:62:  ... 23503: ...
        CONSTRAINT NAME: bus_model_id_fkey
[02/14] psql:queries/week03_negative.sql:67:  ... 23514: ...
        CONSTRAINT NAME: stop_latitude_bounds_ck
[03/14] psql:queries/week03_negative.sql:72:  ... 23514: ...
        CONSTRAINT NAME: stop_longitude_bounds_ck
[04/14] psql:queries/week03_negative.sql:78:  ... 23514: ...
        CONSTRAINT NAME: bus_model_capacity_ck
[05/14] psql:queries/week03_negative.sql:84:  ... 23505: ...
        CONSTRAINT NAME: bus_active_registration_uq
[06/14] psql:queries/week03_negative.sql:90:  ... 23505: ...
        CONSTRAINT NAME: route_stop_route_order_uq
[07/14] psql:queries/week03_negative.sql:96:  ... 23505: ...
        CONSTRAINT NAME: assignment_bus_date_shift_uq
[08/14] psql:queries/week03_negative.sql:101: ... 23514: ...
        CONSTRAINT NAME: shift_time_rules_ck
[09/14] psql:queries/week03_negative.sql:106: ... 23514: ...
        CONSTRAINT NAME: trip_planned_time_ck
[10/14] psql:queries/week03_negative.sql:111: ... 23514: ...
        CONSTRAINT NAME: vehicle_position_speed_ck
[11/14] psql:queries/week03_negative.sql:116: ... 23514: ...
        DATATYPE NAME: phone_kz
        CONSTRAINT NAME: phone_kz_format_ck
[12/14] psql:queries/week03_negative.sql:121: ... 22P02: ... trip_status: "flying"
        LOCATION: enum_in, enum.c:133
[13/14] psql:queries/week03_negative.sql:126: ... 23514: ...
        CONSTRAINT NAME: driver_experience_age_ck
[14/14] psql:queries/week03_negative.sql:131: ... 23514: ...
        CONSTRAINT NAME: request_compensation_nonnegative_ck
ROLLBACK
=== SRSP WEEK 03: END NEGATIVE TESTS; NO TEST DATA SAVED ===
```

Во всех 14 проверках фактический код ошибки совпал с ожидаемым. После каждой ошибки скрипт использовал `ROLLBACK TO SAVEPOINT`, а в конце общего теста — `ROLLBACK`, поэтому тестовые записи не сохранились.

**Применение миграции к основной базе `transit`:** команда `psql -X -U transit_app -d transit -v ON_ERROR_STOP=1 -f "migrations\03_constraints.sql"` завершилась `COMMIT`, затем `echo %ERRORLEVEL%` вернул `0`. Перед изменениями создана резервная копия `transit_before_week03.sql`; её создание также завершилось с кодом `0`. Наличие всех новых таблиц и ограничений будет дополнительно проверено запросом `checks/week03_verify.sql`.

## 6. Ответы на вопросы преподавателя

**Почему `NOT NULL` быстрее, чем `CHECK (col IS NOT NULL)`?** `NOT NULL` — специальный признак столбца, который PostgreSQL проверяет через встроенный путь обработки значений. `CHECK` требует вычисления выражения; обычно он создаёт чуть больше работы и хуже сообщает семантику обязательного поля. Разница невелика и зависит от версии и нагрузки, но для обязательных полей нужно писать `NOT NULL`.

**Чем `UNIQUE` отличается от `PRIMARY KEY` в отношении `NULL`?** Первичный ключ всегда запрещает `NULL` и однозначно идентифицирует строку. Обычный `UNIQUE` допускает несколько `NULL`, потому что в стандартной семантике PostgreSQL они считаются различными для уникальности. При необходимости можно применить `UNIQUE NULLS NOT DISTINCT` в поддерживаемых версиях.

## 7. Итог

Миграция третьей недели успешно проверена на тестовой базе и применена к основной базе `transit`. В реальном запуске PostgreSQL все 14 негативных тестов выдали ожидаемые коды ошибок и имена ограничений. Тестовые данные откатились; перед обновлением основной базы создана резервная копия.

**Файлы для сдачи:** `migrations/03_constraints.sql`, `queries/week03_negative.sql`, `reports/week03.md`. Дополнительно: `checks/week03_verify.sql`, `HOW_TO_RUN_SRSP_WEEK03.md`.
