import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

export const syncSpotStatus = functions.database
  .ref('/spots/{parkingId}/{spotId}/status')
  .onWrite(async (change, context) => {
    const newStatus = change.after.val();
    const parkingId = context.params.parkingId;
    const spotId = context.params.spotId;

    try {
      const spotRef = admin.firestore()
        .collection('parking')
        .doc(parkingId)
        .collection('spots')
        .doc(spotId);

      // Get current spot data
      const spotDoc = await spotRef.get();
      if (!spotDoc.exists) return null;

      const spotData = spotDoc.data()!;
      const now = admin.firestore.Timestamp.now();

      // If spot is reserved, only update if expiry time has passed
      if (spotData.status === 'reserved') {
        const expiryTime = spotData.expiryTime?.toDate();
        if (expiryTime && expiryTime > now.toDate()) {
          // Don't update if reservation is still active
          return null;
        }
      }

      // Batch write for consistency
      const batch = admin.firestore().batch();

      // Update spot status
      batch.update(spotRef, {
        status: newStatus,
        lastUpdated: now,
        syncedFromRealtime: true,
        isAvailable: newStatus === 'available'
      });

      // Update parking availability if status changed to available
      if (newStatus === 'available') {
        const parkingRef = admin.firestore()
          .collection('parking')
          .doc(parkingId);
        
        const parkingDoc = await parkingRef.get();
        if (parkingDoc.exists) {
          const parkingData = parkingDoc.data()!;
          batch.update(parkingRef, {
            available: Math.min(parkingData.available + 1, parkingData.capacity),
            lastUpdated: now
          });
        }
      }

      await batch.commit();
      return null;
    } catch (error) {
      console.error('Error syncing spot status:', error);
      return null;
    }
  });

export const updateSpotStatus = functions.database
  .ref('/spots/{parkingId}/{spotId}/status')
  .onUpdate(async (change, context) => {
    const newStatus = change.after.val();
    const parkingId = context.params.parkingId;
    const spotId = context.params.spotId;

    const spotRef = admin.firestore()
      .collection('parking')
      .doc(parkingId)
      .collection('spots')
      .doc(spotId);

    const spotData = await spotRef.get();
    if (!spotData.exists) return null;

    // Don't update if spot is reserved and not past expiry time
    if (spotData.data()?.status === 'reserved') {
      const expiryTime = spotData.data()?.expiryTime?.toDate();
      if (expiryTime && expiryTime > new Date()) {
        return null;
      }
    }

    // Update status and sync flag
    await spotRef.update({
      'status': newStatus,
      'lastUpdated': admin.firestore.FieldValue.serverTimestamp(),
      'syncedFromRealtime': true
    });

    return null;
  });
