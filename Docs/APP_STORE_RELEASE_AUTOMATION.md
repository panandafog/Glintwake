# Подготовка релиза Glintwake в App Store Connect

Реализация и проверка документации API: **2026-11-13**. Конечная точка workflow —
подтверждённые Apple `READY_FOR_REVIEW` у версии, review item и Draft Review
Submission с конкретным обработанным build. **Workflow не отправляет на ревью и
не публикует приложение.** Реальная доставка/подпись с credentials ещё не проверена.

## Что обнаружено при аудите

- Один app target и scheme `Glintwake`, native iOS/iPadOS 17+ и macOS 14+;
  Mac Catalyst выключен. `Glintwake Screenshots` — только Debug-съёмка.
- Источник проекта — `project.yml`; сгенерированный `Glintwake.xcodeproj` уже в Git.
  Version/build читаются из settings этого источника с учётом target overrides.
  На момент реализации: `0.1.0 (4)`, Bundle ID `com.panandafog.glintwake`,
  team `3HG9ZBM8AV`. Приложение не имеет внешних runtime/SPM-зависимостей.
- GitHub Actions, fastlane, экспортных plist, автоматического архива/подписи и
  имен CI signing secrets в исходном Glintwake не было. Существующие локальные
  настройки Automatic signing оставлены без изменений. Релизный workflow
  переопределяет signing только на время CI-команды.
- Сохранены `Scripts/verify-release.py`, EN/RU
  `AppStore/app-store-metadata.md`, privacy/support страницы и 40 проверенных PNG.
- Подключённый GitHub вернул 404 для `panandafog/Glintwake`: серверные настройки,
  доступность репозитория, наличие Secrets и реальную карточку Apple подтвердить
  не удалось. Это ограничение доступа, а не доказательство отсутствия репозитория.
  Значения существующих секретов не запрашивались и не читались.

## Как устроено

| Файл | Назначение |
| --- | --- |
| `.github/workflows/app-store-release.yml` | Только `workflow_dispatch`; этапы подготовки, подпись, загрузка, ожидание Apple, metadata, review, draft, read-back и Job Summary |
| `.github/workflows/release-checks.yml` | Offline-тесты на push/PR; Apple credentials не используются, ничего не загружается |
| `Gemfile`, `Gemfile.lock`, `fastlane/Fastfile` | Зафиксированный fastlane 2.241.2; единственная lane `upload_binary`, только Transporter для `.ipa`/`.pkg` |
| `AppStore/release.json` | Технические настройки API, таймауты, категории/известные ответы age rating, соответствие папок снимков API-слотам |
| `Scripts/release/metadata.py` | Читает существующие тексты Markdown, version/build из проекта, проверяет длины и матрицу PNG |
| `Scripts/release/asc.py` | JWT/Apple REST API, retries/pagination, безопасные версии/build, metadata, assets, App Review и draft |
| `Scripts/release/signing.py` | Временная keychain, ручная App Store подпись/профили, archive/export, проверка bundle, SHA-256 артефактов и cleanup |
| `Scripts/release/artifact_source.py` | Проверка происхождения сохранённого бинарника: только завершённый ручной релиз с default branch этого репозитория |
| `Scripts/release/cli.py` | Независимые повторяемые этапы, отчёт без контактов/ключей и финальная проверка фактического состояния Apple |
| `Tests/ReleaseAutomation` | Fake API и offline-тесты ошибок, состояний, повторов, подписи и запрета submit/publish |

Fastlane выбран для поддерживаемой доставки бинарников через Apple Transporter.
Версии, metadata и новые review submissions управляются непосредственно Apple REST
API: так черновик не зависит от поведения `deliver submit_for_review`. Переносить
существующие тексты в дублирующую папку `fastlane/metadata` не нужно.

Никакая команда не вызывает `PATCH reviewSubmissions` с `submitted=true`,
`POST appStoreVersionSubmissions`, release requests или phased release. HTTP-клиент
ограничивает разрешённые мутации и отвергает операции submit/publish до сетевого
вызова. Новая версия создаётся с `releaseType=MANUAL`; существующие настройки
выпуска не меняются. Автоматическое опубликование после одобрения не включается.

## A. Первоначальная настройка — один раз

### 1. Доступность исходников и публичных страниц

В GitHub опубликовать изменения в **default branch** репозитория. Релизный
workflow намеренно не запускает привилегированные этапы из других веток.
Для неосновных веток остаются offline-проверки.

Открыть в приватном окне без входа в GitHub:

- [Поддержка](https://github.com/panandafog/Glintwake/blob/master/AppStore/support.md)
- [Конфиденциальность](https://github.com/panandafog/Glintwake/blob/master/AppStore/privacy-policy.md)

Обе страницы должны отвечать 200 и содержать текст. Если репозиторий приватный или
ветка называется иначе, опубликовать страницы по публичным HTTPS-адресам, обновить
URL в существующей таблице `AppStore/app-store-metadata.md` и ссылки в приложении.
Workflow проверяет доступность этих URL без авторизации. Повторять при смене URL.

### 2. Карточка приложения и платформы в Apple

В [App Store Connect → Apps](https://appstoreconnect.apple.com/apps) создать либо
проверить карточку Glintwake с точным Bundle ID `com.panandafog.glintwake`, primary
locale English (U.S.), платформами iOS и macOS для universal purchase. Проверить
доступность имени. API этого workflow **не создаёт App record**; версии внутри
существующей карточки создаёт автоматически.

Если карточка уже существует, не создавать вторую. Убедиться, что team из
`project.yml` совпадает с выбранной командой Apple Developer.

### 3. API Key без интерактивного Apple Account/2FA в CI

Account Holder/Admin открывает
[Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api),
при необходимости активирует доступ к API и создаёт **Team API Key** с ролью
**App Manager**. Developer недостаточен для подготовки submission. Admin/Account
Holder в CI не требуется; сертификаты предоставляются отдельно.

Сохранить Key ID, Issuer ID и единожды скачанный `.p8` в собственном менеджере
секретов. Team key наследует область команды: ограничения именно на Glintwake
дополнительно обеспечиваются поиском и строгой проверкой Bundle ID в клиенте.
Не считать Team key ключом с доступом исключительно к одному приложению.

Проверка: после создания Secrets запустить `status` для нужной платформы. Возможны
404 (карточка/платформа ещё не создана), 401 (ключ/issuer), 403 (роль/доступ), либо
`WAITING_FOR_APPLE` при отсутствии build. Это диагностический read-only запуск.
2FA при выпуске не нужна. Ротация ключа — по политике владельца и при компрометации.

### 4. GitHub Environment и Secrets

В Settings репозитория → Environments создать **`app-store`**, разрешить запуск
только из default branch. Если включить required reviewers, появится дополнительное
ручное подтверждение запуска; для желаемого процесса без него эту настройку не
включать. Это решение принимает владелец. Затем добавить environment Secrets
(либо существующие repository Secrets с теми же именами):

| Secret | Содержимое | Когда нужен |
| --- | --- | --- |
| `ASC_KEY_ID` | Key ID Apple | Все режимы |
| `ASC_ISSUER_ID` | Issuer ID команды | Все режимы |
| `ASC_PRIVATE_KEY_P8_BASE64` | Оригинальный `.p8`, закодированный в base64 одной строкой | Все режимы |
| `ASC_REVIEW_CONTACT_PHONE` | Реальный телефон для App Review, с кодом страны | Первый `full`/`review`; далее можно сохранить значение в Secret или использовать уже заполненное в ASC |
| `IOS_DISTRIBUTION_P12_BASE64` | `.p12` с Apple Distribution/iPhone Distribution сертификатом **и private key** | Новая iOS-сборка |
| `IOS_DISTRIBUTION_P12_PASSWORD` | Пароль этого `.p12` | Новая iOS-сборка |
| `IOS_PROVISION_PROFILE_BASE64` | Профиль App Store Connect distribution для точного iOS Bundle ID | Новая iOS-сборка |
| `MAC_APP_DISTRIBUTION_P12_BASE64` | `.p12` с Mac App Store application identity и private key | Новая Mac-сборка |
| `MAC_APP_DISTRIBUTION_P12_PASSWORD` | Пароль app `.p12` | Новая Mac-сборка |
| `MAC_INSTALLER_P12_BASE64` | `.p12` с **3rd Party Mac Developer Installer** и private key | Новая Mac-сборка |
| `MAC_INSTALLER_P12_PASSWORD` | Пароль installer `.p12` | Новая Mac-сборка |
| `MAC_PROVISION_PROFILE_BASE64` | Mac App Store distribution profile для точного Bundle ID | Новая Mac-сборка |

Имена и email для App Review уже берутся из существующей таблицы Markdown,
английские review notes — из существующего блока EN. Аккаунт для игры не требуется,
`demoAccountRequired=false`; фиктивные login/password не создаются.

**Ключи, `.p12`, пароли и телефон не отправлять в чат и не коммитить.** Для base64
на Mac можно скопировать значение прямо в буфер, не выводя его в терминал:

```sh
base64 -i /absolute/path/to/AuthKey.p8 | tr -d '\n' | pbcopy
```

Аналогично для `.p12` и профиля. Вставить результат в соответствующий GitHub Secret.
Пароль `.p12` — обычная строка, без base64. Если сертификат без пароля, переэкспортировать
его с непустым паролем. Сертификаты/профили готовятся в
[Apple Developer → Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list)
и Keychain Access. Нужен доступ владельца к private key; один `.cer` не подходит.

Не использовать Developer ID Application/Installer, development, Ad Hoc или
enterprise профили. CI проверяет срок, платформу, team, exact application identifier,
отсутствие debug/provisioned devices и совпадение сертификата с профилем.
На каждую новую сборку создаётся отдельная временная keychain; после работы её,
профиль и `.p8` удаляют. Пароль keychain случайный и не сохраняется в артефактах.
Обновлять Secrets при истечении/отзыве/ротации сертификатов и профилей.

### 5. Настройки, которые подтверждает владелец

В карточке ASC один раз проверить:

| Настройка | Что сделать и как проверить | Повторение |
| --- | --- | --- |
| App Privacy | Для текущей игры без аналитики/SDK опубликовать правдивую декларацию Data Not Collected. Privacy manifest в `.app` не публикует эту анкету за владельца | При изменении поведения/SDK |
| Age Rating | Проверить ответы, соответствующие текущему контенту. Workflow отправляет полный набор из 23 обязательных ответов из `AppStore/release.json`; рейтинг рассчитывает Apple. Kids Category и возрастной override автоматически не выбираются | При изменении контента/анкеты Apple |
| Content Rights | Подтвердить права на приложение/контент; тексты, графика и звук описаны в репозитории | При изменении прав/контента |
| Pricing and Availability | Выбрать цену и страны. Workflow не устанавливает цену и не меняет страны | При коммерческих изменениях |
| DSA / trader | Указать действительный статус и пройти требуемую проверку в Business/Agreements | При изменении статуса/запросе Apple |
| Agreements / Tax / Banking | Account Holder принимает актуальные договоры и заполняет применимые сведения | При новых договорах/запросе Apple |
| Export Compliance | `ITSAppUsesNonExemptEncryption=NO` уже в проекте и проверяется в архиве. Если Apple всё же требует отдельный ответ/документ, заполнить его в ASC. Не менять декларацию вслепую для чужого build | При криптографических изменениях/запросе Apple |
| Release policy | Для новых версий workflow выбирает ручной выпуск; существующая политика сохраняется. После одобрения ручной выпуск потребует Release This Version — это отдельный этап после цели Ready for Review | При выборе иной политики владельцем |

API не предоставляет полного достоверного read-back всех юридических/аккаунтных
настроек. Не делается ложного вывода, что они заполнены. При добавлении версии в
draft Apple может вернуть ошибки/указатели недостающих полей; Job Summary не
покажет готовность без фактических ready-состояний. Надёжно формируются ссылки
`https://appstoreconnect.apple.com/apps/<APP_ID>` и
`https://appstoreconnect.apple.com/apps/<APP_ID>/appreview`; неточные deep links к
отдельным юридическим формам не угадываются.

### 6. Runner / Xcode / права GitHub

По умолчанию — GitHub-hosted `macos-26`, Python 3.12, Ruby 3.4.7; используется
уже включённый Xcode. При необходимости в Repository Variables установить:

- `RELEASE_MACOS_RUNNER`: доступный label вашего Mac runner.
- `RELEASE_XCODE_APP`: полный путь, например `/Applications/Xcode_27.2.app`, **только
  если такой Xcode действительно установлен на runner**. Проверяется шагом Xcode.

Приложение требует Swift 6, SDK iOS 17+/macOS 14+. Доступность SDK, сертификаты и
профили нужно подтвердить первым реальным прогоном. Workflow не устанавливает
нелицензированные SDK и не принимает Apple agreements за владельца.
Для self-hosted требуется отдельный изолированный одноразовый Mac runner: cleanup
не заменяет изоляцию от других процессов/задач. На обычном личном Mac CI не запускать.

`GITHUB_TOKEN` получает только `contents:read` и `actions:read` (для восстановления
артефакта). Доступ на запись в GitHub не нужен. Конкурентные релизы приложения
сериализованы, в том числе iOS/macOS из-за общей App Information. Environment
права и возможность Actions должны быть включены в настройках репозитория.

Если первая платформа уже добавлена в draft и общая App Information стала
read-only, вторая платформа переиспользует её только при полном совпадении
локализаций, категорий и известных age flags. Эти общие данные не переписываются.

## B. Каждый новый релиз

1. В `project.yml` обновить `MARKETING_VERSION` и `CURRENT_PROJECT_VERSION` в base
   и target override, где они заданы; выполнить `xcodegen generate`, сохранить
   проект в Git. Либо дать workflow явный новый `build_number` для новой попытки
   загрузки без изменения marketing version. **Для повторов уже принятого build
   номер не увеличивать**. Новую бинарную версию под использованным номером Apple
   не принимает.
2. Проверить существующий `AppStore/app-store-metadata.md`. Для обновления добавить
   только What's New: `AppStore/release-notes/<VERSION>/en-US.txt` и `ru-RU.txt`.
   Для первого релиза What's New не требуется. Остальные тексты не дублировать.
   Если публичный контент/механика изменились, явно переснять PNG по `Docs/FramePilot.md`.
   CI использует готовые проверенные кадры, не запускает GUI-съёмку на runner.
3. Закоммитить/push в default branch. Открыть GitHub → Actions →
   **Prepare App Store Release → Run workflow**. Выбрать `platform=both` (либо
   `ios`/`macos`), `mode=full`, оставить build override пустым для project.yml.
4. Дождаться обоих platform jobs. В каждом Summary проверить bundle/version/build,
   подпись, загрузку, processing, metadata, screenshots, review и draft. При ошибке
   действовать по таблице повторов ниже; не пересобирать без необходимости.
5. Открыть App Review по ссылке в Summary. **Только если Apple подтвердила
   READY_FOR_REVIEW**, проверить содержимое черновика и самому нажать
   **Submit for Review**. При двух платформах готовятся отдельные platform drafts;
   финальное подтверждение может потребоваться для каждого.

При установленном GitHub CLI тот же явный запуск выглядит так:

```sh
gh workflow run app-store-release.yml --repo panandafog/Glintwake \
  -f platform=both -f mode=full
```

Эта команда **реально запускает доставку в Apple** после настройки Secrets;
в ходе реализации она не выполнялась. Дать Codex отдельное разрешение, когда
нужно запустить такую доставку за владельца.

### Повторы без пересборки

| Режим | Что делает | Что указать |
| --- | --- | --- |
| `full` | Проверяет Apple → при отсутствии build/receipt собирает и сохраняет подписанный пакет → upload → wait → metadata/screenshots → review → draft → read-back | platform; тот же build для ретрая |
| `upload` | Берёт сохранённый подписанный пакет из предыдущего release run, проверяет происхождение/identity/SHA-256, выполняет этапы от upload до draft | `artifact_run_id` и прежний platform/build; исходный run должен завершиться |
| `metadata` | Только тексты, категории, известные age ответы и screenshots; без сборки/доставки бинарника | platform/build; версия должна оставаться редактируемой; затем `review` |
| `review` | Wait → конкретный build → App Review Information → draft → read-back; без сборки и изменения metadata | platform/build |
| `status` | Только чтение: точный build, processing, metadata/assets, выбранный build, версия, draft/item | platform/build |

Подписанный артефакт сохраняется **до загрузки Apple** на 14 дней с именем
`app-store-<ios|macos>-<RUN_ID>`. Внутри — `.ipa`/`.pkg` и `artifact.json` с
identity и SHA-256. Новый запуск не должен подменять build другим бинарником.
Восстановление разрешено лишь из завершённого `workflow_dispatch` этого release
workflow на default branch того же репозитория; артефакты PR/форков не принимаются.
Не выбирать чужой/другой run. После истечения retention потребуется новый полный
прогон либо восстановление пакета из собственного безопасного хранилища.

API проверяет и `/builds`, и `/apps/<id>/buildUploads`: квитанция Apple предотвращает
повторный upload, пока обычный build ещё не появился. FAILED/INVALID/expired build
или failed/incomplete receipt не удаляются автоматически. В таких случаях inspect
diagnostics Apple; для исправленной бинарной сборки обычно нужен новый build number.
Processing ждёт до 30 минут, polling каждые 20 секунд. Таймаут —
`WAITING_FOR_APPLE`, а не утверждение, что бинарник испорчен. Повторить `status`,
потом нужный этап. Таймаут обработки asset — 10 минут; повторить `metadata`.
GET/PATCH/DELETE повторяются ограниченно при 429/5xx/network errors; неоднозначные
POST не повторяются вслепую. Следующий запуск сначала заново ищет ресурсы Apple.

Если версия уже READY_FOR_REVIEW, `full` не разбирает draft и не меняет её:
проверяет соответствие локальным metadata и нужному build. Для изменения такой
версии владелец должен сначала вернуть её в редактируемое состояние в ASC.
Активные submission, live и прочие неподходящие версии workflow не отменяет,
не переписывает и не удаляет. Неизвестные изображения в screenshot set также
сохраняются: требуется одна начальная миграция/проверка владельца в ASC.

Исключение при первоначальной настройке: единственный пустой черновик `1.0` или
`1.0.0` в `PREPARE_FOR_SUBMISSION` может получить номер из проекта. Для этого
нужны уже обработанный (`VALID`) build точной целевой версии/платформы, отсутствие
выбранного build у черновика, остальных версий этой платформы, любых review
submissions, локализованных текстов/URL и media sets. Состояние проверяется ещё раз
непосредственно перед PATCH. Меняется только `versionString`; ID, данные и политика
выпуска сохраняются. Черновики с другим исходным номером, контентом, сборкой или
историей не перенумеровываются. `status` остаётся read-only и теперь перечисляет
фактические номера/состояния версий. В Summary добавлен `versionPreparation`.

### Что автоматизировано и что остаётся вручную

После первоначальной настройки: archive, App Store signing, `.ipa` либо Mac App
Store `.pkg`, transport, обработка Apple, версия, выбор точного build, EN/RU
описания/promotional text/keywords/support/privacy URLs/name/subtitle, release
notes обновлений, Games/Puzzle, известные age flags, обычные скриншоты, App Review
контакт/notes и Draft Review Submission выполняются автоматически.

Коды языков преобразуются на границе API: `en-US` → `en-US`, `ru-RU` → `ru`,
по [таблице Apple](https://developer.apple.com/documentation/appstoreconnectapi/managing-metadata-in-your-app-by-using-locale-shortcodes).
Папки PNG, разделы metadata и имена release notes остаются `en-US`/`ru-RU`.
Поиск существующих локализаций и проверка результата используют те же коды Apple,
поэтому повторный запуск использует уже созданную русскую локализацию, а её
скриншоты берёт из `ru-RU`. Неизвестный код требует явного добавления в mapping;
региональная часть не отбрасывается автоматически.

Возрастная анкета для текущего Glintwake содержит 23 явно заданных ответа:
`NONE` для частотных описателей контента и `false` для отсутствующих функций.
Основание — текущие SwiftUI-экраны и `BoardView`, локализации, состав ассетов и
оригинальные синтезированные звуки: абстрактное поле/символы без сцен насилия,
оружия, пугающего, медицинского, взрослого или иного описываемого анкетой контента;
нет ставок, призовых конкурсов, чата/UGC, рекламы, соцсетей, встроенного свободного
браузера, собственных parental controls или age assurance. Внешние ссылки на
поддержку/политику открываются системой. При добавлении контента ответы следует
пересмотреть по [определениям Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions).

Первый реальный прогон показал, что для незаполненной декларации Apple отвергает
частичный PATCH с семью boolean-ответами: нужны ещё 16 обязательных полей.
Теперь перед отправкой скрипт собирает полную декларацию из явной конфигурации и
существующих ответов ASC, сохраняя `false`. Отсутствующие/неверно типизированные
ответы вызывают понятную ошибку до PATCH; ответы не угадываются. После обновления
выполняется read-back. Возрастные overrides, Kids Category и иные неуказанные
поля остаются прежними; `4+` или другая итоговая категория не выставляется кодом.
В Summary добавлен отдельный статус `ageRating`.

Нет повторяющегося копирования полей или выбора build. Ручными остаются итоговое
Submit for Review, вопросы Apple/юридические подтверждения при их возникновении,
проверка реального устройства и выпуск после одобрения при manual release policy.
Игра не имеет App Previews — новые видео не генерируются и не загружаются.
Отсутствующие необязательные Marketing URL/What's New сохраняют существующие данные,
пустые строки из репозитория не стирают сведения ASC.

**Duo:** все 16 PNG сохранены и проверены, но официальный OpenAPI ZIP, скачанный
2026-11-13 (версия 4.6), не содержит Duo в `ScreenshotDisplayType`. Для этих двух
групп `displayType=null`, `optional=true`; workflow явно сообщает, что они не
загружены. Нельзя отправлять их в обычный iPhone slot или выдумывать enum. Когда
Apple опубликует/подтвердит поддерживаемые идентификаторы, их можно добавить в
`AppStore/release.json`, сверить размер и проверить реальной доставкой. До этого
загрузка Duo через интерфейс ASC остаётся отдельным действием, если эти кадры
нужны/обязательны на дату отправки. Это ограничение цели «всё без ручной загрузки».

## Локальные проверки и реальные release gates

Выполнено 2026-11-13 без Apple credentials:

- 66 offline-тестов, включая полный fake-API проход до draft, повторы, возрастную
  анкету по фактическому ответу Apple 409 и безопасную
  обработку первоначального пустого черновика, прошли.
- `actionlint 1.7.12` проверил оба workflow; Ruby syntax check прошёл.
- Установлен зафиксированный fastlane; lane обнаруживается, реальные определения
  deliver options проверены для iOS `.ipa` и Mac `.pkg` без transport action.
- 133 операции offline-сценария, включая mutation payloads, проверены валидатором
  JSON Schema по скачанному официальному OpenAPI 4.6; сеть Apple не вызывалась.
- `git diff --check` прошёл. Исходники игры и Xcode targets не изменялись.

```sh
python3 -m venv /private/tmp/glintwake-release-checks
/private/tmp/glintwake-release-checks/bin/pip install -r Scripts/release/requirements.txt
/private/tmp/glintwake-release-checks/bin/python -m unittest discover -s Tests/ReleaseAutomation -v
actionlint .github/workflows/app-store-release.yml .github/workflows/release-checks.yml
ruby -c fastlane/Fastfile
bundle install
bundle exec fastlane lanes
bundle exec ruby Scripts/release/check-fastlane.rb
```

Эти команды не загружают приложение, не меняют Apple metadata, не создают draft
и не читают личные Apple credentials. Тест JWT генерирует временный тестовый ключ.
API, пересылка assets и review states моделируются fake-сервером/transport.
Проверяются повторы, ошибки/timeout, неверный platform/build/profile, сохранение
пустых опциональных полей, отсутствие submit/publish, утечки секретов и матрица PNG.

Требуют **первого реального запуска с разрешения владельца**: сертификаты и
профили команды, подпись/export конкретным Xcode runner, проверка Transporter,
время обработки Apple, права API key, принятие PNG в слотах ASC, actual draft
validation и фактический `READY_FOR_REVIEW`. До этого end-to-end успех не заявлен.
Доступ к карточке, телефону и GitHub Secrets в реализации не предоставлялся;
реальная доставка, dispatch, push, review submission и publication не выполнялись.

## Проверенные официальные источники

- [Apple API overview и OpenAPI download](https://developer.apple.com/app-store-connect/api/)
- [Официальный OpenAPI ZIP](https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip)
- [Submit an app: Add for Review отдельно от Submit for Review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [Review submissions API](https://developer.apple.com/documentation/appstoreconnectapi/review-submissions)
- [Create Review Submission Item](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-reviewsubmissionitems)
- [Create a build upload / builds API](https://developer.apple.com/documentation/appstoreconnectapi/build-uploads)
- [Upload to App Store / ipa и pkg / skip_app_version_update](https://docs.fastlane.tools/actions/upload_to_app_store/)
- [App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [GitHub workflow run API](https://docs.github.com/en/rest/actions/workflow-runs#get-a-workflow-run)

Перед реальным выпуском сверить актуальные требования Apple и доступность runner.
