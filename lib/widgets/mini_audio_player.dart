import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;
import 'package:audioplayers/audioplayers.dart';

/// Egy kompakt, beágyazható audiolejátszó widget.
///
/// Ez a `StatefulWidget` az `audioplayers` csomagot használja egyetlen
/// audiofájl lejátszására a megadott URL-ről. A widget saját maga kezeli
/// az összes állapotot, ami a lejátszáshoz szükséges. A projektben ez az
/// egységesített audiolejátszó csomag.
class MiniAudioPlayer extends StatefulWidget {
  /// A lejátszandó audiofájl URL-je.
  final String audioUrl;

  const MiniAudioPlayer({super.key, required this.audioUrl});

  @override
  State<MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

/// A `MiniAudioPlayer` állapotát kezelő osztály.
class _MiniAudioPlayerState extends State<MiniAudioPlayer> {
  // Az `audioplayers` csomag lejátszó példánya.
  late AudioPlayer _audioPlayer;

  // Állapotváltozók a lejátszó állapotának követésére.
  PlayerState? _playerState;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isInitialized = false;
  bool _hasError = false;

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudioPlayer();
  }

  /// A lejátszó inicializálását és a listenerekre való feliratkozást végző metódus.
  Future<void> _initAudioPlayer() async {
    try {
      // Beállítja a forrás URL-t. Ez a lejátszás előfeltétele.
      await _audioPlayer.setSourceUrl(widget.audioUrl);

      // Feliratkozás a lejátszó eseményeire (listenerek), hogy az UI
      // valós időben frissüljön az állapotváltozásoknak megfelelően.
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() => _playerState = state);
      });

      _audioPlayer.onDurationChanged.listen((duration) {
        if (!mounted) return;
        setState(() => _duration = duration);
      });

      _audioPlayer.onPositionChanged.listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
      });

      _audioPlayer.onPlayerComplete.listen((event) {
        if (!mounted) return;
        setState(() {
          _playerState = PlayerState.completed;
          _position = _duration; // Vagy Duration.zero, ízlés szerint
        });
      });

      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Hiba az audio inicializálásakor (audioplayers): $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = true; // Jelezzük, hogy a hibaüzenet megjelenhessen.
        });
      }
    }
  }

  @override
  void dispose() {
    // A dispose() metódus automatikusan meghívja a stop() metódust is.
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Relatív tekerés a hangfájlban.
  void _seekRelative(int seconds) {
    final newPos = _position + Duration(seconds: seconds);
    _audioPlayer.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  /// Egy `Duration` objektumot formáz "pp:mm" formátumú String-gé.
  String _formatDuration(Duration d) {
    if (d == Duration.zero) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Tooltip(
        message: 'A hangfájl nem tölthető be vagy hibás.',
        child: Icon(Icons.error, color: Colors.red),
      );
    }
    if (!_isInitialized) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return SizedBox(
      height: 32,
      width: 160,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.replay_10, size: 16),
            onPressed: () => _seekRelative(-10),
            color: Colors.green,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Vissza 10 mp',
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 16),
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else if (_playerState == PlayerState.paused) {
                await _audioPlayer.resume();
              } else {
                // Ha a lejátszás befejeződött vagy le lett állítva,
                // a play metódus újra elindítja a forrástól.
                await _audioPlayer.play(UrlSource(widget.audioUrl));
              }
            },
            color: Colors.green,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: _isPlaying ? 'Szünet' : 'Lejátszás',
          ),
          IconButton(
            icon: const Icon(Icons.forward_10, size: 16),
            onPressed: () => _seekRelative(10),
            color: Colors.green,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Előre 10 mp',
          ),
          IconButton(
            icon: const Icon(Icons.stop, size: 16),
            onPressed: () async {
              await _audioPlayer.stop();
              setState(() => _position = Duration.zero);
            },
            color: Colors.green,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Stop',
          ),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2.0,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12.0),
                activeTrackColor: Color(0xFF1E3A8A),
                inactiveTrackColor: Color(0xFFD1D5DB),
                thumbColor: Color(0xFF1E3A8A),
                overlayColor: Color(0x291E3A8A),
              ),
              child: Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble(),
                onChanged: (value) {
                  _audioPlayer.seek(Duration(seconds: value.toInt()));
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _formatDuration((_duration - _position).isNegative
                  ? Duration.zero
                  : _duration - _position),
              style: const TextStyle(
                  fontSize: 10, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}
