import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewPlayer extends StatefulWidget {
  final String videoUrl;

  const VideoPreviewPlayer({super.key, required this.videoUrl});

  @override
  State<VideoPreviewPlayer> createState() => _VideoPreviewPlayerState();
}

class _VideoPreviewPlayerState extends State<VideoPreviewPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play();
        _controller.addListener(_videoListener);
      });
  }

  void _videoListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_controller),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
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
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4.0,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6.0),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12.0),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white.withOpacity(0.3),
                              thumbColor: Colors.white,
                              overlayColor: Colors.white.withOpacity(0.2),
                            ),
                            child: Slider(
                              value: _controller.value.position.inMilliseconds
                                  .toDouble(),
                              min: 0.0,
                              max: _controller.value.duration.inMilliseconds
                                  .toDouble(),
                              onChanged: (value) {
                                _controller.seekTo(
                                    Duration(milliseconds: value.toInt()));
                              },
                            ),
                          ),
                        ),
                        Text(
                          '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          )
        : const Center(child: CircularProgressIndicator());
  }
}
