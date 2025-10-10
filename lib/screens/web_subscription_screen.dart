import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../services/web_payment_service.dart';
import '../widgets/web_subscription_status_card.dart';
import '../widgets/web_payment_plans.dart';
import '../widgets/web_payment_history.dart';

/// Webes előfizetési képernyő Flutter Web alkalmazáshoz
///
/// Ez a képernyő kezeli a webes fizetési folyamatokat OTP SimplePay integrációval.
/// Kompatibilis a meglévő Google Play Billing rendszerrel.
class WebSubscriptionScreen extends StatefulWidget {
  const WebSubscriptionScreen({super.key});

  @override
  State<WebSubscriptionScreen> createState() => _WebSubscriptionScreenState();
}

class _WebSubscriptionScreenState extends State<WebSubscriptionScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      _user = _auth.currentUser;
      if (_user != null) {
        await _loadUserData();
      }
    } catch (e) {
      setState(() {
        _error = 'Hiba történt a felhasználói adatok betöltése során: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();

      if (doc.exists) {
        setState(() {
          _userData = doc.data();
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Hiba történt a felhasználói adatok betöltése során: $e';
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _loadUserData();

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Előfizetés kezelése'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Előfizetés kezelése'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Újrapróbálás'),
              ),
            ],
          ),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Előfizetés kezelése'),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Kérjük, jelentkezzen be a folytatáshoz',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Bejelentkezés'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Előfizetés kezelése'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Adatok frissítése',
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Előfizetés kezelése',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kezelje előfizetését és fizetési adatait egy helyen',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // SimplePay konfiguráció státusz
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: WebPaymentService.isConfigured
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: WebPaymentService.isConfigured
                              ? Colors.green
                              : Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            WebPaymentService.isConfigured
                                ? Icons.check_circle
                                : Icons.warning,
                            color: WebPaymentService.isConfigured
                                ? Colors.green
                                : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              WebPaymentService.configurationStatus,
                              style: TextStyle(
                                color: WebPaymentService.isConfigured
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Előfizetési státusz és fizetési csomagok
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Előfizetési státusz (2/3 szélesség)
                  Expanded(
                    flex: 2,
                    child: WebSubscriptionStatusCard(
                      userData: _userData,
                      onRefresh: _refreshData,
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Fizetési csomagok (1/3 szélesség)
                  Expanded(
                    flex: 1,
                    child: WebPaymentPlans(
                      userData: _userData,
                      onPaymentInitiated: _refreshData,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Fizetési előzmények
              WebPaymentHistory(
                userData: _userData,
                onRefresh: _refreshData,
              ),

              const SizedBox(height: 24),

              // Információk
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fizetési információk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• A fizetés OTP SimplePay-en keresztül történik\n'
                      '• Biztonságos bankkártyás fizetés\n'
                      '• Bármikor lemondható\n'
                      '• 30 napos pénzvisszafizetési garancia\n'
                      '• A webes és mobil előfizetések együtt működnek',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF374151),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
