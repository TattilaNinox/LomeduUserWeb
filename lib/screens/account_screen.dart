import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/email_notification_service.dart';
import '../widgets/subscription_reminder_banner.dart';
import '../widgets/enhanced_subscription_status_card.dart';
import '../widgets/subscription_renewal_button.dart';
import '../services/account_deletion_service.dart';

/// Egyszerű fiókadatok képernyő, előfizetési státusszal.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Fiók adatok'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/notes'),
          ),
        ),
        body: const Center(child: Text('Nincs bejelentkezett felhasználó.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiók adatok'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/notes'),
        ),
      ),
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

          // Fizetési visszairányítás kezelése: üzenet a query param alapján, majd tisztítás
          final qp = GoRouterState.of(context).uri.queryParameters;
          final paymentStatus = qp['payment'];
          // final orderRef = qp['orderRef'];
          if (paymentStatus != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              // UI jelzés
              final msg = switch (paymentStatus) {
                'success' => 'Fizetés sikeres.',
                'fail' => 'Fizetés sikertelen.',
                'timeout' => 'Fizetés időtúllépés.',
                'cancelled' => 'Fizetés megszakítva.',
                _ => 'Fizetés státusz: $paymentStatus',
              };
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(msg)));

              // Csak URL tisztítás – szerver oldali IPN/recon végzi a lezárást
              if (context.mounted) {
                context.go('/account');
              }
            });
          }

          // Fallback: ha nincs query param, próbáljuk lekérdezni a legutóbbi státuszt (csak olvasás)
          if (paymentStatus == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                // nincs extra kliens akció – elhagyjuk az auto-confirmet, a szerver oldali recon/ipn intézi
              } catch (_) {
                // csendes fallback
              }
            });
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // Emlékeztető banner
                SubscriptionReminderBanner(
                  onRenewPressed: () => context.go('/subscription'),
                ),

                // Felhasználói adatok + műveletek (felső sávban)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${data['lastName'] ?? ''} ${data['firstName'] ?? ''}'
                                    .trim(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email ?? '',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => context.go('/change-password'),
                              icon: const Icon(Icons.password),
                              label: const Text('Jelszó megváltoztatása'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _confirmAndDelete(context),
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Fiók végleges törlése'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Fejlesztett előfizetési státusz kártya
                EnhancedSubscriptionStatusCard(
                  userData: data,
                  onRenewPressed: () => context.go('/subscription'),
                ),

                const SizedBox(height: 20),

                const SizedBox(height: 20),

                // Megújítási gomb (csak havi) - teljes szélességű, kiemelt
                SizedBox(
                  width: double.infinity,
                  child: SubscriptionRenewalButton(
                    showAsCard: false,
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

  Future<void> _confirmAndDelete(BuildContext context) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nincs bejelentkezett felhasználó.')),
      );
      return;
    }

    final passwordCtrl = TextEditingController();
    String? errorText;
    bool isLoading = false;
    bool obscure = true;

    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setState) {
                return AlertDialog(
                  title: const Text('Fiók végleges törlése'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Biztosan törölni szeretnéd a fiókodat?\n\n'
                        'A törlés végleges. A profilod és az adataid eltávolításra kerülnek.\n'
                        'A későbbiekben nem tudjuk visszaállítani.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: obscure,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: 'Jelszó',
                          errorText: errorText,
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(obscure
                                ? Icons.visibility
                                : Icons.visibility_off),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.of(ctx).pop(false),
                      child: const Text('Mégse'),
                    ),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() {
                                isLoading = true;
                                errorText = null;
                              });
                              try {
                                await AccountDeletionService.deleteAccount(
                                  passwordCtrl.text,
                                );
                                if (context.mounted) {
                                  Navigator.of(ctx).pop(true);
                                }
                              } on FirebaseAuthException catch (e) {
                                String msg;
                                switch (e.code) {
                                  case 'wrong-password':
                                    msg = 'Hibás jelszó.';
                                    break;
                                  case 'requires-recent-login':
                                    msg =
                                        'A művelethez friss bejelentkezés szükséges.';
                                    break;
                                  default:
                                    msg =
                                        'Hitelesítési hiba: ${e.message ?? e.code}';
                                }
                                setState(() {
                                  errorText = msg;
                                  isLoading = false;
                                });
                              } catch (e) {
                                setState(() {
                                  errorText = 'Hiba történt: $e';
                                  isLoading = false;
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Végleges törlés'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    if (confirmed) {
      // A szolgáltatás kijelentkeztet; a router redirect a loginra visz.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fiók sikeresen törölve.')),
        );
        // Biztos átirányítás a loginra
        context.go('/login');
      }
    }
  }
}
