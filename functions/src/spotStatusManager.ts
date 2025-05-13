import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const manageSpotStatus = functions.firestore
    .document('parking/{parkingId}/spots/{spotId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const oldData = change.before.data();
        const { parkingId, spotId } = context.params;

        try {
            // If spot becomes reserved, stop syncing with realtime database
            if (newData.status === 'reserved' && oldData.status !== 'reserved') {
                await admin.database().ref(`spots/${parkingId}/${spotId}`)
                    .update({
                        ignoreStatusUpdates: true,
                        status: 'reserved',
                        lastUpdated: admin.database.ServerValue.TIMESTAMP
                    });
            }

            // If reservation expires or is cancelled, resume syncing
            if (oldData.status === 'reserved' && newData.status !== 'reserved') {
                const rtdbRef = admin.database().ref(`spots/${parkingId}/${spotId}`);
                const rtdbSnap = await rtdbRef.get();
                const sensorStatus = rtdbSnap.val()?.status || 'available';

                await rtdbRef.update({
                    ignoreStatusUpdates: false,
                    status: sensorStatus,
                    lastUpdated: admin.database.ServerValue.TIMESTAMP
                });

                // Update Firestore with current sensor status
                await change.after.ref.update({
                    status: sensorStatus,
                    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                    syncedFromRealtime: true
                });
            }
        } catch (error) {
            console.error('Error managing spot status:', error);
        }
    });
