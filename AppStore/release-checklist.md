# Glintwake — подготовка к App Store

Проверка исходников: **2026-11-11**. Подготовка не является отправкой на ревью.
Автоматизация последующих выпусков (2026-11-13):
[настройка и запуск](../Docs/APP_STORE_RELEASE_AUTOMATION.md). Старые ручные шаги
archive/upload/metadata ниже теперь может выполнять workflow после настройки Secrets;
подпись и фактическая готовность Apple пока требуют первого реального прогона.
Версия исходников: **0.1.0 (4)**. Один app target: iOS/iPadOS 17+ и native macOS 14+.
Локальные проверки выполнялись Xcode 27.2 (27B52). Базовая подготовка и build 4 —
коммит `13d952b`; последующая подготовка Duo описана ниже.

## Подготовлено в проекте

- Иконки iOS и Mac: собственная графика, iOS 1024×1024 без альфа-канала.
- EN/RU интерфейс и метаданные: [app-store-metadata.md](app-store-metadata.md).
- [Политика EN/RU](privacy-policy.md), [поддержка EN/RU](support.md), контакт
  panandafog@icloud.com. Ссылки доступны из «Как играть → Конфиденциальность и поддержка».
- `Resources/PrivacyInfo.xcprivacy`: нет tracking/collected data; UserDefaults,
  required-reason `CA92.1` для собственных сохранений и настроек.
- Для Mac явно задан sandbox entitlement без сетевых и файловых исключений.
- `ITSAppUsesNonExemptEncryption = NO`: игра не реализует криптографию или сетевой протокол.
- Debug-only изолированные сцены, отдельная схема `Glintwake Screenshots`, FramePilot
  prepare/capture/export и проверка отсутствия тестовых режимов в Release.
- Release iOS device и Mac проверены на build 3 перед повышением номера до 4; собираются с `CODE_SIGNING_ALLOWED=NO`; bundle-проверки
  manifest, локализаций, звуков, export-compliance и отсутствия debug-маркеров прошли.
- Схема Mac-скриншотов компилируется `build-for-testing`.
- Сняты и просмотрены 40 PNG: по 4 сцены × 2 языка для iPhone, iPad, Mac
  и обоих дисплеев Duo (Closed 1398×2034, Open 2853×2007).
  Выбранные непрозрачные изображения находятся в `AppStore/screenshots`.
- Duo: Debug-сборка build 4, 16 кадров, 0 ошибок. Проверен реальный ход и смена
  Closed → Open → Closed → Open без сброса позиции, кристаллов и счётчика 3/7.
- Два UI-теста прошли: политика/поддержка доступны из русской справки; открытие
  Debug-сцены не сбрасывает сохранённую тестовую игровую сессию.

## Перед публикацией — требуется владелец / App Store Connect

1. **Commit и push** подготовленных файлов в публичный `master`. Проверить без
   авторизации обе ссылки:
   - https://github.com/panandafog/Glintwake/blob/master/AppStore/privacy-policy.md
   - https://github.com/panandafog/Glintwake/blob/master/AppStore/support.md
   Пока файлы не опубликованы, эти адреса нельзя считать рабочими URL для ревью.
2. Создать/проверить карточку Glintwake с Bundle ID `com.panandafog.glintwake`.
   Доступность имени проверяется в ASC. Для iOS и Mac выбрать соответствующие сборки
   в одной карточке при желаемой universal purchase конфигурации.
3. Выбрать цену, страны, дату и ручной/автоматический выпуск. Заполнить контактный
   телефон App Review, возрастную анкету, App Privacy и export-compliance. Не выбирать
   Kids Category автоматически. Контактные имя/почта уже подготовлены в metadata.
4. Собрать **подписанный Release Archive** для generic iOS device и для Mac через
   Xcode Organizer; проверить Distribution signing, provisioning и sandbox.
   Затем Validate App / Upload. Проверка неподписанного `.app` не заменяет этот шаг.
   Для повторной загрузки в ASC каждый раз использовать новый номер build.
5. Выполнить короткую проверку подписанной/TestFlight-сборки на физическом устройстве:
   свайпы и стрелки, победа/проигрыш/перезапуск, восстановление прогресса, звук,
   поворот iPhone/iPad, складывание/раскрытие Duo, Mac на минимальном размере,
   ссылки политики/поддержки. Duo в этой задаче проверялся на симуляторе.
6. Загрузить актуальные скриншоты и EN/RU тексты. Точный статус снимков —
   [screenshots/README.md](screenshots/README.md). Не использовать старые
   `Assets/Screenshots`: это исторические проверки интерфейса до текущих изменений.
7. Проверить все URL, выбранные сборки, анкету, описание и изображения в ASC Preview
   и только затем отправить на ревью. Никаких загрузок или отправок из этой задачи не выполнялось.

## Источники Apple

- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [Required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [TN3183: privacy manifest](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/):
  1.5 — поддержка, 2.1 — полнота/URL, 2.3 — реальные скриншоты и метаданные,
  2.4.5 — Mac sandbox, 5.1.1 — политика в приложении и ASC.

Перечень требований может меняться; перед фактической отправкой сверить текущую ASC-форму.
Duo-снимки уже подготовлены для обоих дисплеев. На ранее проверенной странице Apple
дата требования — апрель 2027 для SDK iOS 27.1+. Перед отправкой сверить актуальные слоты ASC.
