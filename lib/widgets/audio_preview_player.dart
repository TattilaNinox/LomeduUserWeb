import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPreviewPlayer extends StatefulWidget {
  final String audioUrl;

  const AudioPreviewPlayer({super.key, required this.audioUrl});

  @override
  State<AudioPreviewPlayer> createState() => _AudioPreviewPlayerState();
}

class _AudioPreviewPlayerState extends State<AudioPreviewPlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isInitialized = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _audioPlayer.setSourceUrl(widget.audioUrl);
      _audioPlayer.onDurationChanged.listen((Duration d) {
        if (mounted) setState(() => _duration = d);
      });
      _audioPlayer.onPositionChanged.listen((Duration p) {
        if (mounted) setState(() => _position = p);
      });
      _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
        if (mounted) {
          setState(() => _isPlaying = state == PlayerState.playing);
        }
      });
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a hangfájl betöltésekor: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble(),
                onChanged: (value) async {
                  final position = Duration(seconds: value.toInt());
                  await _audioPlayer.seek(position);
                  setState(() => _position = position);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 48,
                    ),
                    onPressed: () async {
                      if (_isPlaying) {
                        await _audioPlayer.pause();
                      } else {
                        await _audioPlayer.play(UrlSource(widget.audioUrl));
                      }
                    },
                  ),
                ],
              ),
            ],
          )
        : const Center(child: CircularProgressIndicator());
  }
}