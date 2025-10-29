import 'package:flutter/material.dart';

/// SimplePay adattovábbítási nyilatkozat dialog
///
/// Minden előfizetés indítás előtt meg kell jeleníteni.
/// A felhasználónak el kell fogadnia a nyilatkozatot a fizetés indítása előtt.
class DataTransferConsentDialog extends StatefulWidget {
  const DataTransferConsentDialog({super.key});

  /// Megjeleníti a consent dialogot
  ///
  /// Visszatérési érték:
  /// - `true`: a felhasználó elfogadta a nyilatkozatot
  /// - `false`: a felhasználó nem fogadta el vagy bezárta a dialogot
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // csak a gombokkal lehet bezárni
      builder: (context) => const DataTransferConsentDialog(),
    );
    return result ?? false;
  }

  @override
  State<DataTransferConsentDialog> createState() =>
      _DataTransferConsentDialogState();
}

class _DataTransferConsentDialogState extends State<DataTransferConsentDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    // Reszponzív méretek
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final dialogHeight = isMobile
        ? screenSize.height * 0.5 // Mobil: 50%
        : (screenSize.height * 0.6).clamp(300.0, 500.0);
    final fontSize = isMobile ? 11.0 : 13.0;
    final titleSize = isMobile ? 13.0 : 15.0;

    return AlertDialog(
      title: Text(
        'Adattovábbítási nyilatkozat',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 16 : 18,
        ),
      ),
      contentPadding: EdgeInsets.all(isMobile ? 12 : 24),
      content: SizedBox(
        width: isMobile ? screenSize.width * 0.9 : double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A fizetés folytatásához el kell fogadnia az adattovábbítási nyilatkozatot:',
              style: TextStyle(fontSize: fontSize, color: Colors.black87),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            // Scrollozható tartalom - RESZPONZÍV magasság
            Container(
              height: dialogHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 8 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHungarianConsent(isMobile, fontSize, titleSize),
                    SizedBox(height: isMobile ? 16 : 32),
                    const Divider(),
                    SizedBox(height: isMobile ? 16 : 32),
                    _buildEnglishConsent(isMobile, fontSize, titleSize),
                  ],
                ),
              ),
            ),
            SizedBox(height: isMobile ? 8 : 16),
            // Checkbox
            CheckboxListTile(
              value: _accepted,
              onChanged: (value) {
                setState(() {
                  _accepted = value ?? false;
                });
              },
              title: Text(
                'Elfogadom az adattovábbítási nyilatkozatot',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Mégse', style: TextStyle(fontSize: isMobile ? 13 : 14)),
        ),
        ElevatedButton(
          onPressed: _accepted ? () => Navigator.of(context).pop(true) : null,
          child:
              Text('Elfogadom', style: TextStyle(fontSize: isMobile ? 13 : 14)),
        ),
      ],
    );
  }

  Widget _buildHungarianConsent(
      bool isMobile, double fontSize, double titleSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Magyar nyelvű nyilatkozat',
          style: TextStyle(
            fontSize: titleSize + 1,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        SizedBox(height: isMobile ? 8 : 16),
        Text(
          'Adattovábbítási nyilatkozat',
          style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: isMobile ? 6 : 12),
        Text(
          'Tudomásul veszem, hogy a(z) Oak Quality Kft. 2113 Erdőkertes, Bocskai utca 13. adatkezelő által a(z) Lomedu.hu felhasználói adatbázisában tárolt alábbi személyes adataim átadásra kerülnek a SimplePay Zrt., mint adatfeldolgozó részére.',
          style: TextStyle(fontSize: fontSize),
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Text(
          'Az adatkezelő által továbbított adatok köre az alábbi:',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: isMobile ? 4 : 8),
        Text(
          '• Email cím',
          style: TextStyle(fontSize: fontSize),
        ),
        Text(
          '• Megrendelési azonosító',
          style: TextStyle(fontSize: fontSize),
        ),
        Text(
          '• Vásárolt termék/szolgáltatás neve',
          style: TextStyle(fontSize: fontSize),
        ),
        Text(
          '• Vásárolt termék/szolgáltatás leírása',
          style: TextStyle(fontSize: fontSize),
        ),
        Text(
          '• Vásárolt termék/szolgáltatás ára',
          style: TextStyle(fontSize: fontSize),
        ),
        Text(
          '• Vásárolt termék/szolgáltatás mennyisége',
          style: TextStyle(fontSize: fontSize),
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Text(
          'Az adatfeldolgozó által végzett adatfeldolgozási tevékenység jellege és célja a SimplePay Adatkezelési tájékoztatóban, az alábbi linken tekinthető meg:',
          style: TextStyle(fontSize: fontSize),
        ),
        SizedBox(height: isMobile ? 8 : 16),
        Text(
          'A Szolgáltató azonosító adatai',
          style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: isMobile ? 4 : 8),
        _buildDataRow('Név:', 'Oak Quality Kft.', isMobile, fontSize),
        _buildDataRow('Székhely:', '2113 Erdőkertes, Bocskai utca 13.',
            isMobile, fontSize),
        _buildDataRow('Cégjegyzékszám:', '13 09 084075', isMobile, fontSize),
        _buildDataRow('Adószám:', '11803010-2-13', isMobile, fontSize),
        _buildDataRow('E-mail:', 'support@lomedu.hu', isMobile, fontSize),
        SizedBox(height: isMobile ? 8 : 12),
        Text(
          'További információk:',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
        Text(
          'https://simplepay.hu/adatkezelesi-tajekoztatok/',
          style: TextStyle(fontSize: fontSize - 1, color: Colors.blue),
        ),
      ],
    );
  }

  Widget _buildEnglishConsent(
      bool isMobile, double fontSize, double titleSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'English Declaration',
          style: TextStyle(
            fontSize: titleSize + 1,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        SizedBox(height: isMobile ? 8 : 16),
        Text(
          'Data Transfer Declaration',
          style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        Text(
          'I acknowledge that the following personal data stored in the Lomedu.hu user database by Oak Quality Kft. (2113 Erdőkertes, Bocskai utca 13.) as data controller will be transferred to SimplePay Plc. as data processor.',
          style: TextStyle(fontSize: fontSize),
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Text(
          'Data transferred by the merchant:',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: isMobile ? 4 : 8),
        Text(
          '• Email address',
          style: TextStyle(fontSize: fontSize),
        ),
        Text(
          '• Order reference number',
          style: TextStyle(fontSize: fontSize),
        ),
        Text(
          '• Name of purchased product/service',
          style: TextStyle(fontSize: fontSize),
        ),
        Text(
          '• Description of purchased product/service',
          style: TextStyle(fontSize: fontSize),
        ),
        Text(
          '• Price of purchased product/service',
          style: TextStyle(fontSize: fontSize),
        ),
        Text(
          '• Quantity of purchased product/service',
          style: TextStyle(fontSize: fontSize),
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Text(
          'The nature and purpose of data processing activities performed by the data processor can be viewed in the SimplePay Data Processing Information at the following link:',
          style: TextStyle(fontSize: fontSize),
        ),
        SizedBox(height: isMobile ? 8 : 16),
        Text(
          'Service Provider Information',
          style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: isMobile ? 4 : 8),
        _buildDataRow('Name:', 'Oak Quality Kft.', isMobile, fontSize),
        _buildDataRow('Headquarters:', '2113 Erdőkertes, Bocskai u. 13.',
            isMobile, fontSize),
        _buildDataRow('Registration:', '13 09 084075', isMobile, fontSize),
        _buildDataRow('Tax number:', '11803010-2-13', isMobile, fontSize),
        _buildDataRow('Email:', 'support@lomedu.hu', isMobile, fontSize),
        SizedBox(height: isMobile ? 8 : 12),
        Text(
          'More info:',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
        Text(
          'https://simplepay.hu/adatkezelesi-tajekoztatok/',
          style: TextStyle(fontSize: fontSize - 1, color: Colors.blue),
        ),
      ],
    );
  }

  Widget _buildDataRow(
      String label, String value, bool isMobile, double fontSize) {
    // Mobilon column layout, asztali nézetben row
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: fontSize),
            ),
          ],
        ),
      );
    }

    // Asztali nézet - row layout
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }
}
