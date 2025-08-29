import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/sidebar.dart';

enum UserFilter { all, premium, trial, test, free }

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  UserFilter _selectedFilter = UserFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // science filter
  List<String> _sciences = [];
  String? _selectedScience;

  @override
  void initState() {
    super.initState();
    _loadSciences();
  }

  Future<void> _loadSciences() async {
    final snap = await FirebaseFirestore.instance.collection('sciences').get();
    final sciences =
        snap.docs.map((d) => (d['name'] as String? ?? '')).toList();
    sciences.sort();
    sciences.insert(0, 'Összes');
    setState(() {
      _sciences = sciences;
      // ensure default selection is 'Összes' (null = all)
      _selectedScience ??= 'Összes';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Felhasználók'),
      ),
      body: Row(
        children: [
          const Sidebar(selectedMenu: 'users'),
          Expanded(
            child: Column(
              children: [
                _buildStatsSection(),
                const Divider(),
                Expanded(
                  child: _buildUsersList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // science dropdown filter
          Row(
            children: [
              const Text('Tudomány:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedScience,
                hint: const Text('Összes'),
                items: _sciences
                    .map((s) =>
                        DropdownMenuItem<String>(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedScience = val),
              ),
              const Spacer(),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration:
                      const InputDecoration(labelText: 'Keresés név/email'),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              var docs = snapshot.data!.docs;
              if (_searchQuery.isNotEmpty) {
                final filtered = docs.where((d) {
                  final data = (d.data() as Map<String, dynamic>? ?? {});
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  return email.contains(_searchQuery.toLowerCase()) ||
                      name.contains(_searchQuery.toLowerCase());
                }).toList();
                docs = filtered;
              }

              final totalUsers = docs.length;

              int premiumUsers = 0;
              int trialUsers = 0;
              int testUsers = 0;
              int freeUsers = 0;

              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final subscriptionStatus =
                    data['subscriptionStatus'] as String? ?? 'free';
                final userType = data['userType'] as String? ?? 'normal';
                final trialEndDate = data['trialEndDate'] as Timestamp?;
                final isSubscriptionActive =
                    data['isSubscriptionActive'] as bool? ?? false;

                if (userType == 'test') {
                  testUsers++;
                } else if (isSubscriptionActive &&
                    subscriptionStatus == 'premium') {
                  premiumUsers++;
                } else if (trialEndDate != null &&
                    DateTime.now().isBefore(trialEndDate.toDate())) {
                  trialUsers++;
                } else {
                  freeUsers++;
                }
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Összes felhasználó',
                      totalUsers.toString(),
                      Colors.blue,
                      UserFilter.all,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Premium',
                      premiumUsers.toString(),
                      Colors.green,
                      UserFilter.premium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Próbaidő',
                      trialUsers.toString(),
                      Colors.purple,
                      UserFilter.trial,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Teszt',
                      testUsers.toString(),
                      Colors.orange,
                      UserFilter.test,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Ingyenes',
                      freeUsers.toString(),
                      Colors.grey,
                      UserFilter.free,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, UserFilter filter) {
    final bool selected = _selectedFilter == filter;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minHeight: 80, maxHeight: 80),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('users');
    if (_selectedScience != null && _selectedScience != 'Összes') {
      query = query.where('science', isEqualTo: _selectedScience);
    }

    return StreamBuilder<QuerySnapshot>(
      // Nem használunk Firestore oldali rendezést, mert sok
      // felhasználónál hiányzik a 'createdAt' mező. Helyette
      // kliens oldalon rendezzük, így minden dokumentum látható.
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Hiba: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('Nincsenek felhasználók'),
          );
        }

        List<QueryDocumentSnapshot> users = snapshot.data!.docs;

        // Kliens oldali rendezés 'createdAt' szerint (hiányzó érték kezelése)
        users.sort((a, b) {
          final aTs =
              (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTs =
              (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final aDt = aTs?.toDate();
          final bDt = bTs?.toDate();
          if (aDt == null && bDt == null) return 0;
          if (aDt == null) return 1; // null értékek a lista végére
          if (bDt == null) return -1;
          return bDt.compareTo(aDt); // csökkenő sorrend
        });

        users = users.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final subscriptionStatus =
              data['subscriptionStatus'] as String? ?? 'free';
          final userType = data['userType'] as String? ?? 'normal';
          final trialEndDate = data['trialEndDate'] as Timestamp?;
          final isSubscriptionActive =
              data['isSubscriptionActive'] as bool? ?? false;

          switch (_selectedFilter) {
            case UserFilter.premium:
              return isSubscriptionActive && subscriptionStatus == 'premium';
            case UserFilter.trial:
              return trialEndDate != null &&
                  DateTime.now().isBefore(trialEndDate.toDate());
            case UserFilter.test:
              return userType == 'test';
            case UserFilter.free:
              return !isSubscriptionActive &&
                  (trialEndDate == null ||
                      DateTime.now().isAfter(trialEndDate.toDate())) &&
                  userType != 'test';
            case UserFilter.all:
              return true;
          }
        }).toList();

        if (_searchQuery.isNotEmpty) {
          users = users.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final email = data['email'] as String? ?? '';
            return email.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Felhasználók',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Keresés e-mail alapján',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () {
                          setState(() {
                            _searchQuery = _searchController.text;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Találatok: ${users.length}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final doc = users[index];
                  return _buildUserTile(doc);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final email = data['email'] ?? 'Ismeretlen email';
    final createdAt = data['createdAt'] as Timestamp?;
    final createdDate =
        createdAt?.toDate().toString().split(' ')[0] ?? 'Ismeretlen dátum';
    final subscriptionStatus = data['subscriptionStatus'] as String? ?? 'free';
    final userType = data['userType'] as String? ?? 'normal';
    final trialEndDate = data['trialEndDate'] as Timestamp?;
    final isSubscriptionActive = data['isSubscriptionActive'] as bool? ?? false;
    final isActive = data['isActive'] as bool? ?? true;

    String statusText = 'Ingyenes';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.person;

    if (!isActive) {
      statusText = 'Inaktív';
      statusColor = Colors.red.shade300;
      statusIcon = Icons.block;
    } else if (userType == 'test') {
      statusText = 'Teszt felhasználó';
      statusColor = Colors.orange;
      statusIcon = Icons.science;
    } else if (userType == 'admin') {
      statusText = 'Admin';
      statusColor = Colors.red;
      statusIcon = Icons.admin_panel_settings;
    } else if (isSubscriptionActive && subscriptionStatus == 'premium') {
      statusText = 'Premium aktív';
      statusColor = Colors.green;
      statusIcon = Icons.star;
    } else if (trialEndDate != null &&
        DateTime.now().isBefore(trialEndDate.toDate())) {
      final remainingDays =
          trialEndDate.toDate().difference(DateTime.now()).inDays;
      statusText = 'Próbaidő: $remainingDays nap';
      statusColor = Colors.purple;
      statusIcon = Icons.schedule;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        dense: true,
        minVerticalPadding: 4,
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(
            statusIcon,
            color: Colors.white,
            size: 16,
          ),
        ),
        title: Text(
          email,
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Regisztráció: $createdDate',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleUserAction(doc.id, value, data),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'make_test',
              child: Text('Teszt felhasználó'),
            ),
            const PopupMenuItem(
              value: 'make_normal',
              child: Text('Normál felhasználó'),
            ),
            const PopupMenuItem(
              value: 'activate_premium',
              child: Text('Premium aktiválás'),
            ),
            const PopupMenuItem(
              value: 'extend_trial',
              child: Text('Próbaidő meghosszabbítás'),
            ),
            const PopupMenuItem(
              value: 'shorten_trial',
              child: Text('Próbaidő rövidítése (napok)'),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: data['isActive'] == false ? 'activate' : 'deactivate',
              child: Text(data['isActive'] == false
                  ? 'Felhasználó aktiválása'
                  : 'Felhasználó inaktiválása'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Felhasználó törlése',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUserAction(
      String userId, String action, Map<String, dynamic> userData) async {
    bool success = false;
    String message = '';

    try {
      switch (action) {
        case 'make_test':
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'userType': 'test',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          success = true;
          message = 'Felhasználó teszt típusra állítva';
          break;

        case 'make_normal':
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'userType': 'normal',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          success = true;
          message = 'Felhasználó normál típusra állítva';
          break;

        case 'activate_premium':
          final subscriptionEnd = DateTime.now().add(const Duration(days: 30));
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'subscriptionStatus': 'premium',
            'isSubscriptionActive': true,
            'subscriptionEndDate': Timestamp.fromDate(subscriptionEnd),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          success = true;
          message = 'Premium előfizetés aktiválva (30 nap)';
          break;

        case 'extend_trial':
          final trialEnd = DateTime.now().add(const Duration(days: 7));
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'trialEndDate': Timestamp.fromDate(trialEnd),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          success = true;
          message = 'Próbaidő meghosszabbítva (+7 nap)';
          break;

        case 'shorten_trial':
          final int? days = await _promptDaysDialog(
            title: 'Próbaidő rövidítése',
            label: 'Hány napot vonjunk le? (pozitív egész szám)',
            initialValue: '3',
          );
          if (days == null || days <= 0) {
            success = false;
            message = 'Művelet megszakítva.';
            break;
          }

          final userRef =
              FirebaseFirestore.instance.collection('users').doc(userId);
          final userSnap = await userRef.get();
          final data = userSnap.data();
          final currentTs = data?['trialEndDate'] as Timestamp?;

          if (currentTs == null) {
            success = false;
            message = 'Nincs beállított próbaidő ehhez a felhasználóhoz.';
            break;
          }

          final now = DateTime.now();
          DateTime newEnd = currentTs.toDate().subtract(Duration(days: days));
          if (newEnd.isBefore(now)) {
            newEnd = now; // azonnali lejárat
          }

          await userRef.update({
            'trialEndDate': Timestamp.fromDate(newEnd),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          success = true;
          message = 'Próbaidő rövidítve (−$days nap).';
          break;

        case 'activate':
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'isActive': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          success = true;
          message = 'Felhasználó aktiválva';
          break;

        case 'deactivate':
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          success = true;
          message = 'Felhasználó inaktiválva';
          break;

        case 'delete':
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Felhasználó törlése'),
              content: Text(
                  'Biztosan törölni szeretnéd a következő felhasználót?\n\n${userData['email'] ?? 'Ismeretlen email'}\n\nEz a művelet nem visszavonható!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Mégse'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Törlés'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .delete();
            success = true;
            message = 'Felhasználó törölve';
          } else {
            success = false;
            message = 'Törlés megszakítva';
          }
          break;
      }
    } catch (e) {
      success = false;
      message = 'Hiba történt: $e';
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// Egyszerű párbeszédablak pozitív egész napok megadásához
  Future<int?> _promptDaysDialog({
    required String title,
    required String label,
    String initialValue = '1',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Mégse'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null || parsed <= 0) {
                  Navigator.of(context).pop(null);
                } else {
                  Navigator.of(context).pop(parsed);
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }
}
