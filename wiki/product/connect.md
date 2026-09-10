---
title: Connect
type: product
status: current
updated: 2026-09-11
tags: [product, connect, onboarding]
---

# Connect

Connect presents one candidate in a stable swipe deck. A left swipe passes, a right swipe says
hi, and vertical movement reveals profile details. Incoming likes, outgoing likes, and matches
are secondary destinations. Report and block actions are available from peer contexts.

## First-use guidance

The contextual guide waits until a candidate image and target geometry are ready. The initial
“Meet someone new” message hands control to a feature-owned tutorial. The tutorial demonstrates
and then asks the user to practice pass and say-hi gestures without applying either action to the
real candidate. It completes only after the final ready action.

The guide manager suspends the introductory guide while the tutorial owns the experience. Layout
and blocker updates must not requeue it between tutorial phases. An abandoned tutorial releases
the suspension so it can be offered on the next visit.

## Profile images

Profile images fit within the existing stable card dimensions and keep their source aspect ratio.
Unused container space uses the shared soft surface color. This prevents geometric distortion and
avoids changing deck geometry or swipe behavior.

## Related decisions

- [Contextual guide system](../decisions/connect/contextual-guide-system.md)
- [Hybrid onboarding](../decisions/connect/hybrid-onboarding.md)
- [Profile image rendering](../decisions/connect/profile-image-rendering.md)

## Sources

- `CircleLink/Features/Connect/ConnectView.swift` — `ConnectView`.
- `CircleLink/Features/Connect/ConnectDiscoverDeckView.swift` — `ConnectDiscoverDeckView`.
- `CircleLink/Features/Connect/ConnectTutorialController.swift` — tutorial state machine.
- `CircleLink/Shared/Guides/ContextualGuideManager.swift` — guide lifecycle.
