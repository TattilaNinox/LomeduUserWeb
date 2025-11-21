import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Szállítási cím űrlap komponens az Account képernyőn
///
/// Ez a komponens a számlázáshoz szükséges szállítási adatokat kezeli.
/// Feltételesen szerkeszthető: csak akkor, ha az előfizetés lejárt vagy
/// 3 napon belül lejár, vagy admin felhasználó.
class ShippingAddressForm extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool canEdit;

  const ShippingAddressForm({
    super.key,
    required this.userData,
    required this.canEdit,
  });

  @override
  State<ShippingAddressForm> createState() => _ShippingAddressFormState();
}

class _ShippingAddressFormState extends State<ShippingAddressForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxNumberController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isAdmin = false;
  bool _isGeneratingInvoice = false;
  bool _isCompany = false;

  // Irányítószám-település adatok
  Map<String, List<String>>? _postalCodes;
  bool _isLoadingPostalCodes = false;
  List<String>? _availableCities;

  @override
  void initState() {
    super.initState();
    _loadPostalCodes();
    _loadUserData();
    _zipCodeController.addListener(_onZipCodeChanged);
  }

  @override
  void dispose() {
    _zipCodeController.removeListener(_onZipCodeChanged);
    _nameController.dispose();
    _zipCodeController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _taxNumberController.dispose();
    super.dispose();
  }

  /// Irányítószám adatbázis betöltése
  Future<void> _loadPostalCodes() async {
    try {
      setState(() {
        _isLoadingPostalCodes = true;
      });

      final String jsonString =
          await rootBundle.loadString('assets/postal_codes.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      _postalCodes = jsonData.map(
        (key, value) => MapEntry(
          key,
          List<String>.from(value as List),
        ),
      );

      if (mounted) {
        setState(() {
          _isLoadingPostalCodes = false;
        });
      }
    } catch (e) {
      debugPrint('Hiba az iranyitoszam adatok betoltesekor: $e');
      if (mounted) {
        setState(() {
          _isLoadingPostalCodes = false;
        });
      }
    }
  }

  /// Felhasználói adatok betöltése
  void _loadUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Admin ellenőrzés
    final isAdmin = widget.userData['isAdmin'] == true ||
        user.email == 'tattila.ninox@gmail.com';
    setState(() {
      _isAdmin = isAdmin;
    });

    // Szállítási cím betöltése - TESZTELÉSHEZ KIKOMMENTEZVE
    // A form mindig üresen indul, hogy tesztelni lehessen
    /*
    final shippingAddress = widget.userData['shippingAddress'] as Map<String, dynamic>?;
    if (shippingAddress != null && shippingAddress.isNotEmpty) {
      _nameController.text = shippingAddress['name']?.toString() ?? '';
      _zipCodeController.text = shippingAddress['zipCode']?.toString() ?? '';
      _cityController.text = shippingAddress['city']?.toString() ?? '';
      _addressController.text = shippingAddress['address']?.toString() ?? '';
      _taxNumberController.text = shippingAddress['taxNumber']?.toString() ?? '';
      _isCompany = shippingAddress['isCompany']?.toString() == 'true';
    }
    */
    // A form mindig üresen marad teszteléshez
  }

  /// Irányítószám változás figyelése
  void _onZipCodeChanged() {
    final zipCode = _zipCodeController.text.trim();

    // Csak akkor keresünk, ha pontosan 4 számjegy van
    if (zipCode.length == 4 && RegExp(r'^\d{4}$').hasMatch(zipCode)) {
      _lookupCity(zipCode);
    } else {
      // Ha nem 4 számjegy, eltávolítjuk a település mezőt és a dropdown-t
      if (_availableCities != null) {
        setState(() {
          _availableCities = null;
        });
      }
    }
  }

  /// Település keresés irányítószám alapján
  void _lookupCity(String zipCode) {
    if (_postalCodes == null) return;

    final cities = _postalCodes![zipCode];

    if (cities != null && cities.isNotEmpty) {
      if (cities.length == 1) {
        // Egy település: automatikusan kitöltjük
        setState(() {
          _cityController.text = cities[0];
          _availableCities = null;
        });
      } else {
        // Több település: lista megjelenítése
        setState(() {
          _availableCities = cities;
          _cityController.clear(); // Töröljük, hogy válasszon
        });
      }
    } else {
      // Nincs találat
      setState(() {
        _availableCities = null;
      });
    }
  }

  /// Település választó megjelenítése bottom sheet-ben
  Future<void> _showCitySelector() async {
    if (_availableCities == null || _availableCities!.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${_availableCities!.length} telepules talalhato, valassz egyet:',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _availableCities!.length,
              itemBuilder: (context, index) {
                final city = _availableCities![index];
                return ListTile(
                  leading: const Icon(Icons.location_city),
                  title: Text(city),
                  onTap: () {
                    Navigator.of(context).pop(city);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _cityController.text = selected;
        _availableCities = null;
      });
    }
  }

  /// Szerkesztés indítása
  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  /// Szerkesztés megszakítása
  void _cancelEditing() {
    _loadUserData(); // Visszaállítjuk az eredeti adatokat
    setState(() {
      _isEditing = false;
    });
  }

  /// Adatok mentése Firestore-ba
  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Szigorú ellenőrzés: minden kötelező mező ki kell legyen töltve
    final name = _nameController.text.trim();
    final zipCode = _zipCodeController.text.trim();
    final city = _cityController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || zipCode.isEmpty || zipCode.length != 4 || city.isEmpty || address.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kerjuk, toltsd ki az osszes kotelezo mezot!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Cég esetén adószám kötelező
    if (_isCompany && _taxNumberController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jogi szemely eseten az adoszam megadasa kotelezo!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final addressData = {
        'name': name,
        'zipCode': zipCode,
        'city': city,
        'address': address,
        'isCompany': _isCompany.toString(),
        if (_taxNumberController.text.trim().isNotEmpty)
          'taxNumber': _taxNumberController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'shippingAddress': addressData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Szallitasi cim sikeresen mentve!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba tortent: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Szállítási cím törlése
  Future<void> _deleteShippingAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Megerősítés
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Szallitasi cim torlese'),
        content: const Text(
          'Biztosan torolni szeretned a mentett szallitasi cimet?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Megse'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Torles'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'shippingAddress': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mezők törlése
      _nameController.clear();
      _zipCodeController.clear();
      _cityController.clear();
      _addressController.clear();
      _taxNumberController.clear();
      _isCompany = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Szallitasi cim sikeresen torolve!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba tortent: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Admin teszt számla generálása
  Future<void> _generateTestInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isGeneratingInvoice = true;
    });

    try {
      final addressData = {
        'name': _nameController.text.trim(),
        'zipCode': _zipCodeController.text.trim(),
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
        'isCompany': _isCompany.toString(),
        if (_taxNumberController.text.trim().isNotEmpty)
          'taxNumber': _taxNumberController.text.trim(),
      };

      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('generateInvoiceManually');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Szamla generalasa folyamatban...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final result = await callable.call({
        'shippingAddress': addressData,
        'planId': 'monthly_premium_prepaid',
        'amount': 4350,
      });

      final data = result.data as Map<String, dynamic>;

      if (mounted) {
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Szamla sikeresen generalva! Szamlaszam: ${data['invoiceNumber'] ?? 'N/A'}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hiba: ${data['error'] ?? 'Ismeretlen hiba'}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Hiba a teszt szamla generalasakor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba tortent: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingInvoice = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.canEdit || _isAdmin;
    final isFormEditable = canEdit && _isEditing;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cím és szerkesztés gomb
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Color(0xFF1E3A8A),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Szallitasi cim',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                  if (canEdit && !_isEditing)
                    TextButton.icon(
                      onPressed: _startEditing,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Szerkesztes'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A8A),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Cég/Magánszemély választó (csak szerkesztés módban)
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Jogi szemelykent vasarlok',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: _isCompany,
                    onChanged: isFormEditable
                        ? (value) {
                            setState(() {
                              _isCompany = value ?? false;
                            });
                          }
                        : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ),

              // Név/Cégnév mező
              TextFormField(
                controller: _nameController,
                enabled: isFormEditable,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: _isCompany ? 'Cegnev *' : 'Nev *',
                  prefixIcon: const Icon(Icons.person, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A ${_isCompany ? "cegnev" : "nev"} megadasa kotelezo';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Irányítószám és Település sor
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _zipCodeController,
                      enabled: isFormEditable,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Iranyitoszam *',
                        prefixIcon: const Icon(Icons.markunread_mailbox, size: 20),
                        suffixIcon: _isLoadingPostalCodes
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                        counterText: '',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      maxLength: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Kotelezo';
                        }
                        if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) {
                          return '4 szamjegy';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _cityController,
                      enabled: isFormEditable && _availableCities == null,
                      readOnly: _availableCities != null,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Telepules *',
                        prefixIcon: const Icon(Icons.location_city, size: 20),
                        suffixIcon: _availableCities != null
                            ? IconButton(
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                onPressed: isFormEditable
                                    ? _showCitySelector
                                    : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Kotelezo';
                        }
                        return null;
                      },
                      onTap: _availableCities != null && isFormEditable
                          ? _showCitySelector
                          : null,
                    ),
                  ),
                ],
              ),

              // Választólista megjelenítése (ha több település van)
              if (_availableCities != null && _availableCities!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_availableCities!.length} telepules talalhato',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (isFormEditable)
                          TextButton(
                            onPressed: _showCitySelector,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Valasztas',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Utca, házszám mező
              TextFormField(
                controller: _addressController,
                enabled: isFormEditable,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Utca, hazszam *',
                  prefixIcon: const Icon(Icons.home, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kotelezo';
                  }
                  return null;
                },
              ),

              // Adószám mező (csak cég esetén vagy szerkesztés módban)
              if (_isCompany || _isEditing) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _taxNumberController,
                  enabled: isFormEditable,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: _isCompany ? 'Adoszam *' : 'Adoszam',
                    prefixIcon: const Icon(Icons.badge, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  validator: _isCompany
                      ? (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Jogi szemely eseten az adoszam megadasa kotelezo';
                          }
                          return null;
                        }
                      : null,
                ),
              ],

              const SizedBox(height: 16),

              // Gombok
              if (_isEditing)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : _cancelEditing,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Megse', style: TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Mentes', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                ),

              // Admin gombok
              if (_isAdmin && !_isEditing) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _deleteShippingAddress,
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text(
                            'Szallitasi cim torlese',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isGeneratingInvoice ? null : _generateTestInvoice,
                          icon: _isGeneratingInvoice
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.receipt, size: 18),
                          label: const Text(
                            'Teszt szamla',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

