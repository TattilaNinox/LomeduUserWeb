import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Webes előfizetési státusz kártya widget
///
/// Megjeleníti a felhasználó előfizetési állapotát és kezeli a frissítést.
class WebSubscriptionStatusCard extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback? onRefresh;

  const WebSubscriptionStatusCard({
    super.key,
    required this.userData,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return _buildLoadingCard();
    }

    final subscriptionStatus = userData!['subscriptionStatus'] ?? 'free';
    final isSubscriptionActive = userData!['isSubscriptionActive'] ?? false;
    final subscriptionEndDate = userData!['subscriptionEndDate'];
    final subscription = userData!['subscription'] as Map<String, dynamic>?;
    final lastPaymentDate = userData!['lastPaymentDate'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.account_circle,
                size: 24,
                color: Color(0xFF1E3A8A),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Előfizetési állapot',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    Text(
                      userData!['email'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Státusz badge
              _buildStatusBadge(subscriptionStatus, isSubscriptionActive),
            ],
          ),

          const SizedBox(height: 24),

          // Státusz leírás
          _buildStatusDescription(subscriptionStatus, isSubscriptionActive),

          const SizedBox(height: 20),

          // Előfizetési részletek
          if (subscriptionEndDate != null) ...[
            _buildDetailRow(
              'Lejárati dátum',
              _formatDate(subscriptionEndDate),
              Icons.calendar_today,
            ),
            const SizedBox(height: 12),
          ],

          if (subscription != null) ...[
            _buildDetailRow(
              'Fizetési forrás',
              _getSourceText(subscription['source']),
              Icons.payment,
            ),
            const SizedBox(height: 12),
          ],

          if (lastPaymentDate != null) ...[
            _buildDetailRow(
              'Utolsó fizetés',
              _formatDate(lastPaymentDate),
              Icons.history,
            ),
            const SizedBox(height: 12),
          ],

          // Hátralévő napok számítása
          if (subscriptionEndDate != null && isSubscriptionActive) ...[
            _buildRemainingDays(subscriptionEndDate),
            const SizedBox(height: 20),
          ],

          // Akció gombok eltávolítva - a megújítási gombok a fő képernyőn jelennek meg
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Adatok betöltése...'),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isActive) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    if (status == 'premium' && isActive) {
      backgroundColor = Colors.green;
      textColor = Colors.white;
      text = 'Aktív Premium';
      icon = Icons.check_circle;
    } else if (status == 'expired' || (!isActive && status == 'premium')) {
      backgroundColor =
          Colors.deepOrange[600]!; // Barátságosabb narancs árnyalat
      textColor = Colors.white;
      text = 'Lejárt';
      icon = Icons.warning;
    } else if (status == 'free') {
      backgroundColor = Colors.blue;
      textColor = Colors.white;
      text = 'Ingyenes';
      icon = Icons.free_breakfast;
    } else {
      backgroundColor = Colors.grey;
      textColor = Colors.white;
      text = 'Ismeretlen';
      icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDescription(String status, bool isActive) {
    String description;
    Color color;

    if (status == 'premium' && isActive) {
      description = 'Előfizetése aktív és minden funkció elérhető';
      color = Colors.green[700]!;
    } else if (status == 'expired' || (!isActive && status == 'premium')) {
      description = 'Előfizetése lejárt, frissítse a fizetést a folytatáshoz';
      color = Colors.deepOrange[600]!;
    } else if (status == 'free') {
      description = 'Korlátozott funkciók elérhetők';
      color = Colors.blue[700]!;
    } else {
      description = 'Nem sikerült meghatározni az előfizetési állapotot';
      color = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemainingDays(dynamic endDate) {
    try {
      DateTime endDateTime;
      if (endDate is Timestamp) {
        endDateTime = endDate.toDate();
      } else if (endDate is String) {
        endDateTime = DateTime.parse(endDate);
      } else {
        return const SizedBox.shrink();
      }

      final now = DateTime.now();
      final difference = endDateTime.difference(now);
      final days = difference.inDays;

      if (days > 0) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Hátralévő napok: $days nap',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Hiba esetén ne jelenítsen meg semmit
    }

    return const SizedBox.shrink();
  }

  String _formatDate(dynamic date) {
    try {
      DateTime dateTime;
      if (date is Timestamp) {
        dateTime = date.toDate();
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else {
        return 'N/A';
      }

      return DateFormat('yyyy. MMMM dd.', 'hu').format(dateTime);
    } catch (e) {
      return 'N/A';
    }
  }

  String _getSourceText(String? source) {
    switch (source) {
      case 'google_play':
        return 'Google Play Store';
      case 'otp_simplepay':
        return 'OTP SimplePay';
      case 'registration_trial':
        return 'Regisztrációs próbaidő';
      default:
        return source ?? 'Ismeretlen';
    }
  }
}
