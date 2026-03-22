# RU Net Blacklist

Списки доменов/подсетей и кастомный Podkop для OpenWrt.

## Что это

Проект дает:

- базу сервисов `services/`
- готовые секции `lists/`
- кастомный Podkop с community-списками:
  - стандартные списки Podkop
  - ваши секции из `lists/`
- установку на роутер одной командой

## Установка одной командой

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/install.sh)
```

или напрямую:

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/podkop-fork/install.sh)
```

## Community-секции (наши)

- `ai_all` — AI инструменты
- `gaming` — Игры
- `social_networks` — Социальные сети
- `messengers_calls` — Мессенджеры и звонки
- `video_audio_streaming` — Видео и стриминг
- `news_media` — Новости и медиа
- `developer_platforms` — Платформы для разработчиков
- `cloud_storage` — Облачные хранилища

## Как выпускается наш Podkop

При push тега `podkop-v*` запускается GitHub Actions:

- `.github/workflows/release-custom-podkop.yml`

Он:

1. Собирает `podkop` и `luci-app-podkop` (`ipk` и `apk`) из `_podkop_upstream/`
2. Публикует артефакты в GitHub Release

## Где что лежит

- `_podkop_upstream/` — исходники кастомного Podkop
- `podkop-fork/` — установщик и инструкция
- `lists/` — агрегированные списки
- `services/` — отдельные сервисы
- `selector/` — генератор ключа выбора списков
- `wiki/` — документация

## Благодарность

Спасибо автору Podkop:

- https://github.com/itdoginfo/podkop
