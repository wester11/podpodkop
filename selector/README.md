# Selector

Статический генератор ключа для `podkop-fork/install.sh`.

## Локальный запуск

Откройте `selector/index.html` в браузере.

Если браузер блокирует `fetch` локального `catalog.json`, поднимите простой сервер:

```sh
python -m http.server 8000
```

и откройте `http://localhost:8000/selector/`.

## На GitHub Pages

Можно публиковать папку `selector/` как статический сайт и генерировать ключ прямо там.
