# Сборка и релиз форка Podkop

## 1. Создать fork репозитория Podkop

Форкните:

- `https://github.com/itdoginfo/podkop`

## 2. Перенести изменения

Из локальной папки `_podkop_upstream/` перенесите изменения в ваш fork:

- `fe-app-podkop/src/constants.ts`
- `luci-app-podkop/htdocs/luci-static/resources/view/podkop/main.js`
- `luci-app-podkop/htdocs/luci-static/resources/view/podkop/section.js`
- `podkop/files/usr/lib/constants.sh`
- `podkop/files/usr/bin/podkop`
- `podkop/files/etc/config/podkop`

## 3. Выпустить релиз в fork

В upstream сборка релиза запускается на tag (`.github/workflows/build.yml`).

В вашем fork:

1. Запушьте изменения в `main`.
2. Создайте tag, например:
   - `v0.7.0-ru1`
3. Запушьте tag:
   - `git push origin v0.7.0-ru1`

После этого GitHub Actions соберет `ipk/apk` пакеты и прикрепит их к релизу.

## 4. Установочный скрипт

В `podkop-fork/install.sh` поставьте ваш fork:

- `PODKOP_FORK_REPO="<ваш_user>/podkop"`

Тогда установка будет идти из ваших релизов.

## 5. Команда установки для пользователей

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/podkop-fork/install.sh)
```

Важно: если используете свой fork Podkop, обновите `install.sh`, чтобы он качал пакеты именно из вашего `PODKOP_FORK_REPO`.
