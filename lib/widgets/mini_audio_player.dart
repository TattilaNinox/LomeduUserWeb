import 'package:flutter/material.dart';
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

  /// Ha igaz, a lejátszó csak interakcióra inicializál (lista teljesítményhez).
  final bool deferInit;

  /// Kompakt megjelenítés: kisebb ikonok, hátralévő idő elrejtése.
  final bool compact;

  const MiniAudioPlayer(
      {super.key,
      required this.audioUrl,
      this.deferInit = true,
      this.compact = false});

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
  bool _initializing = false;
  bool _expanded = false; // Ha igaz, a teljes kezelőfelület látszik
  bool _isLooping =
      false; // Folyamatos lejátszás kapcsoló (nem mentjük tartósan)

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    if (!widget.deferInit) {
      _initAudioPlayer();
    }
  }

  /// A lejátszó inicializálását és a listenerekre való feliratkozást végző metódus.
  Future<void> _initAudioPlayer() async {
    try {
      // Beállítja a forrás URL-t. Ez a lejátszás előfeltétele.
      await _audioPlayer.setSourceUrl(widget.audioUrl);
      // Ismétlés beállítása a kapcsoló állapotának megfelelően
      await _audioPlayer.setReleaseMode(
        _isLooping ? ReleaseMode.loop : ReleaseMode.stop,
      );

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

  Future<void> _ensureInitAndPlay() async {
    if (_isInitialized) {
      setState(() => _expanded = true);
      await _audioPlayer.play(UrlSource(widget.audioUrl));
      return;
    }
    setState(() => _initializing = true);
    await _initAudioPlayer();
    if (!mounted) return;
    setState(() {
      _initializing = false;
      _expanded = true;
    });
    await _audioPlayer.play(UrlSource(widget.audioUrl));
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
    final double iconSize = widget.compact ? 18 : 22; // kompakt módban kisebb
    final BoxConstraints btnSize = BoxConstraints(
      minWidth: widget.compact ? 30 : 36,
      minHeight: widget.compact ? 30 : 36,
    );

    if (_hasError) {
      return const Tooltip(
        message: 'A hangfájl nem tölthető be vagy hibás.',
        child: Icon(Icons.error, color: Colors.red),
      );
    }

    // Lista-optimalizált kezdeti állapot: csak egy kis Play ikon jelenik meg.
    if (widget.deferInit && !_expanded) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SizedBox(
          height: 28,
          child: _initializing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill,
                          size: 22, color: Color(0xFF1E3A8A)),
                      padding: EdgeInsets.zero,
                      constraints: btnSize,
                      tooltip: 'Hang lejátszása',
                      onPressed: _ensureInitAndPlay,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        _isLooping ? Icons.repeat_on : Icons.repeat,
                        size: 20,
                        color: _isLooping
                            ? Colors.orange
                            : const Color(0xFF1E3A8A),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: btnSize,
                      tooltip: _isLooping
                          ? 'Ismétlés: bekapcsolva'
                          : 'Ismétlés: kikapcsolva',
                      onPressed: () async {
                        setState(() => _isLooping = !_isLooping);
                        if (_isInitialized) {
                          await _audioPlayer.setReleaseMode(
                            _isLooping ? ReleaseMode.loop : ReleaseMode.stop,
                          );
                        }
                      },
                    ),
                  ],
                ),
        ),
      );
    }

    if (!_isInitialized) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SizedBox(
          height: 36,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.replay_10, size: iconSize),
                  onPressed: () => _seekRelative(-10),
                  color: Colors.green,
                  padding: EdgeInsets.zero,
                  constraints: btnSize,
                  tooltip: 'Vissza 10 mp',
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                      size: iconSize),
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
                  constraints: btnSize,
                  tooltip: _isPlaying ? 'Szünet' : 'Lejátszás',
                ),
                IconButton(
                  icon: Icon(Icons.forward_10, size: iconSize),
                  onPressed: () => _seekRelative(10),
                  color: Colors.green,
                  padding: EdgeInsets.zero,
                  constraints: btnSize,
                  tooltip: 'Előre 10 mp',
                ),
                IconButton(
                  icon: Icon(Icons.stop, size: iconSize),
                  onPressed: () async {
                    await _audioPlayer.stop();
                    setState(() => _position = Duration.zero);
                  },
                  color: Colors.green,
                  padding: EdgeInsets.zero,
                  constraints: btnSize,
                  tooltip: 'Stop',
                ),
                IconButton(
                  icon: Icon(
                    _isLooping ? Icons.repeat_on : Icons.repeat,
                    size: iconSize,
                  ),
                  onPressed: () async {
                    setState(() => _isLooping = !_isLooping);
                    await _audioPlayer.setReleaseMode(
                      _isLooping ? ReleaseMode.loop : ReleaseMode.stop,
                    );
                  },
                  color: _isLooping ? Colors.orange : Colors.green,
                  padding: EdgeInsets.zero,
                  constraints: btnSize,
                  tooltip: _isLooping
                      ? 'Ismétlés: bekapcsolva'
                      : 'Ismétlés: kikapcsolva',
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    _formatDuration((_duration - _position).isNegative
                        ? Duration.zero
                        : _duration - _position),
                    style: TextStyle(
                      fontSize: widget.compact ? 11 : 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
