# CircleLink integration prompt archive

> Historical record. The numbered prompts have been implemented or superseded in the
> current `ui-redisign` working tree. Do not treat this folder as the active roadmap or
> replay prompts blindly. Current LLM memory lives in `docs/ai/`.

Каждый numbered Markdown-файл изначально описывал самостоятельную задачу и остаётся для
аудита intent/acceptance criteria.

## Порядок

- Последовательно: `01 → 02`, `03 → 04`, `06 → 07 → 08`, `09 → 10 → 11`, `12 → 13`, `15 → 16 → 17`.
- `19` — после `01`, `05`, `07`, `11`; `20` и `21` — после `19`.
- Дополнительные багфиксы: `27` — community media grid, `28` — navigation loop, `29` — длинные community name/description.
- `27` и `28` независимы. `29` заменяет/расширяет `25`, если тот ещё не реализован; если `25` уже слит, `29` сохраняет его поведение и проводит более широкий audit.
- Остальные UI PR независимы после проверки их prerequisites.
- Несмотря на номер, `26` запускается последним — после всех выбранных PR, включая `27–29`, — и аудирует только фактически реализованные изменения.

## Уже покрытые найденные баги

- Mute поднимает чат: `17-chat-ordering-and-mute-fix.md`.
- Закрепление чатов: `15-chat-pinning-data.md` → `16-chat-pinning-ui.md`.
- Растягивание avatar и слишком заметный Hidden Chats row: `18-chat-list-visual-fixes.md`.
- Community media grid: `27-community-media-grid-fix.md`.
- All Communities navigation loop: `28-all-communities-navigation-loop-fix.md`.
- Длинные community name/description: `29-community-long-content-ui-audit.md`.

Каждый агент обязан исследовать актуальную ветку, остановиться при отсутствии указанного prerequisite, сохранить чужие незакоммиченные изменения и не выполнять commit/push/deploy без отдельного разрешения.
