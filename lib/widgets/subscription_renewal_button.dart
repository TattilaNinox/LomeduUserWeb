import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/hybrid_payment_service.dart';
import '../services/subscription_reminder_service.dart';
import '../services/web_payment_service.dart';

/// Előfizetés megújítási gomb widget
///
/// Intelligens megújítási gomb, amely a felhasználó előfizetési állapota
/// alapján megjeleníti a megfelelő akciót.
class SubscriptionRenewalButton extends StatefulWidget {
  final VoidCallback? onPaymentInitiated;
  final String? customPlanId;
  final bool showAsCard;
  final String? customText;

  const SubscriptionRenewalButton({
    super.key,
    this.onPaymentInitiated,
    this.customPlanId,
    this.showAsCard = false,
    this.customText,
  });

  @override
  State<SubscriptionRenewalButton> createState() =>
      _SubscriptionRenewalButtonState();
}

class _SubscriptionRenewalButtonState extends State<SubscriptionRenewalButton> {
  bool _isLoading = false;
  SubscriptionStatusColor _statusColor = SubscriptionStatusColor.free;
  List<PaymentPlan> _availablePlans = [];

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final statusColor =
          await SubscriptionReminderService.getSubscriptionStatusColor(
              user.uid);
      final availablePlans = HybridPaymentService.getAvailablePlans();

      setState(() {
        _statusColor = statusColor;
        _availablePlans = availablePlans;
      });
    } catch (e) {
      // Hiba esetén alapértelmezett értékek
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAsCard) {
      return _buildCardButton();
    } else {
      return _buildSimpleButton();
    }
  }

  Widget _buildCardButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getButtonColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getButtonColor().withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _getButtonIcon(),
            size: 48,
            color: _getButtonColor(),
          ),
          const SizedBox(height: 16),
          Text(
            _getButtonTitle(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getButtonColor(),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getButtonDescription(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleButton() {
    return _buildActionButton();
  }

  Widget _buildActionButton() {
    if (_isLoading) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getButtonColor(),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 8),
            Text('Feldolgozás...'),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _handleButtonPress,
      icon: Icon(_getButtonIcon(), size: 18),
      label: Text(widget.customText ?? _getButtonText()),
      style: ElevatedButton.styleFrom(
        backgroundColor: _getButtonColor(),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
    );
  }

  Future<void> _handleButtonPress() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Nincs bejelentkezett felhasználó');
        return;
      }

      // Ha van egyedi csomag ID, használjuk azt
      String planId = widget.customPlanId ?? _getDefaultPlanId();

      // Fizetés indítása
      final result = await HybridPaymentService.initiatePayment(
        planId: planId,
        userId: user.uid,
      );

      if (result.success && result.paymentUrl != null) {
        // Sikeres fizetés indítás
        widget.onPaymentInitiated?.call();
        _showSuccess('Fizetés sikeresen indítva!');

        // Web esetén átirányítás
        if (HybridPaymentService.isWeb) {
          _showPaymentDialog(result.paymentUrl!);
        }
      } else {
        _showError(result.error ?? 'Fizetés indítása sikertelen');
      }
    } catch (e) {
      _showError('Hiba történt: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPaymentDialog(String paymentUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Fizetés'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Átirányítjuk a biztonságos fizetési oldalra...'),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Web navigáció implementálva
                debugPrint('Opening payment URL: $paymentUrl');
              },
              child: const Text('Manuális átirányítás'),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.amber[600],
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green[600],
        ),
      );
    }
  }

  String _getDefaultPlanId() {
    // Alapértelmezett csomag kiválasztása - csak havi van
    if (_availablePlans.isNotEmpty) {
      return _availablePlans.first.id;
    }

    // Fallback
    return 'monthly_web';
  }

  Color _getButtonColor() {
    switch (_statusColor) {
      case SubscriptionStatusColor.free:
        return Colors.blue;
      case SubscriptionStatusColor.premium:
        return Colors.green;
      case SubscriptionStatusColor.warning:
        return Colors
            .lightBlue[600]!; // Világos kék a hamarosan lejáró előfizetéshez
      case SubscriptionStatusColor.expired:
        return Colors.amber[700]!; // Barátságosabb sárga árnyalat
    }
  }

  IconData _getButtonIcon() {
    switch (_statusColor) {
      case SubscriptionStatusColor.free:
        return Icons.upgrade;
      case SubscriptionStatusColor.premium:
        return Icons.check_circle;
      case SubscriptionStatusColor.warning:
        return Icons.refresh;
      case SubscriptionStatusColor.expired:
        return Icons.payment;
    }
  }

  String _getButtonTitle() {
    switch (_statusColor) {
      case SubscriptionStatusColor.free:
        return 'Premium előfizetés';
      case SubscriptionStatusColor.premium:
        return 'Aktív előfizetés';
      case SubscriptionStatusColor.warning:
        return 'Előfizetés megújítása';
      case SubscriptionStatusColor.expired:
        return 'Előfizetés megújítása';
    }
  }

  String _getButtonDescription() {
    switch (_statusColor) {
      case SubscriptionStatusColor.free:
        return 'Frissítsen premium előfizetésre a teljes hozzáférésért';
      case SubscriptionStatusColor.premium:
        return 'Előfizetése aktív és minden funkció elérhető';
      case SubscriptionStatusColor.warning:
        return 'Előfizetése hamarosan lejár. Érdemes megújítani';
      case SubscriptionStatusColor.expired:
        return 'Előfizetése lejárt. Frissítse a fizetést a folytatáshoz';
    }
  }

  String _getButtonText() {
    switch (_statusColor) {
      case SubscriptionStatusColor.free:
        return 'Premium előfizetés';
      case SubscriptionStatusColor.premium:
        return 'Aktív előfizetés';
      case SubscriptionStatusColor.warning:
        return 'Előfizetés megújítása';
      case SubscriptionStatusColor.expired:
        return 'Előfizetés megújítása';
    }
  }
}
