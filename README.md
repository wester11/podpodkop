# ru-net-blacklist

![Release](https://img.shields.io/github/v/release/wester11/ru-net-blacklist?sort=semver)
![Build](https://img.shields.io/github/actions/workflow/status/wester11/ru-net-blacklist/release-custom-podkop.yml?label=podkop%20release)
![License](https://img.shields.io/github/license/wester11/ru-net-blacklist)

Репозиторий со списками доменов/подсетей и кастомным `Podkop` для OpenWrt.

## Возможности

- Списки сервисов по категориям (`lists/`) и по отдельным платформам (`services/`).
- Кастомный `Podkop` с доработанным LuCI.
- Поддержка подписок (`Subscribe URL`) для режимов:
  - `Connection URL`
  - `Selector`
  - `URLTest`
- Автоматическая интеграция с Remnawave:
  - авто-`x-hwid`
  - авто-`x-device-os`
  - авто-`x-ver-os`
  - авто-`x-device-model`
  - авто-`user-agent`
  - отображение `x-provider-id` из ответа (если сервер его возвращает)
- В `Selector` и `URLTest` конфиги из подписки автоматически заменяют старый набор.
- One-tap импорт подписки с телефона через кнопку (локальная ссылка на роутер).

## LuCI (упрощено)

В интерфейсе убраны лишние переключатели типов для пользовательских списков.  
Пользователь вводит данные напрямую:

- `User Domains` — текстом (через запятые/пробелы/переносы, с комментариями `//`)
- `User Subnets` — текстом (CIDR/IP, также с комментариями)

## Быстрая установка

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/install.sh)
```

Установка конкретного релиза:

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/install.sh) --release podkop-v0.7.15-ru6
```

Прямой запуск установщика:

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/podkop-fork/install.sh)
```

С ключом выборки списков:

```sh
sh <(wget -O - https://raw.githubusercontent.com/wester11/ru-net-blacklist/main/podkop-fork/install.sh) --key "PK1_ВАШ_КЛЮЧ"
```

## Импорт подписки кнопкой (телефон -> роутер)

После установки скрипт выводит:

- `Mobile import key`
- готовый шаблон URL для кнопки

Формат ссылки для кнопки в подписке:

```text
http://ROUTER_IP/cgi-bin/podkop-import-subscription?key=YOUR_KEY&mode=selector&url=URL_ENCODED_SUBSCRIPTION
```

Где:

- `mode=selector` — импорт в `Selector`
- `mode=urltest` — импорт в `URLTest`
- `mode=url` — импорт первой конфигурации в `Connection URL`

Это позволяет пользователю нажать кнопку на телефоне в локальной сети роутера и автоматически применить подписку в Podkop.

## Структура репозитория

- `lists/` — агрегированные категории.
- `services/` — отдельные сервисы (домен + подсети).
- `_podkop_upstream/` — исходники кастомного Podkop.
- `podkop-fork/` — установщик и логика one-command установки.
- `selector/` — генератор ключа для выборки списков.
- `wiki/` — документация.

## Релизы

Релиз Podkop публикуется через GitHub Actions:

- workflow: `.github/workflows/release-custom-podkop.yml`
- теги: `podkop-v*`
- артефакты:
  - `podkop`
  - `luci-app-podkop`
  - `luci-i18n-podkop-ru`

## Благодарности

Спасибо автору оригинального Podkop:  
[itdoginfo/podkop](https://github.com/itdoginfo/podkop)
