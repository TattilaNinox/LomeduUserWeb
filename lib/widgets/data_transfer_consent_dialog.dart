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

class _DataTransferConsentDialogState
    extends State<DataTransferConsentDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Adattovábbítási nyilatkozat',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A fizetés folytatásához el kell fogadnia az adattovábbítási nyilatkozatot:',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            // Scrollozható tartalom
            Container(
              height: 400,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHungarianConsent(),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 32),
                    _buildEnglishConsent(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Checkbox
            CheckboxListTile(
              value: _accepted,
              onChanged: (value) {
                setState(() {
                  _accepted = value ?? false;
                });
              },
              title: const Text(
                'Elfogadom az adattovábbítási nyilatkozatot',
                style: TextStyle(fontWeight: FontWeight.w500),
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
          child: const Text('Mégse'),
        ),
        ElevatedButton(
          onPressed: _accepted ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Elfogadom és tovább'),
        ),
      ],
    );
  }

  Widget _buildHungarianConsent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Magyar nyelvű nyilatkozat',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Adattovábbítási nyilatkozat',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Mivel a kereskedő harmadik fél adatai a megrendelési/vásárlási adatok kezelésébe kerülnek, a vásárló nem található alább felsorolt adatok átadásával kapcsolatban megadja:',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Text(
          '- az oldal saját Általános Szerződési Feltételeiben és ezen belül az adatkezelés részben ismertetett szabályok szerint',
          style: TextStyle(fontSize: 13),
        ),
        const Text(
          '- a fizetést ellátó kártyatársaságok és pénzintézetek által megrendelt részletes és érvényes szerződési feltételek',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        const Text(
          'FONTOS: nyilatkozat elfogadéséve a weboldal önmagadában nem elegánge, ha azért a vásárlót nem találkozik el nem fogadja el.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        const Text(
          'A Szolgáltató azonosító adatai',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildDataRow('Név:', 'Oak Quality Kft. (a továbbiakban: „Szolgáltató")'),
        _buildDataRow('Székhely:', '2113 Erdőkertes, Bocskai utca 13.'),
        _buildDataRow('Cégjegyzékszám:', '13 09 084075'),
        _buildDataRow('Adószám:', '11803010-2-13'),
        _buildDataRow('E-mail cím (ügyfélszolgálat):', 'support@lomedu.hu'),
        const SizedBox(height: 16),
        const Text(
          'Kereskedő cégneve: [Iszkékhely] [székhelye]',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kereskedő által továbbított adatok megnevezése: [Fizetési Elfogadóhely webcímé] [albbi adatbázisba tartott élni személyes adatok]',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        const Text(
          'Munkáték részében szolgáltatott további részletesebben használt adatok körét és szlológózó (részére)',
          style: TextStyle(fontSize: 13),
        ),
        const Text(
          'https://simplepay.hu/adatkoz lelesi-tájékozatatók/',
          style: TextStyle(fontSize: 13, color: Colors.blue),
        ),
      ],
    );
  }

  Widget _buildEnglishConsent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'English declaration',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'I acknowledge the following personal data stored in the user account of the data controller',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          '[Kereskedő cégneve] [székhelye] in the user database of [Fizetési Elfogadóhely webcíme] '
          'will be handed over to SimplePay Plc. and is trusted as data processor. The data transferred '
          'by the data controller are the following: [Kereskedő által továbbított adatok megnevezése]',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        const Text(
          'The nature and purpose of the data processing activity performed by the data processor '
          'in the SimplePay Privacy Policy can be found at the following link:',
          style: TextStyle(fontSize: 13),
        ),
        const Text(
          'https://simplepay.hu/adatkezelesi-tajekoztatok/',
          style: TextStyle(fontSize: 13, color: Colors.blue),
        ),
        const SizedBox(height: 16),
        const Text(
          'Service Provider Information',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildDataRow('Name:', 'Oak Quality Kft. (hereinafter: "Service Provider")'),
        _buildDataRow('Headquarters:', '2113 Erdőkertes, Bocskai utca 13., Hungary'),
        _buildDataRow('Company registration number:', '13 09 084075'),
        _buildDataRow('Tax number:', '11803010-2-13'),
        _buildDataRow('Email (customer service):', 'support@lomedu.hu'),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

