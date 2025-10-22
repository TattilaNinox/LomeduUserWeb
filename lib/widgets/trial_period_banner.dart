import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Egy bannert jelenít meg, ami a felhasználó ingyenes próbaidejéből hátralévő időt mutatja.
/// Csak akkor jelenik meg, ha a felhasználó ingyenes státuszban van és a próbaidőszaka még nem járt le.
class TrialPeriodBanner extends StatelessWidget {
  final Map<String, dynamic> userData;

  const TrialPeriodBanner({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final status = userData['subscriptionStatus'] as String?;
    final trialEndDate = userData['freeTrialEndDate'] as Timestamp?;

    // Csak akkor jelenítjük meg, ha a felhasználó "free" státuszban van
    // és a próbaidőszak lejárati dátuma a jövőben van.
    if (status != 'free' ||
        trialEndDate == null ||
        trialEndDate.toDate().isBefore(DateTime.now())) {
      return const SizedBox.shrink(); // Ne jelenítsen meg semmit
    }

    final daysLeft = trialEndDate.toDate().difference(DateTime.now()).inDays;

    // Ha kevesebb mint egy nap van hátra, 1 napot írunk ki.
    final displayDays = daysLeft < 1 ? 1 : daysLeft + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ingyenes próbaidőszakodból még $displayDays nap van hátra.',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



