# RU Net Blacklist

Я собираю и поддерживаю этот репозиторий как набор списков доменов/подсетей и свой форк Podkop для OpenWrt.

## Что внутри

- `services/` - отдельные сервисы (домен + подсети).
- `lists/` - готовые групповые секции (несколько сервисов в одном списке).
- `_podkop_upstream/` - исходники моего кастомного Podkop.
- `selector/` - генератор ключа выбора списков.
- `wiki/` - документация по проекту.

## Что добавлено в моем форке Podkop

- Предустановленные community-секции из этого репозитория:
  - `ai_all` - AI инструменты
  - `gaming` - Игры
  - `social_networks` - Социальные сети
  - `messengers_calls` - Мессенджеры и звонки
  - `video_audio_streaming` - Видео и стриминг
  - `news_media` - Новости и медиа
  - `developer_platforms` - Платформы для разработчиков
  - `cloud_storage` - Облачные хранилища
- Интеграция подписок (Subscribe URL) в интерфейсе Podkop:
  - можно подгружать конфиги по подписке;
  - работает для режимов `Connection URL`, `Selector`, `URLTest`;
  - можно выбирать конфиги из подписки без ручного копирования каждой ссылки.
- Расширенная совместимость с Remnawave:
  - передача `x-hwid`, `x-device-os`, `x-ver-os`, `x-device-model`, `user-agent`;
  - `HWID` можно задать вручную или оставить авто-генерацию на роутере;
  - в режиме `Selector` список серверов из подписки автоматически заменяет старый.

## Установка одной командой

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/install.sh)
```

Прямой запуск установщика:

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/podkop-fork/install.sh)
```

С ключом выбора списков:

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/podkop-fork/install.sh) --key "PK1_ВАШ_КЛЮЧ"
```

## Как собирается релиз Podkop

Релиз запускается тегом формата `podkop-v*`.  
Workflow: `.github/workflows/release-custom-podkop.yml`.

Сборка публикует пакеты в GitHub Releases:

- `podkop`
- `luci-app-podkop`
- `luci-i18n-podkop-ru` (если есть в сборке)

## Благодарность

Отдельное спасибо автору оригинального Podkop:  
[itdoginfo/podkop](https://github.com/itdoginfo/podkop)
