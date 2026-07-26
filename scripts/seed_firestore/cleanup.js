/**
 * CampusConnect v8.3 — Demo Data Cleanup Script
 *
 * Deletes ALL documents flagged with isDemoData: true across all
 * Firestore collections and subcollections.
 *
 * Safe: only touches documents with the isDemoData flag.
 * Production documents without this flag are NOT affected.
 *
 * Usage:
 *   1. Ensure serviceAccountKey.json is present
 *   2. npm run cleanup
 *
 * Handles:
 *   - Top-level collections: users, placements, mentorship_requests,
 *     opportunities, chats, applications, public_profiles
 *   - Subcollections under users: resumeReviews, engagement_summary,
 *     recommendations, recommendations_meta, activities,
 *     notifications, ai_interactions, ai_insights
 *   - Subcollections under placements: applications
 *   - Subcollections under chats: messages
 *
 * Deletion order respects Firestore constraints:
 *   - Subcollections before parent documents
 *   - Batch writes for efficiency (chunks of 490)
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// ============================================================================
// UTILITIES
// ============================================================================
let totalDeleted = 0;
let totalBatches = 0;

function log(msg) { console.log(msg); }

async function batchDelete(docs) {
  if (docs.length === 0) return;
  for (let i = 0; i < docs.length; i += 490) {
    const batch = db.batch();
    const chunk = docs.slice(i, i + 490);
    for (const doc of chunk) batch.delete(doc.ref);
    await batch.commit();
    totalBatches++;
    totalDeleted += chunk.length;
    log(`   Batch ${totalBatches}: Deleted ${chunk.length} docs (${totalDeleted} total)`);
  }
}

/**
 * Recursively delete all documents in a collection/subcollection that have
 * the isDemoData flag set to true.
 */
async function deleteDemoDocs(collectionRef) {
  const docs = [];
  const query = await collectionRef.where('isDemoData', '==', true).get();

  for (const doc of query.docs) {
    // Recursively delete subcollections first
    const subcollections = await doc.ref.listCollections();
    for (const subcol of subcollections) {
      await deleteDemoDocs(subcol);
    }
    docs.push({ ref: doc.ref });
  }

  if (docs.length > 0) {
    await batchDelete(docs);
  }
}

/**
 * Delete demo documents from a path without recursion (for leaf collections).
 */
async function deleteLeafDemoDocs(collectionRef) {
  const docs = [];
  const query = await collectionRef.where('isDemoData', '==', true).get();
  for (const doc of query.docs) docs.push({ ref: doc.ref });
  if (docs.length > 0) await batchDelete(docs);
}

/**
 * Delete all subcollections for a list of parent documents (used for users
 * where we know the demo UIDs and their subcollections).
 */
async function deleteUserSubcollections(userIds) {
  const subcollections = [
    'resumeReviews', 'engagement_summary', 'recommendations',
    'recommendations_meta', 'activities', 'notifications',
    'ai_interactions', 'ai_insights',
  ];

  for (const uid of userIds) {
    const userRef = db.collection('users').doc(uid);
    for (const subcol of subcollections) {
      await deleteLeafDemoDocs(userRef.collection(subcol));
    }
  }
}

/**
 * Delete all applications under placements (subcollection).
 */
async function deletePlacementSubcollections(placementIds) {
  for (const pid of placementIds) {
    await deleteLeafDemoDocs(db.collection('placements').doc(pid).collection('applications'));
  }
}

/**
 * Delete all messages under chats (subcollection).
 */
async function deleteChatSubcollections(chatIds) {
  for (const cid of chatIds) {
    await deleteLeafDemoDocs(db.collection('chats').doc(cid).collection('messages'));
  }
}

// ============================================================================
// MAIN CLEANUP
// ============================================================================
async function main() {
  console.log('🧹 CampusConnect v8.3 — Demo Data Cleanup');
  console.log('='.repeat(60));
  console.log('Starting cleanup at:', new Date().toISOString());
  console.log('Only documents with isDemoData: true will be deleted.');
  console.log('='.repeat(60));

  try {
    // --- Phase 1: Find all demo user UIDs ---
    log('\n📋 Phase 1: Identifying demo users...');
    const userQuery = await db.collection('users').where('isDemoData', '==', true).get();
    const demoUserIds = userQuery.docs.map(d => d.id);
    log(`   Found ${demoUserIds.length} demo users`);
    for (const uid of demoUserIds) log(`   - ${uid}`);

    // --- Phase 2: Find all demo placements ---
    log('\n📋 Phase 2: Identifying demo placements...');
    const placementQuery = await db.collection('placements').where('isDemoData', '==', true).get();
    const demoPlacementIds = placementQuery.docs.map(d => d.id);
    log(`   Found ${demoPlacementIds.length} demo placements`);

    // --- Phase 3: Find all demo chats ---
    log('\n📋 Phase 3: Identifying demo chats...');
    const chatQuery = await db.collection('chats').where('isDemoData', '==', true).get();
    const demoChatIds = chatQuery.docs.map(d => d.id);
    log(`   Found ${demoChatIds.length} demo chats`);

    // --- Phase 4: Delete subcollections first ---
    log('\n🗑️  Phase 4: Deleting user subcollections (resume reviews, engagement, recommendations, etc.)...');
    await deleteUserSubcollections(demoUserIds);

    log('\n🗑️  Phase 5: Deleting placement subcollections (applications)...');
    await deletePlacementSubcollections(demoPlacementIds);

    log('\n🗑️  Phase 6: Deleting chat subcollections (messages)...');
    await deleteChatSubcollections(demoChatIds);

    // --- Phase 7: Delete top-level demo documents ---
    log('\n🗑️  Phase 7: Deleting top-level collections...');

    // Applications (global collection)
    log('   Deleting applications...');
    await deleteLeafDemoDocs(db.collection('applications'));

    // Mentorship requests
    log('   Deleting mentorship_requests...');
    await deleteLeafDemoDocs(db.collection('mentorship_requests'));

    // Opportunities
    log('   Deleting opportunities...');
    await deleteLeafDemoDocs(db.collection('opportunities'));

    // Public profiles
    log('   Deleting public_profiles...');
    await deleteLeafDemoDocs(db.collection('public_profiles'));

    // Chats (parent docs — messages already deleted in Phase 6)
    log('   Deleting chats...');
    await deleteLeafDemoDocs(db.collection('chats'));

    // Placements (parent docs — applications already deleted in Phase 5)
    log('   Deleting placements...');
    await deleteLeafDemoDocs(db.collection('placements'));

    // Users (parent docs — subcollections already deleted in Phase 4)
    log('   Deleting users...');
    await deleteLeafDemoDocs(db.collection('users'));

    // --- Summary ---
    console.log('\n' + '='.repeat(60));
    console.log('✅ CLEANUP COMPLETE');
    console.log('='.repeat(60));
    console.log(`   Total batches: ${totalBatches}`);
    console.log(`   Total documents deleted: ${totalDeleted}`);
    console.log(`   Demo users removed: ${demoUserIds.length}`);
    console.log(`   Demo placements removed: ${demoPlacementIds.length}`);
    console.log(`   Demo chats removed: ${demoChatIds.length}`);
    console.log('='.repeat(60));
    console.log('\nAll demo data has been removed. Production data is untouched.\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Cleanup failed:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

main();
