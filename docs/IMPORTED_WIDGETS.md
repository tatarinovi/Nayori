# Перенесённые виджеты Ryoku

Подключено 83 оригинальных компонентов: ii — 46, Python — 28, Shima — 9. Ещё 80 записей не перенесены. Дополнительно в исходном реестре есть один алиас той же карточки даты; он не считается отдельным виджетом. Собственные шесть типов Nayori в эти числа не входят.

Это промежуточный результат переноса. Последние изменения не проверялись локальным запуском по просьбе пользователя; загрузка и функциональные проверки добавлены в CI, результат CI пока не получен. Живой Wayland-ввод, GPU-эффекты и соответствие оригиналу на реальном мониторе не подтверждены.

## Источники и лицензии

Исходники закреплены на Ryoku `2befae30e0e1e8d370a8fdb4489e84be529af1bd` из https://github.com/Ryoku-dev/ryoku. Локальная копия исходников использовалась только как источник; установленные конфигурации Ryoku не изменялись. Путь каждого оригинала и хеши исходной и адаптированной версии записаны в [manifest.json](../surfaces/desktop/vendor/widgets/manifest.json).

- ii: GPLv3, исходная цепочка авторов ii / illogical-impulse сохранена в [NOTICE](../NOTICE).
- Shima: GPLv3 и дополнительные условия раздела 7, [shima-NOTICE](../surfaces/desktop/vendor/widgets/shima-NOTICE). Based on iNiR by snowarch (https://github.com/snowarch/inir). Это модифицированный перенос.
- Python: Ryoku / Serpantinum, ilyamiro и участники проекта, AGPL-3.0-or-later; [python-NOTICE](../surfaces/desktop/vendor/widgets/python-NOTICE) и полный текст лицензии сохранены рядом. Покрытые части не перелицензированы под GPL Nayori.
- Material Shapes: MIT. Inter, Rubik, Montserrat: SIL OFL; уведомления рядом со шрифтами. Material Symbols Rounded: Apache-2.0, отдельная закреплённая версия указана в манифесте.

## Данные и экземпляры

`ImportedWidgets.js` задаёт каталог, размеры и исходные параметры; `WidgetLayout.js` сохраняет независимые JSON-параметры экземпляров по мониторам. `ImportedWidgetFace.qml` загружает оригинальный адаптированный компонент, а `ImportedWidgetBridge.qml` передаёт существующие сервисы Nayori. Отдельные upstream-демоны и глобальные хранилища настроек не запускаются.

Процессор, память, GPU, температура, диски и uptime берутся из общего SystemReader / SystemMonitor. Батарея — из Quickshell UPower. Календарь — из CalendarService Nayori; названия и даты переводятся в схему ii, события через полночь учитываются по пересечению, дата окончания all-day остаётся исключающей. Погода — из общего ответа службы Nayori. Отсутствие показаний не заменяется демонстрационными числами.

Python Lyrics Simple использует общий MusicService: подписка действует при видимом экземпляре, подсветка следует текущей строке, нажатие на строку перематывает текущий MPRIS-плеер. Доступен также обычный текст без временных меток. Локальный upstream-файловый редактор текста песни не запускается. Пословная разметка пока не передаётся этому лицу.

Динамические цвета Nayori включены по умолчанию, явное отключение сохраняется для экземпляра. Для Shima доступны исходные параметры материала и темы. Дополнительное пространственное извлечение яркости обоев не подключено; текстовые шрифты, отсутствующие в системе и комплекте, используют fallback Qt. Это ограничение отображения, не подтверждение полного визуального совпадения.

## Последняя группа

К трём календарным лицам ii добавлены PcBatteryBars, PcBatteryCable и ResourceFillCards; Shima — IrisDayFace; Python — MusicFaceLyricsSimple с исходным LyricsView. Добавлены проверки отсутствующих показаний, следующего события, многодневной даты, текста песни, перемотки и освобождения подписок. Общий smoke загружает весь текущий каталог.

## Оставшиеся записи

«Не перенесён» означает незавершённую адаптацию, а не принципиальную невозможность. Зависимости с неподтверждёнными правами на распространение и отсутствующие исходные файлы отмечены отдельно. Они не копируются и не заменяются похожим оформлением.

### ii

| ID | Состояние | Причина |
| --- | --- | --- |
| clock_nagasaki | Не перенесён | Nagasaki/Ndot font assets and redistribution rights are absent from the source snapshot; no substitute is presented as the original. |
| clock_ios | Не перенесён | Bundled SF Pro font redistribution rights not established; no font substituted. |
| clock_nothing | Не перенесён | Nagasaki/Ndot font assets and redistribution rights are absent from the source snapshot; no substitute is presented as the original. |
| nagasaki_text | Не перенесён | Nagasaki/Ndot font assets and redistribution rights are absent from the source snapshot; no substitute is presented as the original. |
| clock_wearos | Не перенесён | Complication providers (phone, calendar, battery, media) not yet adapted. |
| wearos_arc_clock | Не перенесён | Complication providers (phone, calendar, battery, media) not yet adapted. |
| clock_expressive_card | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| circular_media | Не перенесён | MPRIS source/control adapter not yet ported. |
| media_circular | Не перенесён | MPRIS source/control adapter not yet ported. |
| media_expressive | Не перенесён | MPRIS source/control adapter not yet ported. |
| media_android | Не перенесён | MPRIS source/control adapter not yet ported. |
| media_cd | Не перенесён | MPRIS source/control adapter not yet ported. |
| nothing_ring_media | Не перенесён | MPRIS source/control adapter not yet ported. |
| weather_default | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| weather_expressive | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| weather_forecast | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| weather_card | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| weather_icon | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| weather_pill | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| weather_circle | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| nothing_weather_circle | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| volume_mute_pill | Не перенесён | Widget-specific service adapter not yet ported. |
| wifi_pill | Не перенесён | Widget-specific service adapter not yet ported. |
| bluetooth_pill | Не перенесён | Widget-specific service adapter not yet ported. |
| mic_pill | Не перенесён | Widget-specific service adapter not yet ported. |
| dark_mode_pill | Не перенесён | Widget-specific service adapter not yet ported. |
| screen_record_pill | Не перенесён | Widget-specific service adapter not yet ported. |
| easy_effects_pill | Не перенесён | Widget-specific service adapter not yet ported. |
| easyeffects_preset_portrait | Не перенесён | Widget-specific service adapter not yet ported. |
| easyeffects_preset_landscape | Не перенесён | Widget-specific service adapter not yet ported. |
| weather_typography | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| weather_hourly | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| photo_weather_2x1 | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| photo_pill_2x1 | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| photo_minimal_temp_2x1 | Не перенесён | Requires Google Weather SVGs from mrdarrengriffin/google-weather-icons; its License section reserves all icons to Google and grants no redistribution license. No artwork copied. |
| bluetooth_battery | Не перенесён | Requires phone/KDE Connect or Bluetooth battery provider not yet adapted. |
| bluetooth_headphone | Не перенесён | Requires phone/KDE Connect or Bluetooth battery provider not yet adapted. |
| mobile_battery | Не перенесён | Requires phone/KDE Connect or Bluetooth battery provider not yet adapted. |
| bluetooth_headphone_cookie | Не перенесён | Requires phone/KDE Connect or Bluetooth battery provider not yet adapted. |
| bluetooth_fill_cards | Не перенесён | Requires phone/KDE Connect or Bluetooth battery provider not yet adapted. |
| devices_battery_list | Не перенесён | Requires phone/KDE Connect or Bluetooth battery provider not yet adapted. |
| devices_battery_list_1x1 | Не перенесён | Requires phone/KDE Connect or Bluetooth battery provider not yet adapted. |
| bluetooth_earbuds_stem | Не перенесён | Requires phone/KDE Connect or Bluetooth battery provider not yet adapted. |
| email_inbox | Не перенесён | Upstream utility service/actions not yet adapted. |
| email_inbox_2x1 | Не перенесён | Upstream utility service/actions not yet adapted. |
| ai_chat | Не перенесён | Upstream utility service/actions not yet adapted. |
| notes_widget | Не перенесён | Upstream utility service/actions not yet adapted. |
| notes_widget_2x1 | Не перенесён | Upstream utility service/actions not yet adapted. |
| compact_media | Не перенесён | MPRIS source/control adapter not yet ported. |
| quick_actions | Не перенесён | Upstream utility service/actions not yet adapted. |
| android_search_bar | Не перенесён | Upstream utility service/actions not yet adapted. |
| search_pill | Не перенесён | Upstream utility service/actions not yet adapted. |
| water_reminder | Не перенесён | Upstream utility service/actions not yet adapted. |
| at_a_glance | Не перенесён | Upstream utility service/actions not yet adapted. |
| resource_nothing_disk | Не перенесён | Original face requires Ndot57-Regular.otf; font assets and redistribution rights are absent from the source snapshot. No substitute is presented as the original. |
| resource_nothing_cpu | Не перенесён | Original face requires Ndot57-Regular.otf; font assets and redistribution rights are absent from the source snapshot. No substitute is presented as the original. |
| resource_nothing_ram | Не перенесён | Original face requires Ndot57-Regular.otf; font assets and redistribution rights are absent from the source snapshot. No substitute is presented as the original. |
| wearos_clock | Не перенесён | Complication provider services not yet adapted. |
| clock_ios_tile | Не перенесён | Original QML imports RoundedRectRay.js, absent from the pinned Ryoku tree. |
| clock_california | Не перенесён | Original QML imports RoundedRectRay.js, absent from the pinned Ryoku tree. |
| date | Алиас | Same DateWidget.qml implementation as date_default; one catalogue entry avoids duplication. |

### python

| ID | Состояние | Причина |
| --- | --- | --- |
| UserFace | Не перенесён | Profile and sound action adapters not yet ported. |
| NotesFace | Не перенесён | Original notes opens a separate quick-actions editor and shared file store; no instance-safe editor adapter yet. |
| MusicFaceLyrics | Не перенесён | System/media/weather/audio data adapter not yet ported. |
| GithubFace | Не перенесён | Original GitHub settings opens a separate Ryoku layer window; network/cache adapter not yet ported. |

### shima

| ID | Состояние | Причина |
| --- | --- | --- |
| mediaControls | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| controls | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| todo | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| notes | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| timers | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| screenTime | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| worldClock | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| userCard | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| newsTicker | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| customImage | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| editorial | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| imageConverter | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| japaneseTypography | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| visualizer | Не перенесён | iRiS face requires upstream appearance/data provider; not yet adapted. |
| shape | Не перенесён | Standalone iNiR component outside Ryoku IrisRoster; its concrete renderer/settings adapter has not been ported. |
| organicEdge | Не перенесён | Standalone iNiR component outside Ryoku IrisRoster; its concrete renderer/settings adapter has not been ported. |

## Проверки CI

`tests/imported-widgets.cjs` проверяет каталог, исходники, ограничения геометрии, параметры и изоляцию экземпляров. `tests/imported-widgets.py` запускает `ImportedWidgetsSmoke.qml` offscreen с временными XDG-каталогами, искусственными данными и повторным чтением настроек. Эти проверки входят в существующие unit/smoke-наборы CI. Локально они не запускались для этой группы.
