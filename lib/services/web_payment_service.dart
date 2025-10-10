import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Flutter Web payment service OTP SimplePay v2 API integrációval
///
/// Ez a service kezeli a webes fizetési folyamatokat a SimplePay v2 API-val.
/// Kompatibilis a meglévő Google Play Billing rendszerrel.
class WebPaymentService {
  static const String _baseUrl = 'https://secure.simplepay.hu/payment/v2/';
  static const String _sandboxUrl = 'https://sandbox.simplepay.hu/payment/v2/';

  // Environment változók (build-time injection)
  static const String _merchantId =
      String.fromEnvironment('SIMPLEPAY_MERCHANT_ID', defaultValue: '');
  static const String _secretKey =
      String.fromEnvironment('SIMPLEPAY_SECRET_KEY', defaultValue: '');
  static const bool _isProduction =
      bool.fromEnvironment('PRODUCTION', defaultValue: false);

  static String get _apiBaseUrl => _isProduction ? _baseUrl : _sandboxUrl;

  /// Fizetési csomagok definíciója
  static const Map<String, PaymentPlan> _plans = {
    'monthly_web': PaymentPlan(
      id: 'monthly_web',
      name: 'Havi előfizetés',
      price: 4350,
      period: 'hó',
      description: 'Teljes hozzáférés minden funkcióhoz',
      features: [
        'Korlátlan jegyzet hozzáférés',
        'Interaktív kvízek',
        'Flashcard csomagok',
        'Audio tartalmak',
        'Offline letöltés',
        'Elsődleges támogatás'
      ],
      subscriptionDays: 30,
      popular: true,
    ),
  };

  /// Fizetési csomagok lekérése
  static List<PaymentPlan> get availablePlans => _plans.values.toList();

  /// Fizetés indítása SimplePay v2 API-val
  static Future<PaymentInitiationResult> initiatePayment({
    required String planId,
    required String userId,
    String? customerEmail,
    String? customerName,
  }) async {
    try {
      // Plan validálás
      final plan = _plans[planId];
      if (plan == null) {
        throw PaymentException('Érvénytelen csomag: $planId');
      }

      // Environment változók ellenőrzése
      if (_merchantId.isEmpty || _secretKey.isEmpty) {
        throw PaymentException(
            'SimplePay konfiguráció hiányzik. Ellenőrizze az environment változókat.');
      }

      // Felhasználó adatok lekérése
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw PaymentException('Nincs bejelentkezett felhasználó');
      }

      final email = customerEmail ?? user.email;
      final name = customerName ?? user.displayName;

      if (email == null || email.isEmpty) {
        throw PaymentException('Email cím szükséges a fizetéshez');
      }

      // Egyedi rendelés azonosító generálása (userId-t tartalmazza)
      final orderRef =
          'WEB_${userId}_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';

      // SimplePay v2 API kérés összeállítása
      final request = SimplePayV2Request(
        merchant: _merchantId,
        orderRef: orderRef,
        customerEmail: email,
        customerName: name,
        language: 'HU',
        currency: 'HUF',
        total: plan.price,
        items: [
          SimplePayItem(
            ref: planId,
            title: plan.name,
            description: plan.description,
            amount: plan.price,
            price: plan.price,
            quantity: 1,
          ),
        ],
        methods: ['CARD'], // Bankkártya fizetés
        url: _getWebhookUrl(),
        timeout: _getTimeoutDate(),
        invoice: '1', // Számla generálás
        redirectUrl: _getSuccessUrl(),
      );

      // API hívás
      final response = await http.post(
        Uri.parse('${_apiBaseUrl}start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_secretKey',
          'User-Agent': 'Lomedu-Flutter-Web/1.0',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        return PaymentInitiationResult(
          success: true,
          paymentUrl: responseData['paymentUrl'] as String?,
          orderRef: orderRef,
          amount: plan.price,
          planId: planId,
        );
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        throw PaymentException(
            'SimplePay API hiba: ${errorData['message'] ?? 'Ismeretlen hiba'}');
      }
    } catch (e) {
      debugPrint('WebPaymentService: Payment initiation error: $e');
      return PaymentInitiationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Cloud Function hívás a fizetés indításához (alternatív megközelítés)
  static Future<PaymentInitiationResult> initiatePaymentViaCloudFunction({
    required String planId,
    required String userId,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('initiateWebPayment');

      final result = await callable.call({
        'planId': planId,
        'userId': userId,
      });

      final data = result.data as Map<String, dynamic>;

      return PaymentInitiationResult(
        success: data['success'] as bool,
        paymentUrl: data['paymentUrl'] as String?,
        orderRef: data['orderRef'] as String?,
        amount: data['amount'] as int?,
        planId: planId,
        error: data['error'] as String?,
      );
    } catch (e) {
      debugPrint('WebPaymentService: Cloud Function error: $e');
      return PaymentInitiationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Fizetési előzmények lekérése
  static Future<List<PaymentHistoryItem>> getPaymentHistory(
      String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('web_payments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PaymentHistoryItem(
          id: doc.id,
          orderRef: data['orderRef'] as String? ?? '',
          amount: data['amount'] as int? ?? 0,
          status: data['status'] as String? ?? 'unknown',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          planId: data['planId'] as String? ?? '',
          transactionId: data['transactionId'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('WebPaymentService: Error fetching payment history: $e');
      return [];
    }
  }

  /// Webhook feldolgozás (Cloud Function-ben fog futni)
  static Future<bool> processWebhook(Map<String, dynamic> webhookData) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('processWebPaymentWebhook');

      final result = await callable.call(webhookData);
      final data = result.data as Map<String, dynamic>;

      return data['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('WebPaymentService: Webhook processing error: $e');
      return false;
    }
  }

  /// Helper metódusok
  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
        length, (index) => chars[(random + index) % chars.length]).join();
  }

  static String _getWebhookUrl() {
    if (kIsWeb) {
      // Web esetén a jelenlegi domain + webhook path
      return '${Uri.base.origin}/api/webhook/simplepay';
    } else {
      // Mobilon nincs webhook
      return '';
    }
  }

  static String _getSuccessUrl() {
    if (kIsWeb) {
      return '${Uri.base.origin}/subscription?success=true';
    } else {
      return '';
    }
  }

  static String _getTimeoutDate() {
    // 30 perc timeout
    final timeout = DateTime.now().add(const Duration(minutes: 30));
    return timeout.toIso8601String();
  }

  /// Konfiguráció ellenőrzése
  static bool get isConfigured =>
      _merchantId.isNotEmpty && _secretKey.isNotEmpty;

  static String get configurationStatus {
    if (_merchantId.isEmpty) return 'SIMPLEPAY_MERCHANT_ID hiányzik';
    if (_secretKey.isEmpty) return 'SIMPLEPAY_SECRET_KEY hiányzik';
    return 'Konfigurálva (${_isProduction ? 'Production' : 'Sandbox'})';
  }
}

/// Fizetési csomag modell
class PaymentPlan {
  final String id;
  final String name;
  final int price;
  final String period;
  final String description;
  final List<String> features;
  final int subscriptionDays;
  final bool popular;

  const PaymentPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.period,
    required this.description,
    required this.features,
    required this.subscriptionDays,
    this.popular = false,
  });

  String get formattedPrice =>
      '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} Ft';

  String get periodText => '/$period';
}

/// Fizetés indítási eredmény
class PaymentInitiationResult {
  final bool success;
  final String? paymentUrl;
  final String? orderRef;
  final int? amount;
  final String? planId;
  final String? error;

  const PaymentInitiationResult({
    required this.success,
    this.paymentUrl,
    this.orderRef,
    this.amount,
    this.planId,
    this.error,
  });
}

/// Fizetési előzmény elem
class PaymentHistoryItem {
  final String id;
  final String orderRef;
  final int amount;
  final String status;
  final DateTime createdAt;
  final String planId;
  final String? transactionId;

  const PaymentHistoryItem({
    required this.id,
    required this.orderRef,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.planId,
    this.transactionId,
  });

  String get formattedAmount =>
      '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} Ft';

  String get statusText {
    switch (status) {
      case 'completed':
        return 'Sikeres';
      case 'pending':
        return 'Folyamatban';
      case 'failed':
        return 'Sikertelen';
      case 'cancelled':
        return 'Lemondva';
      default:
        return 'Ismeretlen';
    }
  }
}

/// SimplePay v2 API kérés modell
class SimplePayV2Request {
  final String merchant;
  final String orderRef;
  final String customerEmail;
  final String? customerName;
  final String language;
  final String currency;
  final int total;
  final List<SimplePayItem> items;
  final List<String> methods;
  final String url;
  final String timeout;
  final String invoice;
  final String redirectUrl;

  const SimplePayV2Request({
    required this.merchant,
    required this.orderRef,
    required this.customerEmail,
    this.customerName,
    required this.language,
    required this.currency,
    required this.total,
    required this.items,
    required this.methods,
    required this.url,
    required this.timeout,
    required this.invoice,
    required this.redirectUrl,
  });

  Map<String, dynamic> toJson() => {
        'merchant': merchant,
        'orderRef': orderRef,
        'customerEmail': customerEmail,
        if (customerName != null) 'customerName': customerName,
        'language': language,
        'currency': currency,
        'total': total,
        'items': items.map((item) => item.toJson()).toList(),
        'methods': methods,
        'url': url,
        'timeout': timeout,
        'invoice': invoice,
        'redirectUrl': redirectUrl,
      };
}

/// SimplePay v2 API item modell
class SimplePayItem {
  final String ref;
  final String title;
  final String description;
  final int amount;
  final int price;
  final int quantity;

  const SimplePayItem({
    required this.ref,
    required this.title,
    required this.description,
    required this.amount,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'title': title,
        'description': description,
        'amount': amount,
        'price': price,
        'quantity': quantity,
      };
}

/// Payment exception
class PaymentException implements Exception {
  final String message;
  const PaymentException(this.message);

  @override
  String toString() => 'PaymentException: $message';
}
