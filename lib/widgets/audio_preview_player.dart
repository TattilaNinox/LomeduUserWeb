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
  bool _hasPlayedOnce = false;
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  /// Inicializálja a lejátszót és feliratkozik a releváns eseményfigyelőkre.
  Future<void> _ensureConfigured() async {
    if (_isConfigured) return;
    try {
      // Feliratkozás a lejátszó eseményeire (listenerek), hogy az UI
      // valós időben frissüljön az állapotváltozásoknak megfelelően.
      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _audioPlayer.onPlayerStateChanged.listen((s) {
        if (!mounted) return;
        setState(() {
          _playerState = s;
          if (s == PlayerState.playing) {
            _hasPlayedOnce = true;
          }
        });
      });

      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setSourceUrl(widget.audioUrl);
      _isConfigured = true;
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
    final bool isNarrow = MediaQuery.of(context).size.width < 360;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Csúszka a lejátszási pozíció jelzésére és a tekerésre.
        Slider(
          value: _position.inSeconds
              .toDouble()
              .clamp(0.0, _duration.inSeconds.toDouble()),
          max: _duration.inSeconds.toDouble(),
          onChanged: (value) async {
            final position = Duration(seconds: value.toInt());
            await _audioPlayer.seek(position);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formatDuration(_position),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDuration(_duration - _position),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10),
              onPressed: () {
                final newPosition = _position - const Duration(seconds: 10);
                _audioPlayer.seek(
                    newPosition > Duration.zero ? newPosition : Duration.zero);
              },
            ),
            IconButton(
              iconSize: isNarrow ? 40 : 48,
              icon: Icon(
                _playerState == PlayerState.playing
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
              ),
              onPressed: () async {
                await _ensureConfigured();

                if (_playerState == PlayerState.playing) {
                  await _audioPlayer.pause();
                  return;
                }

                if (_playerState == PlayerState.paused && _hasPlayedOnce) {
                  await _audioPlayer.resume();
                  return;
                }

                await _audioPlayer.play(UrlSource(widget.audioUrl));
              },
            ),
            IconButton(
              icon: const Icon(Icons.forward_10),
              onPressed: () {
                final newPosition = _position + const Duration(seconds: 10);
                _audioPlayer
                    .seek(newPosition < _duration ? newPosition : _duration);
              },
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () async {
                await _ensureConfigured();
                await _audioPlayer.stop();
              },
            ),
          ],
        ),
      ],
    );
  }
}
