import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../services/email_notification_service.dart';
import '../widgets/subscription_reminder_banner.dart';
import '../widgets/enhanced_subscription_status_card.dart';
import '../widgets/subscription_renewal_button.dart';

/// Egyszerű fiókadatok képernyő, előfizetési státusszal.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fiók adatok')),
        body: const Center(child: Text('Nincs bejelentkezett felhasználó.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fiók adatok')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text('Nincsenek adataink a felhasználóról.'));
          }
          final data = snapshot.data!.data()!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // Emlékeztető banner
                SubscriptionReminderBanner(
                  onRenewPressed: () => context.go('/subscription'),
                ),

                // Felhasználói adatok
                Card(
                  child: ListTile(
                    title: Text(
                        '${data['lastName'] ?? ''} ${data['firstName'] ?? ''}'
                            .trim()),
                    subtitle: Text(user.email ?? ''),
                  ),
                ),
                const SizedBox(height: 12),

                // Fejlesztett előfizetési státusz kártya
                EnhancedSubscriptionStatusCard(
                  userData: data,
                  onRenewPressed: () => context.go('/subscription'),
                ),

                const SizedBox(height: 20),

                // Megújítási gomb (csak havi) - teljes szélességű, kiemelt
                SizedBox(
                  width: double.infinity,
                  child: SubscriptionRenewalButton(
                    showAsCard: false,
                    onPaymentInitiated: () => context.go('/subscription'),
                  ),
                ),

                const SizedBox(height: 20),

                // Teszt fizetés gomb (fejlesztéshez)
                if (kDebugMode) ...[
                  const Divider(),
                  const Text(
                    'Fejlesztői eszközök',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Teszt fizetés gomb
                  ElevatedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) {
                              return AlertDialog(
                                title: const Text('Teszt fizetés'),
                                content: const Text(
                                    'Ez csak teszt. A "Fizetés" gombbal imitáljuk a sikeres SimplePay tranzakciót.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Mégse'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Fizetés'),
                                  ),
                                ],
                              );
                            },
                          ) ??
                          false;
                      if (!confirmed) return;

                      final now = DateTime.now();
                      final expiry = now.add(const Duration(days: 30));
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .set(
                          {
                            'isSubscriptionActive': true,
                            'subscriptionStatus': 'premium',
                            'subscriptionEndDate': Timestamp.fromDate(expiry),
                            'subscription': {
                              'status': 'ACTIVE',
                              'productId': 'test_web_monthly',
                              'purchaseToken':
                                  'simulated_payment_${now.millisecondsSinceEpoch}',
                              'endTime': expiry.toIso8601String(),
                              'lastUpdateTime': now.toIso8601String(),
                              'source': 'test_simulation',
                            },
                            'lastPaymentDate': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          },
                          SetOptions(merge: true),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Sikeres teszt-fizetés!')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Hiba a teszt-fizetés során: $e')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Előfizetés frissítése (teszt)'),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) {
                                    return AlertDialog(
                                      title: const Text(
                                          'Lejárat előtti email teszt'),
                                      content: const Text(
                                          'Ez beállítja az előfizetést 3 napos lejáratra, hogy tesztelhessük a lejárat előtti email értesítéseket.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Mégse'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('Beállítás'),
                                        ),
                                      ],
                                    );
                                  },
                                ) ??
                                false;
                            if (!confirmed) return;

                            final now = DateTime.now();
                            final expiry = now.add(const Duration(days: 3));
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .set(
                                {
                                  'isSubscriptionActive': true,
                                  'subscriptionStatus': 'premium',
                                  'subscriptionEndDate':
                                      Timestamp.fromDate(expiry),
                                  'subscription': {
                                    'status': 'ACTIVE',
                                    'productId': 'test_web_monthly',
                                    'purchaseToken': 'test_expiry_3_days',
                                    'endTime': expiry.toIso8601String(),
                                    'lastUpdateTime': now.toIso8601String(),
                                    'source': 'test_simulation',
                                  },
                                  'lastPaymentDate':
                                      FieldValue.serverTimestamp(),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                  // NE töröljük a lastReminder mezőt teszteléskor!
                                  // Csak új előfizetés esetén töröljük
                                },
                                SetOptions(merge: true),
                              );
                              // Email küldése
                              final emailSent =
                                  await EmailNotificationService.sendTestEmail(
                                testType: 'expiry_warning',
                                daysLeft: 3,
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(emailSent
                                        ? 'Előfizetés beállítva 3 napos lejáratra és email elküldve!'
                                        : 'Előfizetés beállítva 3 napos lejáratra, de email küldése sikertelen!')));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Hiba: $e')));
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[600],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('3 napos lejárat'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) {
                                    return AlertDialog(
                                      title: const Text(
                                          'Lejárat utáni email teszt'),
                                      content: const Text(
                                          'Ez beállítja az előfizetést lejárt állapotra, hogy tesztelhessük a lejárat utáni email értesítéseket.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Mégse'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('Beállítás'),
                                        ),
                                      ],
                                    );
                                  },
                                ) ??
                                false;
                            if (!confirmed) return;

                            final now = DateTime.now();
                            final expiredDate =
                                now.subtract(const Duration(days: 1));
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .set(
                                {
                                  'isSubscriptionActive': false,
                                  'subscriptionStatus': 'expired',
                                  'subscriptionEndDate':
                                      Timestamp.fromDate(expiredDate),
                                  'subscription': {
                                    'status': 'EXPIRED',
                                    'productId': 'test_web_monthly',
                                    'purchaseToken': 'test_expired',
                                    'endTime': expiredDate.toIso8601String(),
                                    'lastUpdateTime': now.toIso8601String(),
                                    'source': 'test_simulation',
                                  },
                                  'lastPaymentDate':
                                      FieldValue.serverTimestamp(),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                  // NE töröljük a lastReminder mezőt teszteléskor!
                                  // Csak új előfizetés esetén töröljük
                                },
                                SetOptions(merge: true),
                              );
                              // Email küldése
                              final emailSent =
                                  await EmailNotificationService.sendTestEmail(
                                testType: 'expired',
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(emailSent
                                        ? 'Előfizetés beállítva lejárt állapotra és email elküldve!'
                                        : 'Előfizetés beállítva lejárt állapotra, de email küldése sikertelen!')));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Hiba: $e')));
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Lejárt állapot'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Reset gomb
                  ElevatedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) {
                              return AlertDialog(
                                title:
                                    const Text('Teszt állapot visszaállítása'),
                                content: const Text(
                                    'Ez visszaállítja az előfizetést ingyenes állapotra.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Mégse'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Visszaállítás'),
                                  ),
                                ],
                              );
                            },
                          ) ??
                          false;
                      if (!confirmed) return;

                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .set(
                          {
                            'isSubscriptionActive': false,
                            'subscriptionStatus': 'free',
                            'subscriptionEndDate': null,
                            'subscription': null,
                            'lastPaymentDate': null,
                            'updatedAt': FieldValue.serverTimestamp(),
                            // Töröljük a lastReminder mezőt, hogy újra küldhessünk emailt
                            'lastReminder': FieldValue.delete(),
                          },
                          SetOptions(merge: true),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Előfizetés visszaállítva ingyenes állapotra!')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Hiba: $e')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reset (ingyenes állapot)'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
