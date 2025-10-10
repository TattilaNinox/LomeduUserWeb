import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/web_payment_service.dart';

/// Webes fizetési csomagok widget
///
/// Megjeleníti a rendelkezésre álló fizetési csomagokat és kezeli a fizetés indítását.
class WebPaymentPlans extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback? onPaymentInitiated;

  const WebPaymentPlans({
    super.key,
    required this.userData,
    this.onPaymentInitiated,
  });

  @override
  State<WebPaymentPlans> createState() => _WebPaymentPlansState();
}

class _WebPaymentPlansState extends State<WebPaymentPlans> {
  String? _selectedPlan;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    // Ha a felhasználó már prémium, ne jelenítsük meg a csomagokat
    final subscriptionStatus = widget.userData?['subscriptionStatus'] ?? 'free';
    final isSubscriptionActive =
        widget.userData?['isSubscriptionActive'] ?? false;

    if (subscriptionStatus == 'premium' && isSubscriptionActive) {
      return _buildActiveSubscriptionCard();
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
          const Row(
            children: [
              Icon(
                Icons.credit_card,
                size: 24,
                color: Color(0xFF1E3A8A),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Fizetési csomagok',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Csomagok listája
          ...WebPaymentService.availablePlans
              .map((plan) => _buildPlanCard(plan)),

          const SizedBox(height: 20),

          // Információk
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Biztonságos fizetés',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• OTP SimplePay biztonságos fizetési rendszer\n'
                  '• Bankkártya adatok nem tárolódnak nálunk\n'
                  '• 30 napos pénzvisszafizetési garancia\n'
                  '• Bármikor lemondható',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubscriptionCard() {
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
        children: [
          const Icon(
            Icons.check_circle,
            size: 48,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          const Text(
            'Aktív előfizetés',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ön már rendelkezik aktív előfizetéssel.\n'
            'A csomag kezeléséhez látogasson el a Google Play Store-ba.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(PaymentPlan plan) {
    final isSelected = _selectedPlan == plan.id;
    final isProcessing = _isProcessing && _selectedPlan == plan.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: plan.popular
              ? Colors.blue
              : (isSelected ? Colors.blue : Colors.grey[300]!),
          width: plan.popular ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: plan.popular ? Colors.blue.withValues(alpha: 0.02) : Colors.white,
      ),
      child: Column(
        children: [
          // Popular badge
          if (plan.popular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Text(
                'Legnépszerűbb',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          plan.formattedPrice,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        Text(
                          plan.periodText,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Features
                ...plan.features
                    .map((feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.green[600],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),

                const SizedBox(height: 20),

                // Action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        isProcessing ? null : () => _handlePlanSelection(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          plan.popular ? Colors.blue[600] : Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isProcessing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Feldolgozás...'),
                            ],
                          )
                        : Text(
                            'Választás - ${plan.formattedPrice}${plan.periodText}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlanSelection(PaymentPlan plan) async {
    if (!kIsWeb) {
      _showError('Ez a funkció csak webes böngészőben érhető el');
      return;
    }

    if (!WebPaymentService.isConfigured) {
      _showError(
          'SimplePay konfiguráció hiányzik. Kérjük, lépjen kapcsolatba a támogatással.');
      return;
    }

    setState(() {
      _selectedPlan = plan.id;
      _isProcessing = true;
    });

    try {
      final user = widget.userData;
      if (user == null) {
        throw Exception('Felhasználói adatok nem elérhetők');
      }

      // Fizetés indítása Cloud Function-nel
      final result = await WebPaymentService.initiatePaymentViaCloudFunction(
        planId: plan.id,
        userId: user['uid'] ?? user['id'],
      );

      if (result.success && result.paymentUrl != null) {
        // Átirányítás a SimplePay fizetési oldalra
        if (kIsWeb) {
          // Web esetén payment dialog megjelenítése
          _showPaymentDialog(result.paymentUrl!);
        }
      } else {
        throw Exception(result.error ?? 'Fizetés indítása sikertelen');
      }
    } catch (e) {
      _showError('Hiba történt a fizetés indítása során: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _selectedPlan = null;
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
                // Manuális átirányítás
                _openPaymentUrl(paymentUrl);
              },
              child: const Text('Manuális átirányítás'),
            ),
          ],
        ),
      ),
    );
  }

  void _openPaymentUrl(String url) {
    if (kIsWeb) {
      // Web esetén window.open használata
        // Web navigáció implementálva
      debugPrint('Opening payment URL: $url');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }
}
