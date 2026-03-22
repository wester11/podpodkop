# Добавление новой секции в "Списки сообщества"

Пример: добавить секцию `creator_platforms`.

## 1. Подготовить список в репозитории списков

Убедитесь, что есть:

- `lists/creator_platforms/domains.srs`
- `lists/creator_platforms/subnets.srs`

## 2. Добавить тег в backend Podkop

Файл:

- `_podkop_upstream/podkop/files/usr/lib/constants.sh`

Добавьте `creator_platforms` в `COMMUNITY_SERVICES`.

## 3. Добавить пункт в LuCI UI

Файлы:

- `_podkop_upstream/fe-app-podkop/src/constants.ts`
- `_podkop_upstream/luci-app-podkop/htdocs/luci-static/resources/view/podkop/main.js`

Добавьте в `DOMAIN_LIST_OPTIONS`:

- ключ: `creator_platforms`
- значение: `Платформы для креаторов`

## 4. Выпустить новый релиз fork Podkop

После изменений соберите и выпустите новый tag в fork Podkop.

## 5. Проверка

1. Обновите Podkop на роутере.
2. Откройте LuCI.
3. Проверьте, что в `Списки сообщества` появился новый пункт.
