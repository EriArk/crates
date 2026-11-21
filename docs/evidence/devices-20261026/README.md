# Crates на Odin и Flip — 26 октября 2026

По прямому разрешению владельца обновлены обе портативки:

| Игры | Установленная версия |
| --- | --- |
| Pocket Golf | 0.1.23 |
| Pocket Artillery | 0.1.4 |
| Pong, Snake Arena, Light Cycles, Falling Blocks, Minesweeper Race, Chain Reaction, Brick Racing, Brick Tanks | 0.1.3 |

Golf собран из `ced2e80`; аркады — из `5926385` ветки handheld repair.
Прежние ID `mini-racing` и `tanks` сохранены. Установка использует штатный
Crates Store: проверены размер/SHA-256, архитектура, атомарная активация,
сохранность всех существовавших файлов игровых данных, истории и других пакетов.
Прежние immutable objects сохранены для отката. Отчёты:
[Odin](odin-installation.json), [Flip](flip-installation.json).

На обеих устройствах установлен общий SDK с `network.group`, `play.scorecards`
и `account.identity`. SHA-256 оболочки:
`af4f0d8c27487ffefb5d90f9b25249b5b002217e4e46815ec081c8824812e26b`.
Сохранены актуальные изменения оболочки, Local Lobby и форматов из других чатов.
Исходники, бинарник и журнал наложения сохранены на существующем сервере;
резервные копии прежней оболочки/настроек/SQLite — на каждой портативке.

## Проверки

- ARM64 аркады: [43 passed](arcade-tests.txt); Artillery: [10 passed](artillery-tests.txt).
- Запущены все десять установленных пакетов штатным managed launcher под выбранным
  Trainer: [Odin](odin-launch-checks.json), [Flip](flip-launch-checks.json).
  Процессы оставались живыми; затем управляющий launcher получал SIGTERM и завершал
  дочернюю игру. Это проверка управляемого завершения, не нажатия игрового Exit.
- Просмотрены реальные кадры Racing, Tanks и Golf на каждом устройстве.
  [Odin Golf](odin-pocket-golf.png), [Flip Golf](flip-pocket-golf.png),
  [Odin Racing](odin-mini-racing.png), [Flip Racing](flip-mini-racing.png),
  [Odin Tanks](odin-tanks.png), [Flip Tanks](flip-tanks.png).
- Первый кадр Golf на Flip через 8 секунд ещё показывал Connecting. Отдельный
  [25-секундный запуск](flip-pocket-golf-followup.json) подтвердил Connected.
  Начальный кадр сохранён как `flip-pocket-golf-initial.png`.
- Оболочки оставлены работающими; игровые процессы проверки завершены.

## Недоделано

Эта доставка не закрывает физические контроллеры/прослушивание, длительный FPS,
полный путь Lobby Ready/Start/реванш и разные интернет-сети. 16 участников в
изолированном ARM64 SDK/TLS тесте не означают 16 портативок в реальном матче.
Каталог и GitHub не публиковались. Следующая игровая приёмка — обычный парный
путь через Lobby с управлением, реваншем и возвратом в оболочку.
