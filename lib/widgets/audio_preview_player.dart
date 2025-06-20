import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// Egy nagyobb méretű, előnézeti célokat szolgáló audiolejátszó widget.
///
/// Ez a `StatefulWidget` az `audioplayers` csomagot használja egyetlen
/// audiofájl lejátszására a megadott URL-ről. A `MiniAudioPlayer`-rel ellentétben
/// ez egy nagyobb, hangsúlyosabb felületet biztosít a lejátszáshoz,
/// jellemzően egy előnézeti ablakban vagy dedikált képernyőn való használatra.
class AudioPreviewPlayer extends StatefulWidget {
  /// A lejátszandó audiofájl URL-je.
  final String audioUrl;

  const AudioPreviewPlayer({super.key, required this.audioUrl});

  @override
  State<AudioPreviewPlayer> createState() => _AudioPreviewPlayerState();
}

/// Az `AudioPreviewPlayer` állapotát kezelő osztály.
class _AudioPreviewPlayerState extends State<AudioPreviewPlayer> {
  // Az `audioplayers` csomag lejátszó példánya.
  late AudioPlayer _audioPlayer;
  
  // Állapotváltozók a lejátszó állapotának követésére.
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializePlayer();
  }

  /// Inicializálja a lejátszót és feliratkozik a releváns eseményfigyelőkre.
  Future<void> _initializePlayer() async {
    try {
      // Beállítja a forrás URL-t. Fontos, hogy a lejátszás (`play`) előtt
      // a forrás már be legyen állítva.
      await _audioPlayer.setSourceUrl(widget.audioUrl);
      
      // Feliratkozás a lejátszó eseményeire (listenerek), hogy az UI
      // valós időben frissüljön az állapotváltozásoknak megfelelően.
      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _audioPlayer.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _playerState = s);
      });
    } catch (e) {
      // Hibakezelés, ha a forrás URL beállítása sikertelen.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a hangfájl betöltésekor: $e')),
        );
      }
    }
  }

  /// A widget eltávolításakor felszabadítja a lejátszó erőforrásait.
  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Csúszka a lejátszási pozíció jelzésére és a tekerésre.
        Slider(
          value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
          max: _duration.inSeconds.toDouble(),
          onChanged: (value) async {
            final position = Duration(seconds: value.toInt());
            await _audioPlayer.seek(position);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position)),
              Text(_formatDuration(_duration - _position)),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10),
              onPressed: () {
                final newPosition = _position - const Duration(seconds: 10);
                _audioPlayer.seek(newPosition > Duration.zero ? newPosition : Duration.zero);
              },
            ),
            IconButton(
              iconSize: 48,
              icon: Icon(
                _playerState == PlayerState.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
              ),
              onPressed: () {
                if (_playerState == PlayerState.playing) {
                  _audioPlayer.pause();
                } else {
                  _audioPlayer.resume();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.forward_10),
              onPressed: () {
                final newPosition = _position + const Duration(seconds: 10);
                _audioPlayer.seek(newPosition < _duration ? newPosition : _duration);
              },
            ),
             IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () {
                _audioPlayer.stop();
              },
            ),
          ],
        ),
      ],
    );
  }
}