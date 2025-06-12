import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class MiniAudioPlayer extends StatefulWidget {
  final String audioUrl;

  const MiniAudioPlayer({super.key, required this.audioUrl});

  @override
  State<MiniAudioPlayer> createState() => _MiniAudioPlayerState();
}

class _MiniAudioPlayerState extends State<MiniAudioPlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _audioPlayer.setUrl(widget.audioUrl);
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
      _audioPlayer.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state.playing;
          _position = _audioPlayer.position;
        });
      });
      _audioPlayer.positionStream.listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
      });
      _audioPlayer.durationStream.listen((duration) {
        if (!mounted) return;
        if (duration != null) {
          setState(() => _duration = duration);
        }
      });
    } catch (e) {
      debugPrint('Hiba az audio inicializálásakor: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _seekRelative(int seconds) {
    final newPos = _position + Duration(seconds: seconds);
    _audioPlayer.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Text(
        'Hangfájl nem található',
        style: TextStyle(color: Colors.red, fontSize: 12),
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
      width: 220,
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
            onPressed: () {
              if (_isPlaying) {
                _audioPlayer.pause();
              } else {
                _audioPlayer.play();
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
            onPressed: () {
              _audioPlayer.stop();
            },
            color: Colors.green,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Stop',
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 1,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                minThumbSeparation: 0,
              ),
              child: Slider(
                value: _position.inSeconds.toDouble(),
                min: 0,
                max: _duration.inSeconds.toDouble() > 0
                    ? _duration.inSeconds.toDouble()
                    : 1,
                onChanged: (value) {
                  _audioPlayer.seek(Duration(seconds: value.toInt()));
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _formatDuration(_position),
              style: const TextStyle(
                  fontSize: 10, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}
