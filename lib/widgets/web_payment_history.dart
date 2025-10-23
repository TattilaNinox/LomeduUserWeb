import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/web_payment_service.dart';

/// Webes fizetési előzmények widget
///
/// Megjeleníti a felhasználó fizetési előzményeit.
class WebPaymentHistory extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback? onRefresh;

  const WebPaymentHistory({
    super.key,
    required this.userData,
    this.onRefresh,
  });

  @override
  State<WebPaymentHistory> createState() => _WebPaymentHistoryState();
}

class _WebPaymentHistoryState extends State<WebPaymentHistory> {
  List<PaymentHistoryItem> _payments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    if (widget.userData == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = widget.userData!['uid'] ?? widget.userData!['id'];
      if (userId == null) {
        throw Exception('Felhasználói azonosító nem elérhető');
      }

      final payments = await WebPaymentService.getPaymentHistory(userId);
      setState(() {
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Icons.history,
                size: 24,
                color: Color(0xFF1E3A8A),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Fizetési előzmények',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadPaymentHistory,
                icon: const Icon(Icons.refresh),
                tooltip: 'Frissítés',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Content
          if (_isLoading)
            _buildLoadingState()
          else if (_error != null)
            _buildErrorState()
          else if (_payments.isEmpty)
            _buildEmptyState()
          else
            _buildPaymentsList(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Fizetési előzmények betöltése...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Hiba történt az adatok betöltése során',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.red[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPaymentHistory,
            child: const Text('Újrapróbálás'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Még nincsenek fizetési előzmények',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Az első vásárlás után itt jelennek meg a részletek',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList() {
    return Column(
      children: [
        // Desktop table view
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 768) {
              return _buildDesktopTable();
            } else {
              return _buildMobileList();
            }
          },
        ),

        const SizedBox(height: 16),

        // Footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_payments.length} fizetés található',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Export funkció (jövőbeli fejlesztés)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export funkció hamarosan elérhető'),
                    ),
                  );
                },
                child: const Text('Exportálás'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Dátum',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Leírás',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Összeg',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Státusz',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Műveletek',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rows
          ..._payments.map((payment) => _buildTableRow(payment)),
        ],
      ),
    );
  }

  Widget _buildTableRow(PaymentHistoryItem payment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(payment.createdAt),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _getPlanName(payment.planId),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              payment.formattedAmount,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: _buildStatusChip(payment.status),
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                // Query státusz gomb
                if (payment.status != 'completed')
                  IconButton(
                    onPressed: () => _queryPaymentStatus(payment.orderRef),
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Státusz ellenőrzése',
                    padding: EdgeInsets.zero,
                  ),
                // Számla gomb
                if (payment.status == 'completed')
                  TextButton(
                    onPressed: () {
                      // Számla letöltés (jövőbeli fejlesztés)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Számla letöltése hamarosan elérhető'),
                        ),
                      );
                    },
                    child: const Text('Számla'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList() {
    return Column(
      children: _payments.map((payment) => _buildMobileCard(payment)).toList(),
    );
  }

  Widget _buildMobileCard(PaymentHistoryItem payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getPlanName(payment.planId),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildStatusChip(payment.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(payment.createdAt),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                payment.formattedAmount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Query státusz gomb
              if (payment.status != 'completed')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _queryPaymentStatus(payment.orderRef),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Státusz ellenőrzése'),
                  ),
                ),
              // Számla gomb
              if (payment.status == 'completed')
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      // Számla letöltés (jövőbeli fejlesztés)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Számla letöltése hamarosan elérhető'),
                        ),
                      );
                    },
                    child: const Text('Számla letöltése'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (status) {
      case 'completed':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        text = 'Sikeres';
        break;
      case 'pending':
        backgroundColor = Colors.yellow[100]!;
        textColor = Colors.yellow[800]!;
        text = 'Folyamatban';
        break;
      case 'failed':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        text = 'Sikertelen';
        break;
      case 'cancelled':
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
        text = 'Lemondva';
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
        text = 'Ismeretlen';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy. MMMM dd. HH:mm', 'hu').format(date);
  }

  String _getPlanName(String planId) {
    switch (planId) {
      case 'monthly_premium_prepaid':
        return 'Havi előfizetés';
      case 'monthly_web':
        return 'Havi előfizetés';
      case 'yearly_web':
        return 'Éves előfizetés';
      default:
        return planId;
    }
  }

  /// Fizetési státusz lekérdezése SimplePay Query API-val
  Future<void> _queryPaymentStatus(String orderRef) async {
    // Loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Fizetési státusz lekérdezése...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('queryPaymentStatus');

      final result = await callable.call({'orderRef': orderRef});
      final data = result.data as Map<String, dynamic>;

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (data['success'] == true) {
        final status = data['status'] as String? ?? 'UNKNOWN';
        final localStatus = data['localStatus'] as String? ?? 'unknown';
        final transactionId = data['transactionId'] as String?;

        // Eredmény dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Fizetési státusz'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow('SimplePay státusz', status),
                const SizedBox(height: 8),
                _buildStatusRow('Helyi státusz', localStatus),
                if (transactionId != null) ...[
                  const SizedBox(height: 8),
                  _buildStatusRow('Tranzakció ID', transactionId),
                ],
                const SizedBox(height: 16),
                Text(
                  status == 'SUCCESS'
                      ? 'A fizetés sikeresen megtörtént!'
                      : 'A fizetés még nem fejeződött be vagy sikertelen volt.',
                  style: TextStyle(
                    color: status == 'SUCCESS'
                        ? Colors.green[700]
                        : Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _loadPaymentHistory(); // Frissítjük a listát
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Sikertelen lekérdezés');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hiba történt: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(value),
      ],
    );
  }
}
