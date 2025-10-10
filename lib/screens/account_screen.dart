import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
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
                  onRenewPressed: () {
                    // TODO: Navigálás a fizetési oldalra
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fizetési oldal hamarosan elérhető'),
                      ),
                    );
                  },
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
                  onRenewPressed: () {
                    // TODO: Navigálás a fizetési oldalra
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fizetési oldal hamarosan elérhető'),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Megújítási gomb (csak havi)
                SubscriptionRenewalButton(
                  showAsCard: false,
                  onPaymentInitiated: () {
                    // TODO: Navigálás a fizetési oldalra
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fizetési oldal hamarosan elérhető'),
                      ),
                    );
                  },
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
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
