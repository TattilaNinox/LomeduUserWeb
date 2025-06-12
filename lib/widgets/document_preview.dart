import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

class DocumentPreview extends StatelessWidget {
  final String docxUrl;
  final String? audioUrl;
  final String? videoUrl;

  const DocumentPreview(
      {super.key, required this.docxUrl, this.audioUrl, this.videoUrl});

  @override
  Widget build(BuildContext context) {
    final googleDocsUrl =
        'https://docs.google.com/viewer?url=${Uri.encodeComponent(docxUrl)}&embedded=true';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.description, size: 48, color: Colors.grey),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => launchUrl(Uri.parse(googleDocsUrl)),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Előnézet megnyitása'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => launchUrl(Uri.parse(docxUrl)),
          icon: const Icon(Icons.download),
          label: const Text('Letöltés'),
        ),
        if (audioUrl != null && audioUrl!.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Hangfájl előnézet:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AudioPreviewPlayer(audioUrl: audioUrl!),
        ],
        if (videoUrl != null && videoUrl!.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Videó előnézet:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => showVideoDialog(context, videoUrl!),
            icon: const Icon(Icons.play_circle_fill),
            label: const Text('Videó megnyitása'),
          ),
        ],
      ],
    );
  }

  void showVideoDialog(BuildContext context, String videoUrl) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width * 0.8;
    final height = mediaQuery.size.height * 0.6;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Videó előnézet',
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  VideoDialogContent(videoUrl: videoUrl),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AudioPreviewPlayer extends StatefulWidget {
  final String audioUrl;
  const AudioPreviewPlayer({super.key, required this.audioUrl});

  @override
  State<AudioPreviewPlayer> createState() => _AudioPreviewPlayerState();
}

class _AudioPreviewPlayerState extends State<AudioPreviewPlayer> {
  late AudioPlayer _audioPlayer;
  bool _isInitialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

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
        _duration = _audioPlayer.duration ?? Duration.zero;
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state.playing;
          _position = _audioPlayer.position;
        });
      });
    } catch (e) {
      debugPrint('Hiba az audio inicializálásakor: $e');
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
    if (!_isInitialized) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 350),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10),
                onPressed: () => _seekRelative(-10),
              ),
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  if (_isPlaying) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.play();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.forward_10),
                onPressed: () => _seekRelative(10),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                Text(_formatDuration(_duration),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoDialogContent extends StatefulWidget {
  final String videoUrl;
  const VideoDialogContent({super.key, required this.videoUrl});

  @override
  State<VideoDialogContent> createState() => _VideoDialogContentState();
}

class _VideoDialogContentState extends State<VideoDialogContent> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller),
          VideoProgressIndicator(_controller, allowScrubbing: true),
          Align(
            alignment: Alignment.center,
            child: IconButton(
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 48,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
