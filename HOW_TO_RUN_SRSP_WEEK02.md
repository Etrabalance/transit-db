# СРСП: неделя 2 — городской пассажирский транспорт

**Что это:** схема на 15 таблиц, ER-диаграмма, отчёт по 3НФ. Подготовлена по файлам
«Задание 1.docx» (структура 3 таблиц) и «Неделя 2» (часть А — СРСП).

## ВАЖНО

- Это **СРСП по транспорту**, а не СРС по доставке еды. **Не запускай** SQL в базе `food_delivery`.
- В задании преподавателя указан «плохой файл» `trips_flat.csv`; его не было, поэтому
  **задание с ним пропущено**. Отчёт честно отмечает этот пропуск.
- `02_schema.sql` не удаляет данные; проверка на вашем PostgreSQL ещё нужна.
- Физические FOREIGN KEY не добавляются в неделю 2, только логические связи на ER.
- Исходные три таблицы `depot`, `route`, `stop` восстановлены по скриншоту из
  «Задание 1.docx» на странице 3. Если текущая структура отличается, прежде чем
  запускать скрипт, нужно сверить и исправить расхождения.

## Содержимое

- `migrations/02_schema.sql` — DDL всех 15 таблиц с комментариями.
- `diagrams/transit_er.png` — ER PNG.
- `diagrams/transit_er.dbml` — редактируемый исходник для dbdiagram.io.
- `diagrams/transit_er.dot` — редактируемый исходник Graphviz PNG.
- `reports/week02.md` — отчёт с обоснованиями.
- `checks/week02_verify.sql` — проверка количества таблиц, сохранения старых строк.

## Проверка, Windows CMD

Скопируй папки из архива в **отдельный каталог проекта транспорта**, например:
`C:\Users\dakar\transit-db`. Не помещай их в `food-delivery-db`.

Сначала в CMD (можно находиться в любой папке):

```cmd
"C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" -U transit_app -d transit -n transit -f "%USERPROFILE%\transit_before_week02.sql"
echo %ERRORLEVEL%
```

При успешном резервном копировании ожидаем `0`. Затем из каталога транспорта:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit -v ON_ERROR_STOP=1 -f "migrations\02_schema.sql"
echo %ERRORLEVEL%
```

После `COMMIT` / `0` проверь:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit -v ON_ERROR_STOP=1 -f "checks\week02_verify.sql"
echo %ERRORLEVEL%
```

По документу первой недели до обновления было 3 депо, 5 маршрутов, 15 остановок;
проверка должна сохранить существующее число записей (если ты не добавлял новые).

**После запуска** внеси фактические результаты в раздел 7 `reports/week02.md`,
затем сохраняй в отдельный Git-репозиторий СРСП по транспорту.
