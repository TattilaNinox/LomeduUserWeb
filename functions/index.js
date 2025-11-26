const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const { buildTemplate, logoAttachment } = require('./emailTemplates');
const szamlaAgent = require('./szamlaAgent');
const szamlaAgentTest = require('./szamlaAgentTest');
const invoiceBuilder = require('./invoiceBuilder');

// Konfiguráció forrása: 1) Firebase Functions config (firebase functions:config:set smtp.*),
// 2) környezeti változók, 3) ha emulátor fut, próbáljon meg helyi SMTP-t (opcionális).

admin.initializeApp();

// Globális beállítások – régió, erőforrások
setGlobalOptions({ region: 'europe-west1', cpu: 1 });

const db = admin.firestore();

// SMTP transport - STARTTLS módszerrel
const transport = nodemailer.createTransport({
  host: 'mail.lomedu.hu',
  port: 587,
  secure: false, // STARTTLS
  requireTLS: true,
  auth: {
    user: 'info@lomedu.hu',
    pass: 'SoliDeoGloria55!!',
  },
});
const auth = admin.auth();

// ÚJ: Próbaidő lejárat ellenőrzés (cron job)
exports.checkTrialExpiryScheduled = onSchedule({
  schedule: '0 10 * * *', // Cron: minden nap 10:00-kor
  timeZone: 'Europe/Budapest',
  region: 'europe-west1', // Explicit régió megadása
  memory: '256MiB',
  timeoutSeconds: 540,
}, async (event) => {
  console.log('Scheduled trial expiry check started at:', new Date().toISOString());
  
  try {
    const now = new Date();
    const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
    
    let emailsSent = 0;
    let emailsSkipped = 0;
    
    // 1. PRÓBAIDŐ LEJÁRAT ELŐTTI EMLÉKEZTETŐK (3 nap múlva lejáró próbaidő)
    // Keressük azokat a felhasználókat, akiknek:
    // - Nincs aktív előfizetésük (isSubscriptionActive == false)
    // - A próbaidő 3 nap múlva jár le (freeTrialEndDate)
    // - Még nem kaptak értesítést
    
    const trialExpiringSoon = await db.collection('users')
      .where('isSubscriptionActive', '==', false) // Csak ha nincs aktív előfizetés
      .where('freeTrialEndDate', '>=', admin.firestore.Timestamp.fromDate(now))
      .where('freeTrialEndDate', '<=', admin.firestore.Timestamp.fromDate(threeDaysFromNow))
      .get();
      
    console.log(`Found ${trialExpiringSoon.size} users with trials expiring in 1-3 days`);
    
    for (const doc of trialExpiringSoon.docs) {
      const userData = doc.data();
      const endDate = userData.freeTrialEndDate.toDate();
      const daysLeft = Math.ceil((endDate - now) / (1000 * 60 * 60 * 24));
      
      if (daysLeft <= 3 && daysLeft > 0) {
        // Ellenőrizzük a lastReminder mezőt
        const lastReminder = userData.lastReminder || {};
        
        if (lastReminder.trial_expiry_warning) {
          console.log(`Skipping trial_expiry_warning for ${doc.id} - already sent on ${lastReminder.trial_expiry_warning.toDate().toISOString()}`);
          emailsSkipped++;
          continue;
        }
        
        // Email küldése
        try {
          await transport.sendMail({
            from: 'Lomedu <info@lomedu.hu>',
            to: userData.email,
            subject: `Próbaidőd hamarosan lejár - ${daysLeft} nap hátra`,
            text: `Kedves ${userData.name || 'Felhasználó'}!\n\nPróbaidőd ${daysLeft} nap múlva lejár. Ne maradj le a prémium funkciókról!\n\nFizess elő most: https://lomedu-user-web.web.app/subscription\n\nÜdvözlettel,\nA Lomedu csapat`,
            html: `<p>Kedves ${userData.name || 'Felhasználó'}!</p><p>Próbaidőd <strong>${daysLeft} nap múlva lejár</strong>. Ne maradj le a prémium funkciókról!</p><p><a href="https://lomedu-user-web.web.app/subscription">Fizess elő most</a></p><p>Üdvözlettel,<br>A Lomedu csapat</p>`,
          });
          
          // Frissítsük a lastReminder mezőt
          await db.collection('users').doc(doc.id).set({
            lastReminder: {
              trial_expiry_warning: admin.firestore.FieldValue.serverTimestamp(),
            }
          }, { merge: true });
          
          emailsSent++;
          console.log(`Sent trial_expiry_warning to ${userData.email} (${daysLeft} days left)`);
        } catch (emailError) {
          console.error(`Failed to send trial_expiry_warning to ${userData.email}:`, emailError);
        }
      }
    }
    
    // 2. LEJÁRT PRÓBAIDŐ ÉRTESÍTÉS (Ma járt le)
    // Keressük azokat, akiknek a próbaideje a közelmúltban járt le (pl. elmúlt 24 órában)
    // és még nem kaptak értesítést.
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    
    const trialExpired = await db.collection('users')
      .where('isSubscriptionActive', '==', false)
      .where('freeTrialEndDate', '<', admin.firestore.Timestamp.fromDate(now))
      .where('freeTrialEndDate', '>', admin.firestore.Timestamp.fromDate(oneDayAgo)) // Csak a frissen lejártakat nézzük
      .get();
      
    console.log(`Found ${trialExpired.size} users with recently expired trials`);
    
    for (const doc of trialExpired.docs) {
      const userData = doc.data();
      
      // Ellenőrizzük a lastReminder mezőt
      const lastReminder = userData.lastReminder || {};
      
      if (lastReminder.trial_expired) {
        console.log(`Skipping trial_expired for ${doc.id} - already sent`);
        emailsSkipped++;
        continue;
      }
      
      // Email küldése
      try {
        await transport.sendMail({
          from: 'Lomedu <info@lomedu.hu>',
          to: userData.email,
          subject: 'Próbaidőd lejárt - Fizess elő a folytatáshoz!',
          text: `Kedves ${userData.name || 'Felhasználó'}!\n\nPróbaidőd lejárt. Fizess elő most, hogy továbbra is elérd a prémium funkciókat!\n\nElőfizetés: https://lomedu-user-web.web.app/subscription\n\nÜdvözlettel,\nA Lomedu csapat`,
          html: `<p>Kedves ${userData.name || 'Felhasználó'}!</p><p>Próbaidőd <strong>lejárt</strong>. Fizess elő most, hogy továbbra is elérd a prémium funkciókat!</p><p><a href="https://lomedu-user-web.web.app/subscription">Előfizetés indítása</a></p><p>Üdvözlettel,<br>A Lomedu csapat</p>`,
        });
        
        // Frissítsük a lastReminder mezőt
        await db.collection('users').doc(doc.id).set({
          lastReminder: {
            trial_expired: admin.firestore.FieldValue.serverTimestamp(),
          }
        }, { merge: true });
        
        emailsSent++;
        console.log(`Sent trial_expired notification to ${userData.email}`);
      } catch (emailError) {
        console.error(`Failed to send trial_expired notification to ${userData.email}:`, emailError);
      }
    }
    
    console.log(`Scheduled trial expiry check completed. ${emailsSent} emails sent, ${emailsSkipped} skipped.`);
    
  } catch (error) {
    console.error('Scheduled trial expiry check error:', error);
    throw error;
  }
});

// ... (rest of the file)
