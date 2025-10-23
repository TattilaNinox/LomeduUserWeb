import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum SubscriptionStatusColor {
  free,
  premium,
  warning,
  expired;

  String get description {
    switch (this) {
      case SubscriptionStatusColor.free:
        return 'Jelenleg az ingyenes verziót használod.';
      case SubscriptionStatusColor.premium:
        return 'Prémium előfizetésed aktív.';
      case SubscriptionStatusColor.warning:
        return 'Előfizetésed hamarosan lejár!';
      case SubscriptionStatusColor.expired:
        return 'Előfizetésed lejárt.';
    }
  }
}

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

  @override
  void initState() {
    super.initState();
    _recomputeFromUserData();
  }

  @override
  void didUpdateWidget(covariant EnhancedSubscriptionStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userData != widget.userData) {
      _recomputeFromUserData();
    }
  }

  void _recomputeFromUserData() {
    final data = widget.userData;
    if (data == null) return;

    try {
      final String subscriptionStatus = data['subscriptionStatus'] ?? 'free';
      final bool isSubscriptionActive = data['isSubscriptionActive'] ?? false;
      final dynamic subscriptionEndDate = data['subscriptionEndDate'];

      int? daysUntilExpiry;
      if (subscriptionEndDate != null) {
        DateTime endDateTime;
        if (subscriptionEndDate is Timestamp) {
          endDateTime = subscriptionEndDate.toDate();
        } else if (subscriptionEndDate is String) {
          endDateTime = DateTime.parse(subscriptionEndDate);
        } else {
          endDateTime = DateTime.now();
        }
        final now = DateTime.now();
        daysUntilExpiry = endDateTime.difference(now).inDays;
      }

      SubscriptionStatusColor color;
      if (subscriptionStatus == 'premium' && isSubscriptionActive) {
        if (daysUntilExpiry != null) {
          if (daysUntilExpiry <= 3 && daysUntilExpiry > 0) {
            color = SubscriptionStatusColor.warning;
          } else if (daysUntilExpiry > 3) {
            color = SubscriptionStatusColor.premium;
          } else {
            color = SubscriptionStatusColor.expired;
          }
        } else {
          color = SubscriptionStatusColor.premium;
        }
      } else if (subscriptionStatus == 'expired' ||
          (!isSubscriptionActive && subscriptionStatus == 'premium')) {
        color = SubscriptionStatusColor.expired;
      } else {
        color = SubscriptionStatusColor.free;
      }

      setState(() {
        _statusColor = color;
        _daysUntilExpiry = daysUntilExpiry;
      });
    } catch (_) {
      // hagyjuk az alapértékeket
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userData == null) {
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
      counterColor = Colors.lightBlue[600]!;
      counterText = 'Hátralévő napok: $_daysUntilExpiry nap';
    } else {
      counterColor = Colors.deepOrange[600]!;
      counterText = 'Hátralévő napok: $_daysUntilExpiry nap';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: counterColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: counterColor.withValues(alpha: 0.3)),
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
          // Kattintható info ikon
          InkWell(
            onTap: () => _showSubscriptionInfoDialog(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child:
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '30 napos előfizetés',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '4,350 Ft / 30 nap',
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

  /// Előfizetési folyamat tájékoztató dialog
  void _showSubscriptionInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.credit_card, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Előfizetési folyamat',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoStep(
                '1',
                '30 napos előfizetés',
                'Egy csomag érhető el: 30 napos teljes hozzáférés minden prémium funkcióhoz 4,350 Ft-ért.',
              ),
              const SizedBox(height: 16),
              _buildInfoStep(
                '2',
                'Biztonságos fizetés',
                'A fizetés az OTP SimplePay biztonságos rendszerén keresztül történik. Bankkártya adatai titkosítva kerülnek továbbításra.',
              ),
              const SizedBox(height: 16),
              _buildInfoStep(
                '3',
                'Azonnali aktiválás',
                'Sikeres fizetés után előfizetése azonnal aktiválódik és 30 napig érvényes.',
              ),
              const SizedBox(height: 16),
              _buildInfoStep(
                '4',
                'Manuális megújítás',
                'Az előfizetés NEM újul meg automatikusan. A megújítási gombot 3 nappal a lejárat előtt aktiváljuk, hogy Ön dönthessen a folytatásról.',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Biztonság és adatvédelem',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Bankkártya adatok nem tárolódnak nálunk\n'
                      '• Biztonságos SSL titkosítás\n'
                      '• Csak akkor fizet, ha Ön megújítja',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fontos: Az előfizetés lejárta után azonnal megszűnik a prémium hozzáférés. Megújításhoz újra fizetnie kell.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Bezárás'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Eltávolítottuk a korábbi, teljes szélességű akciógombokat.

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
        return Colors
            .lightBlue[600]!; // Világos kék a hamarosan lejáró előfizetéshez
      case SubscriptionStatusColor.expired:
        return Colors.deepOrange[600]!; // Barátságosabb narancs árnyalat
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
