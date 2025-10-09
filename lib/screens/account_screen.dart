import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
          final subsStatus = data['subscriptionStatus'] ?? 'free';
          final isActive = data['isSubscriptionActive'] ?? false;
          final endDateTs = data['subscriptionEndDate'];
          DateTime? endDate;
          if (endDateTs is Timestamp) endDate = endDateTs.toDate();

          final df = DateFormat.yMMMMd('hu');
          String endDateStr = endDate != null ? df.format(endDate) : 'nincs';
          Timestamp? lastPayTs = data['lastPaymentDate'];
          DateTime? lastPay;
          if (lastPayTs is Timestamp) lastPay = lastPayTs.toDate();
          String lastPayStr = lastPay != null ? df.format(lastPay) : '—';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Card(
                  child: ListTile(
                    title: Text(
                        '${data['lastName'] ?? ''} ${data['firstName'] ?? ''}'
                            .trim()),
                    subtitle: Text(user.email ?? ''),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('Előfizetés'),
                    subtitle: Text(isActive ? 'Aktív' : 'Inaktív'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Státusz: $subsStatus'),
                        Text('Lejár: $endDateStr'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('Utolsó fizetés'),
                    trailing: Text(lastPayStr),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement upgrade/payment flow
                  },
                  child: const Text('Előfizetés frissítése'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
