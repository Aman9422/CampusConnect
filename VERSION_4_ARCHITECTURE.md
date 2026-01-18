# VERSION 4: Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CAMPUSCONNECT V4                             │
│                    Backend-Safe AI Controls                          │
└─────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│                          FLUTTER APP (CLIENT)                          │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │
│  │   Chat Screen   │  │ Placements View  │  │  Profile Screen  │   │
│  └────────┬────────┘  └────────┬─────────┘  └────────┬─────────┘   │
│           │                    │                      │              │
│           ▼                    ▼                      ▼              │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │               SERVICE LAYER (Abstraction)                   │     │
│  ├────────────────────────────────────────────────────────────┤     │
│  │  AIService     │  PlacementsService  │  AuthService        │     │
│  │  ✓ sendMessage │  ✓ applyPlacement   │  ✓ currentUser      │     │
│  │  ✓ dispose     │  ✓ getApplications  │  ✓ logOut           │     │
│  └────────┬──────────────────┬──────────────────┬─────────────┘     │
│           │                  │                  │                    │
└───────────┼──────────────────┼──────────────────┼────────────────────┘
            │                  │                  │
            │ HTTP             │ Firestore        │ Firebase Auth
            │ POST             │ Read/Write       │
            ▼                  ▼                  ▼
┌───────────────────────────────────────────────────────────────────────┐
│                     FIREBASE BACKEND (SERVER)                          │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                   CLOUD FUNCTIONS (V4)                        │    │
│  ├──────────────────────────────────────────────────────────────┤    │
│  │                                                               │    │
│  │  askAI()                                                      │    │
│  │  ├─ 1. Validate Input                                        │    │
│  │  ├─ 2. Check Rate Limiting ─────► ai_rate_limits/{userId}   │    │
│  │  ├─ 3. Check Spam Detection ────► ai_spam_check/{userId}    │    │
│  │  ├─ 4. Track Usage ──────────────► ai_usage/{userId}         │    │
│  │  ├─ 5. Manage Trial ─────────────► users/{userId}            │    │
│  │  ├─ 6. Log Analytics ────────────► analytics_events          │    │
│  │  ├─ 7. Generate AI Response                                  │    │
│  │  └─ 8. Return: {message, trial, usage, warning}             │    │
│  │                                                               │    │
│  │  logPlacementView()                                           │    │
│  │  └─ Log Event ────────────────────► analytics_events         │    │
│  │                                                               │    │
│  │  logPlacementApplication()                                    │    │
│  │  └─ Log Event ────────────────────► analytics_events         │    │
│  │                                                               │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                  FIRESTORE DATABASE (V4)                      │    │
│  ├──────────────────────────────────────────────────────────────┤    │
│  │                                                               │    │
│  │  V4 COLLECTIONS (New):                                       │    │
│  │  ┌─────────────────────────────────────────────────┐         │    │
│  │  │ ai_usage/{userId}                               │         │    │
│  │  │  ├─ dailyCount: 12                              │         │    │
│  │  │  ├─ lastUsedAt: Timestamp                       │         │    │
│  │  │  └─ lastResetAt: Timestamp                      │         │    │
│  │  └─────────────────────────────────────────────────┘         │    │
│  │                                                               │    │
│  │  ┌─────────────────────────────────────────────────┐         │    │
│  │  │ ai_rate_limits/{userId}                         │         │    │
│  │  │  ├─ timestamps: [t1, t2, t3]                    │         │    │
│  │  │  └─ lastCleanup: Timestamp                      │         │    │
│  │  └─────────────────────────────────────────────────┘         │    │
│  │                                                               │    │
│  │  ┌─────────────────────────────────────────────────┐         │    │
│  │  │ ai_spam_check/{userId}                          │         │    │
│  │  │  ├─ lastMessage: "hello"                        │         │    │
│  │  │  ├─ repeatCount: 1                              │         │    │
│  │  │  └─ lastUpdated: Timestamp                      │         │    │
│  │  └─────────────────────────────────────────────────┘         │    │
│  │                                                               │    │
│  │  ┌─────────────────────────────────────────────────┐         │    │
│  │  │ analytics_events/{eventId}                      │         │    │
│  │  │  ├─ eventType: "ai_message_sent"                │         │    │
│  │  │  ├─ userId: "user123"                           │         │    │
│  │  │  ├─ metadata: {messageLength, dailyUsageCount}  │         │    │
│  │  │  └─ timestamp: Timestamp                        │         │    │
│  │  └─────────────────────────────────────────────────┘         │    │
│  │                                                               │    │
│  │  ┌─────────────────────────────────────────────────┐         │    │
│  │  │ applications/{userId}_{placementId}             │         │    │
│  │  │  ├─ userId: "user123"                           │         │    │
│  │  │  ├─ placementId: "placement456"                 │         │    │
│  │  │  ├─ resumeUrl: "https://..."                    │         │    │
│  │  │  ├─ appliedAt: Timestamp                        │         │    │
│  │  │  └─ status: "applied" | "shortlisted" | ...     │         │    │
│  │  └─────────────────────────────────────────────────┘         │    │
│  │                                                               │    │
│  │  V4 MODIFIED (Enhanced):                                     │    │
│  │  ┌─────────────────────────────────────────────────┐         │    │
│  │  │ users/{userId}                                  │         │    │
│  │  │  ├─ email: "user@example.com"                   │         │    │
│  │  │  ├─ aiTrialStartedAt: Timestamp     ◄─── NEW   │         │    │
│  │  │  └─ aiTrialExpiresAt: Timestamp     ◄─── NEW   │         │    │
│  │  └─────────────────────────────────────────────────┘         │    │
│  │                                                               │    │
│  │  V3 UNCHANGED (Backward Compatible):                         │    │
│  │  • notes/{noteId}                                            │    │
│  │  • placements/{placementId}                                  │    │
│  │  • ai_conversations/{conversationId}                         │    │
│  │                                                               │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                  SECURITY RULES (V4)                          │    │
│  ├──────────────────────────────────────────────────────────────┤    │
│  │                                                               │    │
│  │  ai_usage/{userId}          READ: owner | WRITE: deny        │    │
│  │  ai_rate_limits/{userId}    READ: owner | WRITE: deny        │    │
│  │  ai_spam_check/{userId}     READ: owner | WRITE: deny        │    │
│  │  analytics_events/{id}      READ: deny  | WRITE: deny        │    │
│  │  applications/{id}          READ: owner | WRITE: deny        │    │
│  │                                                               │    │
│  │  ✓ Only Cloud Functions can write                           │    │
│  │  ✓ Users can read their own data                            │    │
│  │  ✓ Analytics are admin-only                                 │    │
│  │                                                               │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                        │
└───────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│                         DATA FLOW (V4)                                 │
└───────────────────────────────────────────────────────────────────────┘

  USER SENDS MESSAGE
        │
        ▼
  ┌──────────────────┐
  │  Chat Screen     │
  │  _handleSend()   │
  └────────┬─────────┘
           │
           ▼
  ┌──────────────────┐
  │  AIService       │
  │  sendMessage()   │
  └────────┬─────────┘
           │ HTTP POST {userId, message}
           ▼
  ┌──────────────────────────────────────────┐
  │  Cloud Function: askAI()                 │
  │  ┌────────────────────────────────────┐  │
  │  │ 1. Validate input                  │  │
  │  └────────────────────────────────────┘  │
  │           │                               │
  │           ▼                               │
  │  ┌────────────────────────────────────┐  │
  │  │ 2. Check rate limit                │  │
  │  │    → ai_rate_limits/{userId}       │  │
  │  │    → If exceeded: return warning   │  │
  │  └────────────────────────────────────┘  │
  │           │                               │
  │           ▼                               │
  │  ┌────────────────────────────────────┐  │
  │  │ 3. Check spam                      │  │
  │  │    → ai_spam_check/{userId}        │  │
  │  │    → If spam: return warning       │  │
  │  └────────────────────────────────────┘  │
  │           │                               │
  │           ▼                               │
  │  ┌────────────────────────────────────┐  │
  │  │ 4. Track usage                     │  │
  │  │    → ai_usage/{userId}             │  │
  │  │    → Increment dailyCount          │  │
  │  └────────────────────────────────────┘  │
  │           │                               │
  │           ▼                               │
  │  ┌────────────────────────────────────┐  │
  │  │ 5. Manage trial                    │  │
  │  │    → users/{userId}                │  │
  │  │    → Create/check trial            │  │
  │  └────────────────────────────────────┘  │
  │           │                               │
  │           ▼                               │
  │  ┌────────────────────────────────────┐  │
  │  │ 6. Log analytics                   │  │
  │  │    → analytics_events              │  │
  │  │    → "ai_message_sent"             │  │
  │  └────────────────────────────────────┘  │
  │           │                               │
  │           ▼                               │
  │  ┌────────────────────────────────────┐  │
  │  │ 7. Generate AI response            │  │
  │  │    → generateMockAIResponse()      │  │
  │  └────────────────────────────────────┘  │
  │           │                               │
  │           ▼                               │
  │  ┌────────────────────────────────────┐  │
  │  │ 8. Log analytics                   │  │
  │  │    → "ai_response_received"        │  │
  │  └────────────────────────────────────┘  │
  │           │                               │
  │           ▼                               │
  │  ┌────────────────────────────────────┐  │
  │  │ 9. Return response                 │  │
  │  │    {                               │  │
  │  │      response: "AI message...",    │  │
  │  │      trial: {                      │  │
  │  │        status: "active",           │  │
  │  │        daysRemaining: 3            │  │
  │  │      },                            │  │
  │  │      usage: {                      │  │
  │  │        dailyCount: 12,             │  │
  │  │        dailyLimit: 50              │  │
  │  │      }                             │  │
  │  │    }                               │  │
  │  └────────────────────────────────────┘  │
  └──────────────┬───────────────────────────┘
                 │ HTTP 200 Response
                 ▼
  ┌──────────────────┐
  │  AIService       │
  │  ← AIResponse    │
  └────────┬─────────┘
           │
           ▼
  ┌──────────────────┐
  │  Chat Screen     │
  │  ├─ Display msg  │
  │  ├─ Show trial   │
  │  │   warning?    │
  │  └─ Show usage   │
  │     warning?     │
  └──────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│                    KEY V4 PRINCIPLES                                   │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  1. SERVER-SIDE ENFORCEMENT                                           │
│     • All business logic in Cloud Functions                          │
│     • Flutter only displays state                                     │
│     • No client-side validation bypassing                            │
│                                                                        │
│  2. SAFE DEFAULTS                                                     │
│     • If tracking fails → allow request                              │
│     • If trial fails → return status: 'none'                         │
│     • If analytics fails → log error, continue                       │
│                                                                        │
│  3. BACKWARD COMPATIBILITY                                            │
│     • All V3 features work unchanged                                 │
│     • Dual storage for applications                                  │
│     • Additive API changes only                                      │
│                                                                        │
│  4. FRIENDLY UX                                                       │
│     • AI-style conversational warnings                               │
│     • Orange snackbars (not red errors)                              │
│     • Informational messages, not blocks                             │
│                                                                        │
│  5. PRODUCTION-READY                                                  │
│     • Comprehensive error handling                                    │
│     • Firestore transactions for consistency                         │
│     • Logging for debugging                                          │
│     • Security rules enforced                                        │
│                                                                        │
└───────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│                    FUTURE ENHANCEMENTS                                 │
├───────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Phase 1 (V5): Payment Integration                                    │
│  ├─ Check trial.isExpired → redirect to payment                      │
│  ├─ Stripe/RevenueCat integration                                    │
│  └─ Subscription plans (Basic, Pro, Premium)                         │
│                                                                        │
│  Phase 2 (V6): Real AI Integration                                    │
│  ├─ Replace mock AI with OpenAI/Gemini/Claude                        │
│  ├─ API key management in Cloud Functions                            │
│  └─ Cost tracking per user                                           │
│                                                                        │
│  Phase 3 (V7): Analytics Dashboard                                    │
│  ├─ Admin panel to view analytics_events                             │
│  ├─ Usage graphs and trends                                          │
│  └─ User behavior insights                                           │
│                                                                        │
│  Phase 4 (V8): Advanced Features                                      │
│  ├─ Application status updates (admin panel)                         │
│  ├─ Email notifications                                              │
│  └─ Push notifications                                               │
│                                                                        │
└───────────────────────────────────────────────────────────────────────┘

VERSION 4 ARCHITECTURE COMPLETE ✅
Backend-safe, scalable, production-ready
```
