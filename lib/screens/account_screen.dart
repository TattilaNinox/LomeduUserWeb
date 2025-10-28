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
import '../widgets/trial_period_banner.dart';
import '../widgets/simplepay_logo.dart';
import '../widgets/web_payment_history.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(
                child: Text('Nincsenek adataink a felhasználóról.'));
          }
          final data = userSnapshot.data!.data()!;

          // Fizetési visszairányítás kezelése: részletes dialógok a SimplePay spec szerint
          final qp = GoRouterState.of(context).uri.queryParameters;
          final paymentStatus = qp['payment'];
          final orderRef = qp['orderRef'];
          if (paymentStatus != null && orderRef != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!context.mounted) return;

              // URL tisztítás először
              context.go('/account');

              // AZONNAL frissítjük a web_payments státuszt callback alapján
              try {
                final functions =
                    FirebaseFunctions.instanceFor(region: 'europe-west1');
                final callable =
                    functions.httpsCallable('updatePaymentStatusFromCallback');
                await callable.call({
                  'orderRef': orderRef,
                  'callbackStatus': paymentStatus,
                });
                debugPrint('[PaymentCallback] Status updated: $paymentStatus');
              } catch (e) {
                debugPrint('[PaymentCallback] Update error: $e');
              }

              // Majd megjelenítjük a megfelelő dialógot
              await Future.delayed(const Duration(milliseconds: 300));
              if (!context.mounted) return;

              switch (paymentStatus) {
                case 'success':
                  await _showPaymentSuccessDialog(context, orderRef);
                  break;
                case 'fail':
                  await _showPaymentFailedDialog(context, orderRef);
                  break;
                case 'timeout':
                  _showPaymentTimeoutDialog(context);
                  break;
                case 'cancelled':
                  _showPaymentCancelledDialog(context);
                  break;
                default:
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fizetés státusz: $paymentStatus')),
                  );
              }
            });
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // Emlékeztető banner
                SubscriptionReminderBanner(
                  onRenewPressed: () => context.go('/account'),
                ),

                // Próbaidőszak bannere
                TrialPeriodBanner(userData: data),

                // Felhasználói adatok + műveletek (felső sávban)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Kis képernyőn (< 700px) oszlopos elrendezés
                        final isSmallScreen = constraints.maxWidth < 700;

                        if (isSmallScreen) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Felhasználói adatok
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
                              const SizedBox(height: 12),
                              // Gombok egymás alatt
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      context.go('/change-password'),
                                  icon: const Icon(Icons.password),
                                  label: const Text('Jelszó megváltoztatása'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _confirmAndDelete(context),
                                  icon: const Icon(Icons.delete_forever),
                                  label: const Text('Fiók végleges törlése'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[700],
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        // Nagy képernyőn vízszintes elrendezés
                        return Row(
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
                                    style:
                                        const TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      context.go('/change-password'),
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
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Fejlesztett előfizetési státusz kártya
                EnhancedSubscriptionStatusCard(
                  userData: data,
                  onRenewPressed: () => context.go('/account'),
                ),

                const SizedBox(height: 20),

                const SizedBox(height: 20),

                // Megújítási gomb (csak havi) - teljes szélességű, kiemelt
                const SizedBox(
                  width: double.infinity,
                  child: SubscriptionRenewalButton(
                    showAsCard: false,
                  ),
                ),

                const SizedBox(height: 20),

                // SimplePay logó (csak webes platformon - SimplePay követelmény)
                if (kIsWeb) ...[
                  // Reszponzív méret mobil/tablet/desktop nézethez
                  LayoutBuilder(
                    builder: (context, constraints) {
                      double logoWidth;
                      if (constraints.maxWidth < 600) {
                        // Mobile - nagyobb logó a részletek jobb láthatóságához
                        logoWidth = constraints.maxWidth *
                            0.9; // 90% a képernyő szélességének
                      } else if (constraints.maxWidth < 900) {
                        // Tablet - nagyobb logó
                        logoWidth = 450;
                      } else {
                        // Desktop - nagy logó a részletek jobb láthatóságához
                        logoWidth = 482; // teljes méret
                      }
                      return SimplePayLogo(
                        centered: true,
                        width: logoWidth,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // Fizetési előzmények
                WebPaymentHistory(
                  userData: {...data, 'uid': user.uid},
                  onRefresh: () {}, // StreamBuilder automatikusan frissít
                ),

                const SizedBox(height: 20),

                // Teszt eszközök (SimplePay teszteléshez)
                // Csak a lomeduteszt@gmail.com felhasználónak látható (release build-ben is)
                if (user.email == 'lomeduteszt@gmail.com') ...[
                  const Divider(),
                  const Text(
                    'Teszt eszközök',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        final now = DateTime.now();
                        final trialEnd = now.add(const Duration(days: 5));

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
                            'freeTrialEndDate': Timestamp.fromDate(trialEnd),
                            'updatedAt': FieldValue.serverTimestamp(),
                            // Töröljük a lastReminder mezőt, hogy újra küldhessünk emailt
                            'lastReminder': FieldValue.delete(),
                          },
                          SetOptions(merge: true),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Előfizetés visszaállítva ingyenes állapotra! (5 napos próbaidőszak)')));
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

  /// Sikeres fizetés dialóg (SimplePay 3.13.4 szerint)
  static Future<void> _showPaymentSuccessDialog(
      BuildContext context, String? orderRef) async {
    // SimplePay transactionId lekérése queryPaymentStatus használatával
    // Ez várja meg az IPN feldolgozását és garantáltan friss adatot ad
    String? transactionId;
    if (orderRef != null) {
      try {
        // Várunk 2 másodpercet az IPN feldolgozásra
        await Future.delayed(const Duration(seconds: 2));

        // queryPaymentStatus Cloud Function hívása
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
            .httpsCallable('queryPaymentStatus');
        final result = await callable.call({'orderRef': orderRef});

        if (result.data['success'] == true) {
          transactionId = result.data['transactionId'] as String?;
          debugPrint('transactionId lekérdezve: $transactionId');
        }
      } catch (e) {
        debugPrint('Hiba a queryPaymentStatus híváskor: $e');
        // Fallback: próbáljuk meg közvetlenül Firestore-ból
        try {
          final paymentDoc = await FirebaseFirestore.instance
              .collection('web_payments')
              .doc(orderRef)
              .get();
          if (paymentDoc.exists) {
            transactionId =
                paymentDoc.data()?['simplePayTransactionId']?.toString();
          }
        } catch (e2) {
          debugPrint('Firestore fallback is sikertelen: $e2');
        }
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 28),
            const SizedBox(width: 12),
            const Text('Sikeres tranzakció'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A fizetés sikeresen megtörtént!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text(
                'Előfizetése aktiválva lett. Most már teljes hozzáférése van minden funkcióhoz.'),
            if (transactionId != null || orderRef != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SimplePay tranzakcióazonosító:',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transactionId ?? orderRef!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rendben'),
          ),
        ],
      ),
    );
  }

  /// Sikertelen fizetés dialóg (SimplePay 3.13.3 szerint - KÖTELEZŐ!)
  static Future<void> _showPaymentFailedDialog(
      BuildContext context, String? orderRef) async {
    // SimplePay transactionId lekérése queryPaymentStatus használatával
    // Ez várja meg az IPN feldolgozását és garantáltan friss adatot ad
    String? transactionId;
    if (orderRef != null) {
      try {
        // Várunk 2 másodpercet az IPN feldolgozásra
        await Future.delayed(const Duration(seconds: 2));

        // queryPaymentStatus Cloud Function hívása
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
            .httpsCallable('queryPaymentStatus');
        final result = await callable.call({'orderRef': orderRef});

        if (result.data['success'] == true) {
          transactionId = result.data['transactionId'] as String?;
          debugPrint('transactionId lekérdezve (failed): $transactionId');
        }
      } catch (e) {
        debugPrint('Hiba a queryPaymentStatus híváskor: $e');
        // Fallback: próbáljuk meg közvetlenül Firestore-ból
        try {
          final paymentDoc = await FirebaseFirestore.instance
              .collection('web_payments')
              .doc(orderRef)
              .get();
          if (paymentDoc.exists) {
            transactionId =
                paymentDoc.data()?['simplePayTransactionId']?.toString();
          }
        } catch (e2) {
          debugPrint('Firestore fallback is sikertelen: $e2');
        }
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 28),
            const SizedBox(width: 12),
            const Text('Sikertelen tranzakció'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transactionId != null || orderRef != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SimplePay tranzakcióazonosító:',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transactionId ?? orderRef!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Kérjük, ellenőrizze a tranzakció során megadott adatok helyességét.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const Text(
              'Amennyiben minden adatot helyesen adott meg, a visszautasítás okának '
              'kivizsgálása érdekében kérjük, szíveskedjen kapcsolatba lépni '
              'kártyakibocsátó bankjával.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Bezárás'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/account');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Újrapróbálás'),
          ),
        ],
      ),
    );
  }

  /// Időtúllépés dialóg (SimplePay 3.13.2 szerint - KÖTELEZŐ!)
  static void _showPaymentTimeoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cím
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          color: Colors.orange[600], size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Időtúllépés',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Tájékoztatás
                  const Text(
                    'Ön túllépte a tranzakció elindításának lehetséges maximális idejét.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A fizetési időkeret (30 perc) lejárt, mielőtt elindította volna a fizetést. '
                    'A tranzakció nem jött létre, így bankkártyája nem lett terhelve.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  // Biztosítás box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user,
                            color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Biztosítjuk: Nem történt pénzügyi terhelés.',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Gombok
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Bezárás'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          context.go('/account');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Új fizetés indítása'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Megszakított fizetés dialóg (SimplePay 3.13.1 szerint - KÖTELEZŐ!)
  static void _showPaymentCancelledDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cím
                  Row(
                    children: [
                      Icon(Icons.cancel_outlined,
                          color: Colors.grey[600], size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Megszakított fizetés',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Tartalom
                  const Text(
                    'Ön megszakította a fizetést.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A fizetési folyamat megszakításra került (a "Vissza" gomb megnyomásával '
                    'vagy a böngésző bezárásával). A tranzakció nem jött létre.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  // Biztosítás box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user,
                            color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Biztosítjuk: Nem történt pénzügyi terhelés.',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Gombok
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Bezárás'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          context.go('/account');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Új fizetés indítása'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
