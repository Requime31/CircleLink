# CircleLink Cloud Functions — inactive reference

> **Do not deploy.** CircleLink uses the Firebase **Spark** plan (no Blaze).
> Push delivery lives in `websocket-server` (Firestore listeners → FCM).
> See [`../websocket-server/README.md`](../websocket-server/README.md).

This folder is a leftover reference for a Blaze + Cloud Functions approach.
The current path does **not** use these triggers. `websocket-server/` also owns the scheduled
account-cleanup CLI; changing this requires an explicit backend/billing decision.
