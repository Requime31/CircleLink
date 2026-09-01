# PR 27 — Community media grid fix

## Role and objective

Ты senior SwiftUI engineer. Создай ветку `codex/community-media-grid-fix` и подготовь один узкий reviewable PR: восстанови корректный media grid в Community → Media, используя рабочий Chats Shared Media grid как эталон поведения и геометрии. Не коммить, не пушь и не открывай PR без отдельной команды пользователя.

## Repository context and required reading

Перед изменениями проверь `git status` и не перезаписывай чужие незакоммиченные правки. Полностью прочитай `docs/ai/AGENTS.md`, `docs/ai/PROJECT.md`, `docs/ai/DECISIONS.md`, `docs/ai/DESIGN_SYSTEM.md`, `ARCHITECTURE.md` и `DESIGN.md`. Затем исследуй `CommunityDetailView`, `CommunityDetailViewModel`, `CommunityPost`, `CommunityPostImage`, `ChatMediaGalleryView` и общий image loading/full-screen viewer. Проект: iOS 16+, SwiftUI + UIKit chat, MVVM + Repository, manual DI, без UseCase-слоя.

## Current state

Community Media сейчас строится как двухколоночный `LazyVGrid` поверх уже загруженной страницы постов и применяет к thumbnail `aspectRatio(..., .fit)`, из-за чего grid/ячейки могут получать нестабильную геометрию. Chats media использует квадратные clipped thumbnails, стабильные spacing/insets и full-screen просмотр. Сначала воспроизведи и зафиксируй точную причину; не копируй Chat repository logic в Communities.

## Implementation requirements

- Сделай community thumbnails строго квадратными: flexible columns с согласованным spacing, `scaledToFill`, фиксируемая через layout ширина, clipping continuous radius и hairline overlay.
- Используй `CLSpacing.screenHorizontal`; крайние ячейки и межколоночные интервалы не должны конфликтовать с родительскими padding.
- Тап открывает существующий либо минимально переиспользованный full-screen media viewer с `scaledToFit` и Close; не создавай второй визуально отличный viewer без причины.
- Обработай loading/failure placeholder без изменения размера ячейки и layout jumping.
- Сохрани фильтрацию постов без `imageURL`, порядок постов, empty/error states и текущую pagination semantics. Если Media показывает только первую страницу из-за реального отсутствия pagination, зафиксируй это как отдельный риск — не расширяй PR без необходимости для исправления grid.
- Не меняй Firestore/Supabase, post repository contracts, compose/edit post UI или Chats media.

## UI and accessibility

Следуй Sunset Parchment, light/dark tokens, Dynamic Type и Reduce Motion. Каждая ячейка — доступная Button с label вроде “Photo by <author>, <relative date>”; декоративный placeholder не должен озвучиваться дважды. Проверь portrait/landscape images, очень узкие экраны и rotation.

## Tests and verification

Добавь unit tests только для вынесенной pure layout/presentation logic; не подключай новый snapshot framework. Собери приложение, запусти релевантные tests и `git diff --check`. Вручную проверь 1, 2, 3, 10+ изображений, mixed aspect ratios, slow/failing image load, light/dark, Dynamic Type, full-screen open/dismiss.

## Definition of Done and final response

Grid имеет стабильные квадратные ячейки без overlap, collapse, растягивания и лишних inset; full-screen viewer работает; Chats media не регрессировал. В финале укажи root cause, изменённые файлы, проверки и оставшиеся data/pagination ограничения. Не заявляй о тестах, которые не запускались.
