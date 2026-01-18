# VERSION 4: Firestore Security Rules

**IMPORTANT:** Update your Firestore security rules to allow V4 collections.

---

## 🔒 Required Security Rules

Add these rules to your `firestore.rules` file or Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function: Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function: Check if user owns the document
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // ===============================================
    // EXISTING COLLECTIONS (Keep these)
    // ===============================================
    
    // Users collection
    match /users/{userId} {
      allow read: if isOwner(userId);
      allow write: if isOwner(userId);
    }
    
    // Notes collection
    match /notes/{noteId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update, delete: if isOwner(resource.data.userId);
    }
    
    // Placements collection
    match /placements/{placementId} {
      allow read: if isAuthenticated();
      allow write: if false; // Admin only (via Cloud Functions)
      
      // Placement applications (old structure - keep for compatibility)
      match /applications/{userId} {
        allow read: if isAuthenticated();
        allow create: if isOwner(userId);
        allow update, delete: if false; // Immutable after creation
      }
    }
    
    // AI conversations
    match /ai_conversations/{conversationId} {
      allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
      allow write: if false; // Only Cloud Functions can write
    }
    
    // ===============================================
    // VERSION 4: NEW COLLECTIONS
    // ===============================================
    
    // AI usage tracking (V4)
    match /ai_usage/{userId} {
      allow read: if isOwner(userId);
      allow write: if false; // Only Cloud Functions can write
    }
    
    // AI rate limits (V4)
    match /ai_rate_limits/{userId} {
      allow read: if isOwner(userId);
      allow write: if false; // Only Cloud Functions can write
    }
    
    // AI spam check (V4)
    match /ai_spam_check/{userId} {
      allow read: if isOwner(userId);
      allow write: if false; // Only Cloud Functions can write
    }
    
    // Analytics events (V4)
    match /analytics_events/{eventId} {
      allow read: if false; // Admin only (via Console)
      allow write: if false; // Only Cloud Functions can write
    }
    
    // Applications - Top-level collection (V4)
    match /applications/{applicationId} {
      allow read: if isAuthenticated() && 
                     resource.data.userId == request.auth.uid;
      allow write: if false; // Only Cloud Functions can write
    }
  }
}
```

---

## 🔄 How to Update Rules

### Option 1: Firebase Console (Easiest)

1. Go to https://console.firebase.google.com
2. Select your project
3. Navigate to **Firestore Database** → **Rules**
4. Copy the rules above
5. Click **Publish**

### Option 2: Firebase CLI

1. Edit `firestore.rules` in project root
2. Deploy:
   ```bash
   firebase deploy --only firestore:rules
   ```

---

## 🔐 Security Principles

### V4 Collections Are Server-Side Only

**Cloud Functions Write, Users Read:**
- `ai_usage` - Tracks usage, users can view their own
- `ai_rate_limits` - Rate limit state, users can view their own
- `ai_spam_check` - Spam detection, users can view their own
- `analytics_events` - Admin analytics, users cannot access
- `applications` - Application records, users can view their own

### Why Server-Side?

✅ **Prevents tampering** - Users can't reset their usage  
✅ **Enforces limits** - Backend controls all logic  
✅ **Accurate tracking** - No client-side manipulation  
✅ **Audit trail** - All events logged server-side

---

## 🧪 Test Your Rules

### Using Firebase Console

1. Go to **Firestore Database** → **Rules** → **Simulator**
2. Test read access:
   ```
   Location: /ai_usage/user123
   Authenticated: Yes (user123)
   Operation: get
   Result: Should ALLOW
   ```
3. Test write access:
   ```
   Location: /ai_usage/user123
   Authenticated: Yes (user123)
   Operation: create
   Result: Should DENY
   ```

### Using Firebase Emulator

```bash
firebase emulators:start --only firestore
```

Then run your Flutter app against emulator.

---

## ⚠️ Important Security Notes

### DO NOT allow client writes to:
- ❌ `ai_usage` - Would allow unlimited usage
- ❌ `ai_rate_limits` - Would bypass rate limiting
- ❌ `analytics_events` - Would pollute analytics
- ❌ `applications` (direct writes) - Use Cloud Functions

### Users CAN read:
- ✅ Their own `ai_usage` document
- ✅ Their own `ai_rate_limits` document
- ✅ Their own `applications` documents
- ✅ All `placements` (active ones)

### Only Cloud Functions can write:
- ✅ All V4 tracking collections
- ✅ Analytics events
- ✅ Application records

---

## 🔍 Verify Security

After deploying rules, test in Flutter app:

### Should Work:
```dart
// Read own usage
await FirebaseFirestore.instance
  .collection('ai_usage')
  .doc(currentUserId)
  .get();

// Read own applications
await FirebaseFirestore.instance
  .collection('applications')
  .where('userId', isEqualTo: currentUserId)
  .get();
```

### Should Fail:
```dart
// Try to write usage (should fail)
await FirebaseFirestore.instance
  .collection('ai_usage')
  .doc(currentUserId)
  .set({'dailyCount': 0}); // ❌ Permission denied

// Try to read another user's usage (should fail)
await FirebaseFirestore.instance
  .collection('ai_usage')
  .doc('otherUserId')
  .get(); // ❌ Permission denied
```

---

## 📊 Rule Change Summary

**New Collections Protected:**
- `ai_usage` - Read own, write deny
- `ai_rate_limits` - Read own, write deny
- `ai_spam_check` - Read own, write deny
- `analytics_events` - Read deny, write deny (admin only)
- `applications` - Read own, write deny

**Existing Collections:**
- No changes to `users`, `notes`, `placements`
- Backward compatible with V3

---

## 🚨 Troubleshooting

### "Permission denied" errors in app

**Check:**
1. Rules deployed successfully
2. User is authenticated
3. Using correct userId in queries
4. Not trying to write to protected collections

### Rules not updating

**Solution:**
```bash
# Force deploy
firebase deploy --only firestore:rules --force
```

### Emulator rules not working

**Solution:**
```bash
# Restart emulator
firebase emulators:start --only firestore --import=./data --export-on-exit
```

---

## ✅ Deployment Checklist

After updating rules:

- [ ] Rules deployed to Firebase
- [ ] Test read own usage in app (should work)
- [ ] Test write usage in app (should fail)
- [ ] AI chat still works (Cloud Function writes)
- [ ] Applications persist (Cloud Function writes)
- [ ] No permission errors in console

---

## 🔗 Related Documentation

- **VERSION_4_CHANGES.md** - Full feature documentation
- **VERSION_4_DEPLOYMENT.md** - Deployment guide
- **Firebase Security Rules Docs:** https://firebase.google.com/docs/firestore/security/get-started

---

**DEPLOY RULES AFTER deploying Cloud Functions** ✅
