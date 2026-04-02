# Защитить демократию

Минимальный браузерный прототип на `Phaser`.

Что внутри:
- стартовый экран с печатающимся прологом;
- кнопка `Защитить демократию!`;
- игровая сцена с 5 линиями;
- `Славян` как цель защиты;
- защитники `Стул` и `Вайнштейн`;
- атакующие `Прокурор` и `Гвардия`;
- подписи над юнитами и полосы HP.

## Запуск

Открывать лучше через локальный HTTP-сервер, а не через `file://`.

Если установлен Python:

```powershell
python -m http.server 8000
```

Потом открыть:

```text
http://localhost:8000
```

## Деплой

Проект подготовлен под `GitHub Pages`.

Что уже добавлено:
- `.github/workflows/deploy-pages.yml`
- `.nojekyll`
- `.gitignore`

Чтобы выложить сайт:

```powershell
git init
git add .
git commit -m "Initial deploy"
git branch -M main
git remote add origin <URL_репозитория>
git push -u origin main
```

После пуша:
- открой настройки репозитория на GitHub;
- включи `Pages`;
- в `Build and deployment` выбери `GitHub Actions`.

Дальше сайт будет публиковаться автоматически на каждый пуш в `main`.
