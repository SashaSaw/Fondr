const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// Helper: get partner's FCM token
async function getPartnerToken(pairId, senderUid) {
  const pairDoc = await db.collection("pairs").doc(pairId).get();
  if (!pairDoc.exists) return null;

  const pair = pairDoc.data();
  const partnerUid = pair.userA === senderUid ? pair.userB : pair.userA;
  if (!partnerUid) return null;

  const userDoc = await db.collection("users").doc(partnerUid).get();
  if (!userDoc.exists) return null;

  return { token: userDoc.data().fcmToken, name: userDoc.data().displayName || "Your partner" };
}

// Helper: get sender's display name
async function getSenderName(uid) {
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) return "Your partner";
  return userDoc.data().displayName || "Your partner";
}

// Helper: send notification
async function sendNotification(token, title, body, data = {}) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data,
      apns: {
        payload: {
          aps: { sound: "default", badge: 1 },
        },
      },
    });
  } catch (err) {
    console.error("FCM send error:", err);
  }
}

// 1. New vault fact
exports.onNewVaultFact = onDocumentCreated(
  "pairs/{pairId}/vault/{factId}",
  async (event) => {
    const pairId = event.params.pairId;
    const fact = event.data.data();
    const senderName = await getSenderName(fact.addedBy);
    const partner = await getPartnerToken(pairId, fact.addedBy);
    if (!partner?.token) return;

    await sendNotification(
      partner.token,
      "New Vault Entry",
      `${senderName} added something to your vault`,
      { type: "vault", pairId }
    );
  }
);

// 2. New list item
exports.onNewListItem = onDocumentCreated(
  "pairs/{pairId}/lists/{itemId}",
  async (event) => {
    const pairId = event.params.pairId;
    const item = event.data.data();
    const senderName = await getSenderName(item.addedBy);
    const partner = await getPartnerToken(pairId, item.addedBy);
    if (!partner?.token) return;

    await sendNotification(
      partner.token,
      "New Idea Added",
      `${senderName} added a date idea: ${item.title}`,
      { type: "listItem", pairId }
    );
  }
);

// 3. Session started
exports.onSessionStarted = onDocumentCreated(
  "pairs/{pairId}/sessions/{sessionId}",
  async (event) => {
    const pairId = event.params.pairId;
    const session = event.data.data();
    const senderName = await getSenderName(session.startedBy);
    const partner = await getPartnerToken(pairId, session.startedBy);
    if (!partner?.token) return;

    await sendNotification(
      partner.token,
      "Swipe Time!",
      `${senderName} wants to decide — swipe time!`,
      { type: "session", pairId }
    );
  }
);

// 4. Swipe match detected + 5. Session completed
exports.onSessionUpdated = onDocumentUpdated(
  "pairs/{pairId}/sessions/{sessionId}",
  async (event) => {
    const pairId = event.params.pairId;
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Check for new matches
    const oldMatches = before.matches || [];
    const newMatches = after.matches || [];

    if (newMatches.length > oldMatches.length) {
      const newMatchIds = newMatches.filter((m) => !oldMatches.includes(m));

      // Look up match titles
      for (const matchId of newMatchIds) {
        const itemDoc = await db
          .collection("pairs")
          .doc(pairId)
          .collection("lists")
          .doc(matchId)
          .get();

        const title = itemDoc.exists ? itemDoc.data().title : "something";

        // Notify both users
        const pairDoc = await db.collection("pairs").doc(pairId).get();
        if (!pairDoc.exists) continue;
        const pair = pairDoc.data();

        for (const uid of [pair.userA, pair.userB].filter(Boolean)) {
          const userDoc = await db.collection("users").doc(uid).get();
          if (!userDoc.exists) continue;
          const token = userDoc.data().fcmToken;
          if (!token) continue;

          await sendNotification(
            token,
            "It's a Match!",
            `You both want: ${title}`,
            { type: "match", pairId }
          );
        }
      }
    }
  }
);

// 6. New availability
exports.onNewAvailability = onDocumentCreated(
  "pairs/{pairId}/availability/{slotId}",
  async (event) => {
    const pairId = event.params.pairId;
    const slot = event.data.data();
    const senderName = await getSenderName(slot.userId);
    const partner = await getPartnerToken(pairId, slot.userId);
    if (!partner?.token) return;

    await sendNotification(
      partner.token,
      "Schedule Updated",
      `${senderName} updated their schedule`,
      { type: "availability", pairId }
    );
  }
);

// 7. New event proposed
exports.onNewEvent = onDocumentCreated(
  "pairs/{pairId}/events/{eventId}",
  async (event) => {
    const pairId = event.params.pairId;
    const eventData = event.data.data();
    const senderName = await getSenderName(eventData.createdBy);
    const partner = await getPartnerToken(pairId, eventData.createdBy);
    if (!partner?.token) return;

    await sendNotification(
      partner.token,
      "Date Proposed!",
      `${senderName} proposed a date: ${eventData.title}`,
      { type: "event", pairId }
    );
  }
);
