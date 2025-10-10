import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/subscription_reminder_service.dart';

/// Fejlesztett előfizetési státusz kártya widget
///
/// Megjeleníti a felhasználó előfizetési állapotát hátralévő napokkal,
/// emlékeztetőkkel és megújítási lehetőségekkel.
class EnhancedSubscriptionStatusCard extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback? onRefresh;
  final VoidCallback? onRenewPressed;

  const EnhancedSubscriptionStatusCard({
    super.key,
    required this.userData,
    this.onRefresh,
    this.onRenewPressed,
  });

  @override
  State<EnhancedSubscriptionStatusCard> createState() =>
      _EnhancedSubscriptionStatusCardState();
}

class _EnhancedSubscriptionStatusCardState
    extends State<EnhancedSubscriptionStatusCard> {
  SubscriptionStatusColor _statusColor = SubscriptionStatusColor.free;
  int? _daysUntilExpiry;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final statusColor =
          await SubscriptionReminderService.getSubscriptionStatusColor(
              user.uid);
      final daysUntilExpiry =
          await SubscriptionReminderService.getDaysUntilExpiry(user.uid);

      setState(() {
        _statusColor = statusColor;
        _daysUntilExpiry = daysUntilExpiry;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingCard();
    }

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
              Icon(
                _getStatusIcon(),
                size: 24,
                color: _getStatusColor(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Előfizetési állapot',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                    if (widget.userData != null)
                      Text(
                        widget.userData!['email'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              // Státusz badge eltávolítva a fejlécből
            ],
          ),

          const SizedBox(height: 24),

          // Státusz leírás
          _buildStatusDescription(),

          const SizedBox(height: 20),

          // Előfizetési részletek
          if (widget.userData != null) ...[
            _buildSubscriptionDetails(),
            const SizedBox(height: 20),
          ],

          // Ár információ
          _buildPriceInfo(),

          // Hátralévő napok számláló
          if (_daysUntilExpiry != null && _daysUntilExpiry! > 0) ...[
            _buildDaysCounter(),
            const SizedBox(height: 20),
          ],

          // Akció gombok
          _buildActionButtons(),
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


  Widget _buildStatusDescription() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor().withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: _getStatusColor(), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusColor.description,
              style: TextStyle(
                color: _getStatusColor(),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionDetails() {
    final data = widget.userData!;
    final subscriptionEndDate = data['subscriptionEndDate'];
    final subscription = data['subscription'] as Map<String, dynamic>?;
    final lastPaymentDate = data['lastPaymentDate'];

    return Column(
      children: [
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
      ],
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

  Widget _buildDaysCounter() {
    if (_daysUntilExpiry == null || _daysUntilExpiry! <= 0) {
      return const SizedBox.shrink();
    }

    Color counterColor;
    String counterText;

    if (_daysUntilExpiry! > 7) {
      counterColor = Colors.green;
      counterText = 'Hátralévő napok: $_daysUntilExpiry nap';
    } else if (_daysUntilExpiry! > 3) {
      counterColor = Colors.orange;
      counterText = 'Hátralévő napok: $_daysUntilExpiry nap';
    } else {
      counterColor = Colors.red;
      counterText = 'Hátralévő napok: $_daysUntilExpiry nap';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: counterColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: counterColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: counterColor, size: 20),
          const SizedBox(width: 8),
          Text(
            counterText,
            style: TextStyle(
              color: counterColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceInfo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Havi előfizetés',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '4,350 Ft / hó',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (_statusColor == SubscriptionStatusColor.expired) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onRenewPressed,
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('Előfizetés megújítása'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ] else if (_statusColor == SubscriptionStatusColor.free) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onRenewPressed,
              icon: const Icon(Icons.upgrade, size: 18),
              label: const Text('Premium előfizetés'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ] else if (_statusColor == SubscriptionStatusColor.warning) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onRenewPressed,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Előfizetés megújítása'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              await _loadSubscriptionStatus();
              widget.onRefresh?.call();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Frissítés'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon() {
    switch (_statusColor) {
      case SubscriptionStatusColor.free:
        return Icons.free_breakfast;
      case SubscriptionStatusColor.premium:
        return Icons.check_circle;
      case SubscriptionStatusColor.warning:
        return Icons.warning;
      case SubscriptionStatusColor.expired:
        return Icons.error;
    }
  }

  Color _getStatusColor() {
    switch (_statusColor) {
      case SubscriptionStatusColor.free:
        return Colors.blue;
      case SubscriptionStatusColor.premium:
        return Colors.green;
      case SubscriptionStatusColor.warning:
        return Colors.orange;
      case SubscriptionStatusColor.expired:
        return Colors.red;
    }
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
