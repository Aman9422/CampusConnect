# Version 3 Quick Start Guide

## 🚀 5-Minute Setup

### Prerequisites
- Firebase CLI installed (`npm install -g firebase-tools`)
- Firebase project created (campusconnect-firebase-project)
- Flutter environment configured

---

## Step 1: Deploy Cloud Function (3 minutes)

```bash
# Navigate to functions directory
cd C:\flutterApps\campusconnect\functions

# Install dependencies
npm install

# Login to Firebase
firebase login

# Deploy function
firebase deploy --only functions
```

**Expected Output:**
```
✔  functions[askAI(us-central1)] Successful create operation.
Function URL: https://us-central1-campusconnect-firebase-project.cloudfunctions.net/askAI
```

---

## Step 2: Update Flutter App (1 minute)

**Open:** `lib/services/ai/ai_service.dart`

**Find line 6-7:**
```dart
static const String _cloudFunctionUrl =
    'https://us-central1-campusconnect-firebase-project.cloudfunctions.net/askAI';
```

**Replace with your actual Function URL** (from Step 1 output)

---

## Step 3: Run the App (1 minute)

```bash
cd C:\flutterApps\campusconnect
flutter pub get
flutter run
```

---

## ✅ Quick Test

1. Open app → Login
2. Tap **AI Chat** tab (4th icon)
3. Tap suggestion: **"How to prepare for placements?"**
4. Wait 2-3 seconds
5. See AI response with placement tips

**Success!** ✅ AI Assistant is working

---

## 🧪 Test Commands

### Test AI Responses

**In app, try these:**
- "Hello" → Get welcome message
- "How to prepare for placements?" → Placement tips
- "Resume help" → Resume building guide
- "Study tips" → Exam strategies
- "Career guidance" → Career advice

### Test Cloud Function Directly

**PowerShell:**
```powershell
$body = @{
    userId = "test-user"
    message = "Hello AI"
} | ConvertTo-Json

Invoke-RestMethod -Uri "YOUR_FUNCTION_URL" -Method Post -Body $body -ContentType "application/json"
```

**Expected Response:**
```json
{
  "response": "Hello! I'm your CampusConnect AI Assistant...",
  "timestamp": "2026-01-14T..."
}
```

---

## 🐛 Common Issues

### Issue: Function URL not working
**Fix:** Wait 1-2 minutes after deployment, then retry

### Issue: CORS error
**Fix:** Function already has CORS enabled. Clear browser cache or restart app

### Issue: Timeout
**Fix:** First request takes 5-10 seconds (cold start). Retry after timeout

### Issue: "User not authenticated"
**Fix:** Ensure you're logged in to the app

---

## 📊 What to Check

### In Firebase Console:
1. **Functions** → See `askAI` listed and active
2. **Firestore** → Check `ai_conversations` collection (after sending messages)
3. **Logs** → View function execution logs

### In Flutter App:
1. **AI Chat tab** → See welcome screen
2. **Send message** → See blue user bubble
3. **Wait** → See "AI is thinking..."
4. **Response** → See gray AI bubble

---

## 🎯 Success Criteria

- [ ] Cloud Function deployed successfully
- [ ] Function URL accessible
- [ ] App connects to function
- [ ] Messages send and receive
- [ ] Chat UI works smoothly
- [ ] No errors in console

---

## 📝 Next Steps

1. Test all question types
2. Check Firestore for conversation logs
3. Monitor function logs for errors
4. Share with users for feedback
5. Plan Version 4 features

---

## 🔗 Resources

- [Full Implementation Guide](VERSION_3_IMPLEMENTATION_GUIDE.md)
- [Firebase Functions Docs](https://firebase.google.com/docs/functions)
- [Cloud Function URL Format](https://firebase.google.com/docs/functions/http-events)

---

**Need Help?**
- Check logs: `firebase functions:log`
- Test function: Use cURL or Postman
- Debug Flutter: Check Debug Console in VS Code

---

**Time to Complete:** ~5 minutes  
**Difficulty:** Easy ✅  
**Result:** Working AI Assistant 🤖
