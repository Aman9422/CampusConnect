# VERSION 4: Quick Deployment Guide

⏱️ **Estimated Time:** 5 minutes

---

## 🚀 Deploy in 3 Steps

### Step 1: Deploy Firebase Cloud Functions (3 minutes)

```powershell
# Navigate to functions directory
cd C:\flutterApps\campusconnect\functions

# Install dependencies (if not already done)
npm install

# Deploy to Firebase
firebase deploy --only functions
```

**Expected Output:**
```
✔  functions[askAI(us-central1)]: Successful update operation.
✔  functions[logPlacementView(us-central1)]: Successful create operation.
✔  functions[logPlacementApplication(us-central1)]: Successful create operation.

✔  Deploy complete!
```

**If deployment fails:**
- Ensure you're logged in: `firebase login`
- Check project: `firebase use --add`
- Verify Node.js installed: `node --version` (should be v18+)

---

### Step 2: Verify Deployment (1 minute)

Open Firebase Console:
1. Go to https://console.firebase.google.com
2. Select your project
3. Navigate to **Functions** section
4. Confirm 3 functions are listed:
   - `askAI`
   - `logPlacementView`
   - `logPlacementApplication`

---

### Step 3: Test in Flutter App (1 minute)

```powershell
# Run the app
cd C:\flutterApps\campusconnect
flutter run
```

**Quick Test Checklist:**
- [ ] Send an AI message - should work normally
- [ ] Send 6 messages quickly - should see rate limit warning
- [ ] Send same message 3 times - should see spam warning
- [ ] Check Firestore console - should see new collections

---

## 🎯 What's New in V4

### Backend Features (Automatic)
✅ **Usage Tracking** - 50 messages/day per user  
✅ **5-Day Trial** - Starts on first AI use  
✅ **Rate Limiting** - Max 5 messages/minute  
✅ **Spam Detection** - Blocks repeated messages  
✅ **Analytics Logging** - All events tracked  
✅ **Application Preservation** - Persists even when placement closes

### User-Visible Changes
✅ **Trial Warnings** - Shows "Trial expires in X days" when ≤2 days left  
✅ **Usage Warnings** - Shows "You've used X of 50 messages" when near limit  
✅ **Friendly AI Responses** - Rate limit and spam messages are conversational

### No Breaking Changes
✅ All V3 features work exactly the same  
✅ No UI redesign  
✅ No user data migration needed  
✅ Backward compatible

---

## 📊 Monitor Your Deployment

### View Cloud Function Logs

```powershell
# Live logs
firebase functions:log --only askAI

# Recent errors
firebase functions:log --only askAI --lines 50
```

### Check Firestore Data

Open Firebase Console → Firestore Database

**New Collections to Monitor:**
1. **ai_usage** - Daily message counts
2. **ai_rate_limits** - Rate limiting state
3. **analytics_events** - All tracked events
4. **applications** - Persistent application records

**Modified Collections:**
1. **users** - Now includes trial fields
2. **ai_conversations** - Now includes usage count

---

## 🔧 Configuration

All limits are configurable in `functions/index.js`:

```javascript
const DAILY_MESSAGE_LIMIT = 50;          // Change daily limit
const RATE_LIMIT_MAX_MESSAGES = 5;       // Change rate limit
const TRIAL_DURATION_DAYS = 5;           // Change trial length
const MAX_MESSAGE_LENGTH = 1000;         // Change max message size
```

**To change settings:**
1. Edit `functions/index.js`
2. Run `firebase deploy --only functions`
3. Changes apply immediately

---

## ⚠️ Troubleshooting

### "Function deployment failed"
```powershell
# Login again
firebase login

# Select correct project
firebase use --add
```

### "Module not found"
```powershell
cd functions
npm install
```

### "Permission denied"
**Solution:** Ensure Firebase project has billing enabled (Blaze plan required for Cloud Functions)

### AI chat not responding
1. Check function URL in `lib/services/ai/ai_service.dart`
2. Verify Cloud Function deployed successfully
3. Check Firebase Console → Functions for errors

---

## 🎉 Success Criteria

Your deployment is successful when:

✅ All 3 Cloud Functions show "Healthy" status in Firebase Console  
✅ AI chat works in the app  
✅ Trial warnings appear (test by setting expiry to tomorrow)  
✅ Rate limiting triggers (send 6 messages quickly)  
✅ Firestore shows new collections: `ai_usage`, `analytics_events`, `applications`

---

## 📖 Full Documentation

For detailed information, see:
- **VERSION_4_CHANGES.md** - Complete feature documentation
- **functions/index.js** - Code comments explaining each feature
- **lib/services/ai/ai_service.dart** - Flutter integration details

---

## 🆘 Need Help?

**Check logs:**
```powershell
firebase functions:log
```

**Test function directly:**
```bash
curl -X POST https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/askAI \
  -H "Content-Type: application/json" \
  -d '{"userId":"test123","message":"Hello"}'
```

**Common Issues:**
- **Firebase not initialized:** Run `firebase init` in project root
- **Wrong project:** Run `firebase projects:list` and `firebase use <project-id>`
- **Billing not enabled:** Enable Blaze plan in Firebase Console

---

**READY TO DEPLOY?** 

Run these 3 commands:

```powershell
cd C:\flutterApps\campusconnect\functions
npm install
firebase deploy --only functions
```

Then test the app! 🚀
