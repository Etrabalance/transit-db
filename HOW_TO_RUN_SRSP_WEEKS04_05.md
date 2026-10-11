# СРСП №4 + №5 — единый проект `transit-db`

Оба задания объединены в один архив, но требуемые преподавателем файлы остались **раздельными**: `seed/*.sql`, `reports/week04.md`, `queries/week05.sql`, `reports/week05.md`.

**Нужно:** PostgreSQL 18, база `transit` с полностью проверенными миграциями недель 1–3. Весь год модели — **2025**, реальные текущие дни могут не иметь рейсов. Миграция недели 3 должна уже быть выполнена; архив её не перезаписывает.

## Порядок — сначала тестовая база

Распакуйте архив в `C:\Users\dakar\transit-db`, объединяя папки `seed`, `queries`, `checks`, `reports` с прежними. Убедитесь, что файлы видны по путям `seed\04_01_reference.sql` и `queries\week05.sql`.

Открыть CMD:

```cmd
cd /d C:\Users\dakar\transit-db
set "PGCLIENTENCODING=UTF8"
"C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" -U transit_app -d transit -n transit -f "%USERPROFILE%\transit_before_week04.sql"
echo %ERRORLEVEL%
```

Если `transit_test3` ещё существует, **не используйте её повторно**. Создайте отдельную `transit_test45`:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -c "CREATE DATABASE transit_test45 OWNER transit_app;"
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test45 -v ON_ERROR_STOP=1 -f "%USERPROFILE%\transit_before_week04.sql"
echo %ERRORLEVEL%
```

В тестовой базе, **в указанном порядке**, выполняйте по одной команде и при каждой проверяйте `echo %ERRORLEVEL%` — ожидается `0`:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test45 -v ON_ERROR_STOP=1 -f "seed\04_01_reference.sql"
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test45 -v ON_ERROR_STOP=1 -f "seed\04_02_year.sql"
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test45 -v ON_ERROR_STOP=1 -f "seed\04_03_telemetry.sql"
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test45 -v ON_ERROR_STOP=1 -f "seed\04_04_dml.sql"
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test45 -v ON_ERROR_STOP=1 -f "checks\week04_verify.sql"
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test45 -v ON_ERROR_STOP=1 -f "queries\week05.sql"
```

Скрипт `04_03_telemetry.sql` создаёт **2 102 400 строк до удаления отменённых рейсов** и может работать несколько минут. Размер БД способен превысить **сотни МБ**, нужен свободный диск. `04_04_dml.sql` сравнивает `\copy` 100 000 строк и динамический цикл 100 000 отдельных `INSERT`; возможна заметная нагрузка CPU. Не запускайте эти команды несколько раз подряд без причины.

## Результат запуска 12.10.2026

Скрипты недель 4 и 5 **успешно выполнены в основной базе `transit`**, перед этим проверены в тестовой `transit_test45`. В основной базе: 18 таблиц, 29 200 нарядов, 175 200 рейсов, 173 556 архивных рейсов, 2 082 672 GPS-записи; размер 326 МБ, ошибки выполнения отсутствуют (`ERRORLEVEL=0`). `queries/week05.sql` выполнил все 28 запросов.

Реальные времена вставки в основную базу: телеметрия 23 897,276 мс; 100 000 строк через `\copy` 30,621 мс; 100 000 `INSERT` в серверном цикле 668,551 мс (отношение ~21,83). Подробнее — `reports/week04.md`, `reports/week05.md`.

**Не запускайте генераторы повторно в основной базе:** данные там уже есть. Если требуется подтверждение, используйте только проверочные `checks/week04_verify.sql` и читающие `queries/week05.sql`.

## Отправка файлов проекта в GitHub

В директории `C:\Users\dakar\transit-db` файлы должны находиться по путям из архива. Перед отправкой:

```cmd
git status
git add seed/ queries/week05.sql checks/week04_verify.sql reports/week04.md reports/week05.md HOW_TO_RUN_SRSP_WEEKS04_05.md
git commit -m "Add SRSP Weeks 4 and 5"
git push origin main
git status
```

**Не добавляйте** локальные `.sql`-дампы резервных копий и ZIP. CSV `seed/week04_stops_export.csv` создан при работе `04_04_dml.sql`; он входит в `git add seed/`.

После подтверждения, что основная база работает и коммит отправлен на GitHub, тестовую базу можно удалить отдельно (необязательно):

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -c "DROP DATABASE transit_test45;"
```

**Оговорка:** маршруты/остановки из `04_01_reference.sql` — синтетические, не реальные открытые данные. Для максимального балла понадобится реальный источник (см. `seed/04_OPEN_DATA_NOTICE.md`). Замеры нельзя заполнять до фактического запуска.
