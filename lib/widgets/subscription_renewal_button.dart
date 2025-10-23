import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hybrid_payment_service.dart';
import '../services/subscription_reminder_service.dart';
import 'data_transfer_consent_dialog.dart';
import 'simplepay_logo.dart';

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

  String _formatDate(DateTime date) {
    return '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}.';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    // StreamBuilder a real-time ellenőrzéshez
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data?.data();
        if (data == null) {
          return const SizedBox.shrink();
        }

        // Állapot számítás
        final statusColor = _calculateStatusColor(data);
        final canRenew = _checkCanRenew(data);
        final blockReason = _getBlockReason(data);

        if (widget.showAsCard) {
          return _buildCardButton(statusColor, canRenew, blockReason);
        } else {
          return _buildSimpleButton(statusColor, canRenew, blockReason);
        }
      },
    );
  }

  SubscriptionStatusColor _calculateStatusColor(Map<String, dynamic> data) {
    final isActive = data['isSubscriptionActive'] ?? false;
    final status = data['subscriptionStatus'] ?? 'free';
    final endDateField = data['subscriptionEndDate'];

    if (!isActive || status == 'free') {
      return SubscriptionStatusColor.free;
    }

    if (status == 'expired') {
      return SubscriptionStatusColor.expired;
    }

    if (endDateField != null) {
      DateTime? endDate;
      if (endDateField is Timestamp) {
        endDate = endDateField.toDate();
      } else if (endDateField is String) {
        endDate = DateTime.parse(endDateField);
      }

      if (endDate != null) {
        final daysUntilExpiry = endDate.difference(DateTime.now()).inDays;
        if (daysUntilExpiry <= 3) {
          return SubscriptionStatusColor.warning;
        }
      }
    }

    return SubscriptionStatusColor.premium;
  }

  bool _checkCanRenew(Map<String, dynamic> data) {
    final isActive = data['isSubscriptionActive'] ?? false;
    final endDateField = data['subscriptionEndDate'];

    if (!isActive) {
      return true; // Lejárt vagy free esetén lehet megújítani
    }

    if (endDateField != null) {
      DateTime? endDate;
      if (endDateField is Timestamp) {
        endDate = endDateField.toDate();
      } else if (endDateField is String) {
        endDate = DateTime.parse(endDateField);
      }

      if (endDate != null) {
        final daysUntilExpiry = endDate.difference(DateTime.now()).inDays;
        return daysUntilExpiry <= 3; // Csak 3 napon belül
      }
    }

    return true;
  }

  String? _getBlockReason(Map<String, dynamic> data) {
    final isActive = data['isSubscriptionActive'] ?? false;
    final endDateField = data['subscriptionEndDate'];

    if (!isActive) {
      return null;
    }

    if (endDateField != null) {
      DateTime? endDate;
      if (endDateField is Timestamp) {
        endDate = endDateField.toDate();
      } else if (endDateField is String) {
        endDate = DateTime.parse(endDateField);
      }

      if (endDate != null) {
        final daysUntilExpiry = endDate.difference(DateTime.now()).inDays;
        if (daysUntilExpiry > 3) {
          return 'Az előfizetés megújítása csak 3 nappal a lejárat előtt lehetséges. Jelenlegi lejárat: ${_formatDate(endDate)}';
        }
      }
    }

    return null;
  }

  Widget _buildCardButton(
      SubscriptionStatusColor statusColor, bool canRenew, String? blockReason) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getButtonColor(statusColor).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getButtonColor(statusColor).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _getButtonIcon(statusColor),
            size: 48,
            color: _getButtonColor(statusColor),
          ),
          const SizedBox(height: 16),
          Text(
            _getButtonTitle(statusColor),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getButtonColor(statusColor),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getButtonDescription(statusColor),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(statusColor, canRenew, blockReason),
          ),

          // SimplePay logó csak webes platformon
          if (HybridPaymentService.isWeb) ...[
            const SizedBox(height: 16),
            const SimplePayLogoCompact(
              width: 120,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleButton(
      SubscriptionStatusColor statusColor, bool canRenew, String? blockReason) {
    return _buildActionButton(statusColor, canRenew, blockReason);
  }

  Widget _buildActionButton(
      SubscriptionStatusColor statusColor, bool canRenew, String? blockReason) {
    if (_isLoading) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getButtonColor(statusColor),
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

    // Premium előfizetés esetén gomb disabled, ha nem lehet még megújítani
    final isDisabled =
        statusColor == SubscriptionStatusColor.premium && !canRenew;

    return Tooltip(
      message: isDisabled ? (blockReason ?? '') : '',
      child: ElevatedButton.icon(
        onPressed: isDisabled ? null : _handleButtonPress,
        icon: Icon(_getButtonIcon(statusColor), size: 18),
        label: Text(widget.customText ?? _getButtonText(statusColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _getButtonColor(statusColor),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          disabledBackgroundColor: Colors.grey[400],
          disabledForegroundColor: Colors.grey[600],
        ),
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

      // WEB esetén: KÖTELEZŐ adattovábbítási nyilatkozat elfogadása
      if (HybridPaymentService.isWeb) {
        final consentAccepted = await DataTransferConsentDialog.show(context);
        if (!consentAccepted) {
          // Felhasználó nem fogadta el a nyilatkozatot
          _showError(
              'A fizetés folytatásához el kell fogadnia az adattovábbítási nyilatkozatot.');
          return;
        }

        // Firestore frissítése: consent elfogadás dátumának rögzítése
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'dataTransferConsentLastAcceptedDate': FieldValue.serverTimestamp(),
        });
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

        // Web esetén ugyanabban a fülben nyissuk meg (ne új ablakban)
        if (HybridPaymentService.isWeb) {
          final uri = Uri.parse(result.paymentUrl!);
          final launched = await launchUrl(
            uri,
            webOnlyWindowName: '_self',
          );
          if (!launched && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Payment URL: ${result.paymentUrl}')),
            );
          }
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

  // payment dialog removed; we launch using url_launcher directly

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
    final availablePlans = HybridPaymentService.getAvailablePlans();
    if (availablePlans.isNotEmpty) {
      return availablePlans.first.id;
    }

    // Fallback
    return 'monthly_premium_prepaid';
  }

  Color _getButtonColor(SubscriptionStatusColor statusColor) {
    switch (statusColor) {
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

  IconData _getButtonIcon(SubscriptionStatusColor statusColor) {
    switch (statusColor) {
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

  String _getButtonTitle(SubscriptionStatusColor statusColor) {
    switch (statusColor) {
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

  String _getButtonDescription(SubscriptionStatusColor statusColor) {
    switch (statusColor) {
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

  String _getButtonText(SubscriptionStatusColor statusColor) {
    switch (statusColor) {
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
