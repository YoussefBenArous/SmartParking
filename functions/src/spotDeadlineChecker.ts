import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  admin.initializeApp();
}

export const checkSpotDeadline = functions.database
    .ref('/spots/{parkingId}/{spotId}/status')
    .onUpdate(async (change, context) => {
        try {
            const newValue = change.after.val();
            const parkingId = context.params.parkingId;
            const spotId = context.params.spotId;
            
            const spotRef = change.after.ref.parent;
            const spotSnapshot = await spotRef?.get();
            const spotData = spotSnapshot?.val();

            if (!spotData || !spotData.bookingId) return null;

            const now = new Date();
            const deadlineArrival = new Date(spotData.deadlineArrival);
            const expectedArrival = new Date(spotData.expectedArrival);
            
            // Check if deadline has passed regardless of sensor status
            if (now > deadlineArrival) {
                console.log(`Deadline passed for spot ${spotId} in parking ${parkingId}`);
                
                // Reset spot
                await spotRef?.update({
                    status: 'available',
                    bookingId: null,
                    userId: null,
                    expectedArrival: null,
                    deadlineArrival: null,
                    lastAction: 'deadline_expired'
                });

                // Cancel booking
                await admin.firestore()
                    .collection('bookings')
                    .doc(spotData.bookingId)
                    .update({
                        status: 'cancelled',
                        cancelReason: 'deadline_passed',
                        cancelledAt: admin.firestore.FieldValue.serverTimestamp()
                    });

                return null;
            }

            // Handle sensor detection
            if (spotData.status === 'reserved' && newValue === 'occupied') {
                // If arrived within deadline window
                if (now <= deadlineArrival) {
                    console.log(`Car arrived on time for spot ${spotId}`);
                    
                    await spotRef?.update({
                        status: 'occupied',
                        arrivedAt: now.toISOString(),
                        lastAction: 'car_arrived'
                    });
                    
                    await admin.firestore()
                        .collection('bookings')
                        .doc(spotData.bookingId)
                        .update({
                            status: 'active',
                            arrivedAt: admin.firestore.FieldValue.serverTimestamp()
                        });
                } else {
                    console.log(`Car arrived after deadline for spot ${spotId}`);
                    
                    // Handle late arrival
                    await spotRef?.update({
                        status: 'available',
                        bookingId: null,
                        userId: null,
                        expectedArrival: null,
                        deadlineArrival: null,
                        lastAction: 'late_arrival'
                    });

                    await admin.firestore()
                        .collection('bookings')
                        .doc(spotData.bookingId)
                        .update({
                            status: 'cancelled',
                            cancelReason: 'late_arrival',
                            cancelledAt: admin.firestore.FieldValue.serverTimestamp()
                        });
                }
            }

            return null;
        } catch (error) {
            console.error('Error in checkSpotDeadline:', error);
            throw error;
        }
    });

// Add a scheduled function to clean up expired reservations
export const cleanupExpiredReservations = functions.pubsub
    .schedule('every 5 minutes')
    .onRun(async (context) => {
        const db = admin.firestore();
        const now = new Date();

        try {
            const expiredBookings = await db.collection('bookings')
                .where('status', '==', 'active')
                .where('expiryTime', '<=', now)
                .get();

            const batch = db.batch();
            
            for (const doc of expiredBookings.docs) {
                const bookingData = doc.data();
                
                // Update booking status
                batch.update(doc.ref, {
                    status: 'cancelled',
                    cancelReason: 'expired',
                    cancelledAt: admin.firestore.FieldValue.serverTimestamp()
                });

                // Reset spot status
                const spotRef = db.collection('parking')
                    .doc(bookingData.parkingId)
                    .collection('spots')
                    .doc(bookingData.spotId);
                
                batch.update(spotRef, {
                    isAvailable: true,
                    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                    lastAction: 'reservation_expired'
                });
            }

            await batch.commit();
            console.log(`Cleaned up ${expiredBookings.size} expired reservations`);
            
            return null;
        } catch (error) {
            console.error('Error cleaning up expired reservations:', error);
            throw error;
        }
    });
