17/17

=== V9.2 audit (docs/confirmation.md) — ALL CODE FINDINGS RESOLVED ===

✓ SEC-1  users/{uid} catch-all removed; owner-writable subcollections enumerated
✓ SEC-2  every subcollection's writer decided explicitly (server-only where CF-owned)
✓ BUG-2 / BUG-10  single engagement writer (server owns summary; client only streams)
✓ resumeReviews tamper  server-only write via persistResumeReview; owner rules false
✓ BUG-1  retention filters ai_interactions by `timestamp` (+ COLLECTION_GROUP index)
✓ BUG-3 / BUG-4 / BUG-6  placements: snapshot gated on exists(), timeouts, full mirror
✓ INT-1  storage.rules covers resumes/{uid}/snapshots/{fileName}; write:false
✓ BUG-5  teacher analytics metrics sourced from TeacherAnalyticsProvider
✓ PERF-1 teacher analytics engagement_summary reads batched via chunked getAll()
✓ BUG-7  deepAnalysis.js: request.data || {}
✓ BUG-8  LoadDedupe.begin: .catchError on the whenComplete future
✓ BUG-9  main.dart: profile-sync is an identity check (_lastSyncedProfile)
✓ BUG-11 engine suppresses ALL role cards once a career interest is declared (+ test)
✓ Chat delete  messages update/delete bound to resource.data.senderId == auth.uid
✓ TEST-1  four node --test suites added (fakes extended: increment/auto-id/subcollections)
✓ Verify  flutter analyze clean; flutter test 422 pass; node --check all pass; node --test 38 pass
✓ Docs  docs/todo.md updated (findings, validation, test counts)

Test suites (node --test, functions/ → 38 pass):
  placement_transitions.test.js        9  SEC-3 status state machine
  retention_snapshot_contract.test.js  6  BUG-1 reader==writer field + index; BUG-3 exists() gate
  engagement_activity.test.js          7  dayKey/previousDayKey + logUserActivity aggregate
  recommendations_engine.test.js       3  BUG-11 declared-role suppression
  quota.test.js                       11  unified-quota reserve/refund
  schedulers.test.js                   2  consolidated sweep envelope

Harness changes for TEST-1 (functions/test/):
  firestore_fake.js — FieldValue.increment sentinel, auto-id for `.doc()`,
                      nested `.collection()` on a doc ref, merge-on-missing-doc
                      applies transforms against 0; collection().get()
  setup.js          — fake FieldValue.increment wired to the sentinel

Left for the user (not code changes):
  • firebase deploy --only functions  (creates compensateStaleAIQuotas, drops the 3 orphans)
  • App Check ENFORCEMENT toggle in the Firebase console
  • Runtime logout→login→re-login check (no WatchStream NOT_FOUND) — §5
