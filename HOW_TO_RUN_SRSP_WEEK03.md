# СРСП, неделя 3 — инструкции для Windows CMD

Проект **СРСП «Городской пассажирский транспорт»**, папка `C:\Users\dakar\transit-db`, база `transit`, пользователь `transit_app`. Не смешивать с СРС `food_delivery`.

1. Распакуйте архив в `C:\Users\dakar\transit-db`, чтобы были `migrations\03_constraints.sql`, `queries\week03_negative.sql`, `checks\week03_verify.sql`, `reports\week03.md`. Не заменяйте файлы второй недели.
2. В CMD выполните:

```cmd
cd /d C:\Users\dakar\transit-db
set "PGCLIENTENCODING=UTF8"
"C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" -U transit_app -d transit -n transit -f "%USERPROFILE%\transit_before_week03.sql"
echo %ERRORLEVEL%
```

3. **Сначала тестовая база**, чтобы защитить основную:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -c "CREATE DATABASE transit_test3 OWNER transit_app;"
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test3 -v ON_ERROR_STOP=1 -f "%USERPROFILE%\transit_before_week03.sql"
echo %ERRORLEVEL%
```

4. Установите ограничения в тестовой базе:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test3 -v ON_ERROR_STOP=1 -f "migrations\03_constraints.sql"
echo %ERRORLEVEL%
```

Ожидаются `COMMIT` и `0`. Если возникла ошибка, **не запускайте на основной базе**.

5. Негативные тесты (ожидается **14 ошибок**; `ERRORLEVEL` может быть 0, поэтому смотрите сами SQLSTATE):

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test3 -f "queries\week03_negative.sql"
```

После подтверждения 14 ошибок можно сохранить лог отдельной командой. Для перенаправления вывода с запросом пароля сначала выполните без перенаправления, чтобы убедиться в успешном входе:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test3 -f "queries\week03_negative.sql" > "reports\week03_server_output.txt" 2>&1
```

6. Проверка структуры:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit_test3 -v ON_ERROR_STOP=1 -f "checks\week03_verify.sql"
```

7. Запускайте миграцию на **основной** базе только после успешной проверки и резервного копирования:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit -v ON_ERROR_STOP=1 -f "migrations\03_constraints.sql"
echo %ERRORLEVEL%
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -X -U transit_app -d transit -v ON_ERROR_STOP=1 -f "checks\week03_verify.sql"
```

8. Вставьте **фактические** SQLSTATE и имена ограничений из логов в `reports\week03.md`. После завершения работ удаляйте тестовую базу только если она не нужна:

```cmd
"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -c "DROP DATABASE transit_test3;"
```

9. Добавьте только нужные файлы в текущий Git-репозиторий:

```cmd
git add migrations/03_constraints.sql queries/week03_negative.sql checks/week03_verify.sql reports/week03.md HOW_TO_RUN_SRSP_WEEK03.md
git status
git commit -m "Add SRSP Week 3 integrity constraints and tests"
git push origin main
```

*Примечание:* ошибки кодировки в CMD исправляет `set "PGCLIENTENCODING=UTF8"`, но русские ошибки могут выглядеть искажёнными. Важно читать SQLSTATE, `COMMIT` и `ERRORLEVEL`. На этапе теста **не делайте `git push` до обновления отчёта реальными результатами**.
