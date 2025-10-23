import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// SimplePay hivatalos logó widget
///
/// Megjeleníti a SimplePay logót a SimplePay követelményeinek megfelelően:
/// - Kattintható link a Fizetési Tájékoztatóra
/// - Új ablakban nyílik meg
/// - Tartalmazza a kötelező alt/title attribútumokat
/// - Reszponzív megjelenítés
class SimplePayLogo extends StatelessWidget {
  /// Logó szélessége (null esetén automatikus)
  final double? width;

  /// Logó magassága (null esetén automatikus)
  final double? height;

  /// Középre igazítás engedélyezése
  final bool centered;

  /// Margó a logó körül
  final EdgeInsetsGeometry? margin;

  const SimplePayLogo({
    super.key,
    this.width,
    this.height,
    this.centered = true,
    this.margin,
  });

  /// Fizetési Tájékoztató megnyitása új ablakban
  Future<void> _openPaymentInfo(BuildContext context) async {
    // Magyar nyelvű Fizetési Tájékoztató
    const url =
        'https://simplepartner.hu/PaymentService/Fizetesi_tajekoztato.pdf';

    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nem sikerült megnyitni a Fizetési Tájékoztatót'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba történt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reszponzív méret számítása
    final screenWidth = MediaQuery.of(context).size.width;
    final double effectiveWidth;

    if (width != null) {
      effectiveWidth = width!;
    } else {
      // Automatikus méretezés képernyőméret alapján
      // A horizontális logó szélesebb, ezért nagyobb értékek
      if (screenWidth < 600) {
        // Mobile
        effectiveWidth = 240;
      } else if (screenWidth < 900) {
        // Tablet
        effectiveWidth = 360;
      } else {
        // Desktop
        effectiveWidth = 482;
      }
    }

    // Arány megtartása (482:40 az eredeti arány, kb. 12:1)
    final double effectiveHeight = height ?? (effectiveWidth / 12.0);

    Widget logoWidget = Semantics(
      label: 'SimplePay - Online bankkártyás fizetés',
      hint: 'Kattintson a Fizetési Tájékoztató megnyitásához',
      button: true,
      child: Tooltip(
        message: 'SimplePay Fizetési Tájékoztató megnyitása',
        child: InkWell(
          onTap: () => _openPaymentInfo(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/images/simplepay_bankcard_logos_left_482x40_new.jpg',
              width: effectiveWidth,
              height: effectiveHeight,
              fit: BoxFit.contain,
              semanticLabel: 'SimplePay vásárlói tájékoztató',
              errorBuilder: (context, error, stackTrace) {
                // Debug info
                debugPrint('SimplePay logo betöltési hiba: $error');
                // Fallback ha a kép nem tölthető be
                return Container(
                  width: effectiveWidth,
                  height: effectiveHeight,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text(
                      'SimplePay',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Ha középre igazítást kértek
    if (centered) {
      logoWidget = Center(child: logoWidget);
    }

    // Ha margót adtak meg
    if (margin != null) {
      logoWidget = Padding(padding: margin!, child: logoWidget);
    }

    return logoWidget;
  }
}

/// SimplePay logó kompakt változata (csak a logo, fizetési opciók nélkül)
///
/// Használható kisebb helyeken, ahol nincs elég hely a teljes logóhoz.
class SimplePayLogoCompact extends StatelessWidget {
  final double? width;
  final double? height;

  const SimplePayLogoCompact({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SimplePayLogo(
      width: width ?? 100,
      height: height,
      centered: false,
      margin: EdgeInsets.zero,
    );
  }
}
