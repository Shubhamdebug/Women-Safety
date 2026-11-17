# Real-device acceptance checklist

Status: NOT RUN. Use consenting test recipients, not emergency services. Record sanitized evidence; exclude phone numbers, tokens and exact coordinates from committed logs.

Record: date, tester, build/commit, phone model, Android version, battery mode, SIM capability, backend version, observed result and evidence reference. Mark PASS / FAIL / BLOCKED per case.

| Case | Procedure | Expected result | Result |
|---|---|---|---|
| GPS allowed | Grant location; confirm test SOS | Location timestamp/accuracy stored | NOT RUN |
| GPS denied | Deny; confirm | Nullable location with reason; SOS persists | NOT RUN |
| Permanently denied | Deny permanently; retry | Settings guidance; no crash or loop | NOT RUN |
| GPS off / timeout | Disable GPS or force timeout | Fresh cache clearly marked or unavailable; event retained | NOT RUN |
| Approximate only | Grant approximate location | Accept lower precision and report accuracy honestly | NOT RUN |
| Online | Confirm with working test API | Persist before send; matching acknowledgment | NOT RUN |
| Offline restart | Disconnect; confirm; kill and reopen | Same event ID and state still present | NOT RUN |
| Reconnect | Restore network after previous case | Same ID; one server incident | NOT RUN |
| Lost acknowledgment | Server accepts then response lost | Same-ID retry; no second incident | NOT RUN |
| Concurrent sync | Trigger reconnect and manual retry together | One claimed item; no duplicate effects | NOT RUN |
| Server failure | Return timeout/500/401/invalid ack | Retained event; appropriate retry/action; no false success | NOT RUN |
| Storage failure | Simulate full/unwritable database | Explicit persistence failure; no false queued state | NOT RUN |
| Shake | Shake repeatedly; then cancel; then confirm | One active confirmation; cancel sends nothing | NOT RUN |
| Tracking | Start visibly; screen off/background; stop | Notification; cached samples; stop ends collection | NOT RUN |
| Revoke permission | Revoke during tracking | Safe stop/degradation; useful error | NOT RUN |
| Battery saver | Repeat tracking with saver enabled | Observe/document actual gaps and limits | NOT RUN |
| Force-stop/reboot | Queue event then force-stop/reboot; reopen | Queue retained; no promise of automatic process restart | NOT RUN |
| SMS composer | Offline; open then cancel composer | User action required/unknown; never delivered | NOT RUN |
| No SMS handler/SIM | Attempt fallback on unsupported device | Explicit capability/failure; queue retained | NOT RUN |
| Account switch | Queue under account A then sign in B | Never send A's event under B | NOT RUN |
| Battery pre-alert | Cross threshold repeatedly; recharge/re-cross | If implemented: distinct pre-alert, one per episode | NOT RUN |

Core completion requires automated tests, analysis, a successful Android build, phone results, and real backend deduplication evidence. Mock acceptance alone is insufficient.
