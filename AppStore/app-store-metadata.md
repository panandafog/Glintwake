# Glintwake — App Store metadata

## Общие поля

| Поле | Значение |
| --- | --- |
| Name | Glintwake — доступность имени проверить при создании карточки |
| Version / Build | 0.1.0 / 4 — текущие значения исходников |
| Bundle ID | `com.panandafog.glintwake`, один app target для iOS/iPadOS и native macOS |
| Primary language | English (U.S.) |
| Category | Games → Puzzle; дополнительную категорию можно не указывать |
| Copyright | 2026 Andrei Pantiukhin |
| Support URL | https://github.com/panandafog/Glintwake/blob/master/AppStore/support.md |
| Privacy Policy URL | https://github.com/panandafog/Glintwake/blob/master/AppStore/privacy-policy.md |
| Marketing URL | Необязательно; можно оставить пустым |
| App Privacy | Data Not Collected — для текущей реализации без аналитики и сторонних SDK |
| Export compliance | Нет собственной криптографии; `ITSAppUsesNonExemptEncryption = NO` |
| Sign-in required | No |
| App Review contact | Andrei Pantiukhin, panandafog@icloud.com |
| App Review phone | Заполнить действующий телефон в ASC |
| Price / Availability | Выбрать цену, страны и дату выпуска в ASC |
| Age rating | Проверить актуальную анкету: полный набор ответов текущей игры находится в `AppStore/release.json` и заполняется workflow. Нет UGC, общения, ставок, рекламы, сцен насилия или встроенного браузера; абстрактные ловушки. Итоговый рейтинг рассчитывает Apple; Kids Category автоматически не выбирается |

Ссылки заработают после push файлов в публичный `master` репозитория. Перед
отправкой проверить их без авторизации. Это ещё не выполненная публикация страниц.

В первой версии поле What's New не требуется. Не использовать слова beta/demo/MVP
в публичном описании. Скриншоты отражают текущую игру; сцены захвата не входят в Release.

## en-US

### Name

```text
Glintwake
```

### Subtitle

```text
Slide. Collect. Find your way.
```

### Promotional Text

```text
Every move matters. Collect every crystal, plan the order, and reach the exit in the fewest moves. Three difficulties, generated puzzles and a calm soundtrack.
```

### Description

```text
Find a route worth thinking through.

In Glintwake, one move sends you sliding until a wall or a stop ring catches you. Collect every crystal and reach the exit in the minimum number of moves. The nearest crystal is not always the best place to start.

PLAN YOUR ROUTE
Move in eight directions. Read the obstacles, choose the order of collection and make each stop count. Red hazards end an attempt, and running out of moves means it is time to rethink your path.

A NEW PUZZLE AFTER EVERY WIN
Choose Easy, Medium or Hard. Puzzles are generated on your device and checked for solvability. Each difficulty keeps its own solved count. Your current board and moves are saved so you can continue later.

ROOM TO THINK
Undo a move, restart the same board or ask for a hint. There is no timer and no limited supply of lives. Soft sound effects and a quiet background composition can be switched off independently.

Play offline on iPhone, iPad and natively on Mac. Swipe or use the direction buttons; on Mac, keyboard controls are also available. English and Russian are included.

No account, advertising, tracking or in-app purchases. Progress stays on your device; it does not sync between devices.
```

### Keywords

```text
sliding,puzzle,logic,crystal,route,path,brain,offline,relax,challenge,grid,maze
```

### App Review Notes

```text
Glintwake is an offline, single-player sliding puzzle. No account, login, server, subscription or purchase is required.

Collect all crystals and reach the exit within the minimum move count displayed above the board. Swipe in eight directions or use the direction buttons. A hazard or an exhausted move budget ends the attempt; Restart resets the same board, while Undo cancels one move.

The difficulty button at the top opens Easy / Medium / Hard, solved counts, and Another puzzle. A win adds to that difficulty's count once; Next level opens a new generated puzzle. Hint shows an optimal next step when a finish within the remaining budget is possible. On Mac, use Q W E / A D / Z X C or arrow keys.

Privacy and support are accessible from How to play. Progress and sound preferences stay locally on the device. There is no cloud sync or developer-operated backend.

The App Store screenshots use representative states of the real interface. Capture fixtures are development-only and absent from Release builds.
```

## ru-RU

### Name

```text
Glintwake
```

### Subtitle

```text
Скользи, собирай, продумывай
```

### Promotional Text

```text
Каждый ход имеет значение. Собери кристаллы и доберись до выхода за минимум ходов. Три сложности, новые поля и спокойная музыка — без таймера.
```

### Description

```text
Найди маршрут, который стоит продумать.

В Glintwake один ход отправляет тебя скользить до стены или кольца остановки. Собери все кристаллы и доберись до выхода за минимальное число ходов. Ближайший кристалл не всегда стоит брать первым.

ПРОДУМАЙ ПУТЬ
Двигайся в восьми направлениях. Учитывай препятствия, выбирай порядок сбора и используй остановки. Красные ловушки завершают попытку, а когда ходы заканчиваются, пора пересмотреть маршрут.

НОВОЕ ПОЛЕ ПОСЛЕ ПОБЕДЫ
Выбирай лёгкую, среднюю или сложную игру. Поля создаются на устройстве и проверяются на проходимость. У каждой сложности свой счётчик побед. Текущее поле и ходы сохраняются, чтобы можно было продолжить позже.

ЕСТЬ ВРЕМЯ ПОДУМАТЬ
Отмени ход, начни то же поле заново или воспользуйся подсказкой. Таймера и ограниченного запаса жизней нет. Мягкие звуковые эффекты и спокойную фоновую музыку можно отключать отдельно.

Играй офлайн на iPhone, iPad и нативно на Mac. Управляй свайпами или стрелками на экране, а на Mac — ещё и клавиатурой. Доступны русский и английский языки.

Без аккаунтов, рекламы, отслеживания и встроенных покупок. Прогресс хранится на устройстве и не синхронизируется между устройствами.
```

### Keywords

```text
головоломка,логика,кристаллы,маршрут,скольжение,офлайн,поле,задачи,планирование
```

### App Review Notes

```text
Для App Review использовать английский блок выше.
```
