# Кастомный Podkop (релизы этого репозитория)

`install.sh` устанавливает Podkop-пакеты из релизов `wester11/ru-net-blacklist`.

## Установка одной командой

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/podkop-fork/install.sh)
```

Также доступен короткий wrapper:

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/install.sh)
```

После установки обновите страницу LuCI с очисткой кэша браузера (Ctrl+F5).

## Что включено

- Стандартные community-списки Podkop
- Ваши секции из `lists/`:
  - `ai_all`
  - `gaming`
  - `social_networks`
  - `messengers_calls`
  - `video_audio_streaming`
  - `news_media`
  - `developer_platforms`
  - `cloud_storage`

## Как выпускать новую версию пакетов

1. Обновите код в `main`.
2. Создайте tag формата `podkop-vX.Y.Z` (например, `podkop-v0.7.1-ru1`).
3. Запушьте tag в GitHub.

Workflow `.github/workflows/release-custom-podkop.yml` соберет `ipk/apk` и создаст релиз автоматически.
