import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/vault_file.dart';

class MediaViewerScreen extends StatefulWidget {
  final VaultFile file;

  const MediaViewerScreen({Key? key, required this.file}) : super(key: key);

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> with SingleTickerProviderStateMixin {
  String _textContent = '';
  bool _isLoading = false;

  // Audio Player variables
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late AnimationController _rotationController;

  // Video Player variables
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _showVideoControls = true;

  @override
  void initState() {
    super.initState();
    
    final String pathExt = p.extension(widget.file.path).replaceAll('.', '').toLowerCase().trim();
    final String modelExt = widget.file.extension.replaceAll('.', '').toLowerCase().trim();
    final ext = modelExt.isNotEmpty ? modelExt : pathExt;

    // Rotation animation for Audio Vinyl
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    if (ext == 'txt') {
      _loadTextContent();
    } else if (['mp3', 'wav', 'm4a', 'flac'].contains(ext)) {
      _initAudioPlayer();
    } else if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) {
      _initVideoPlayer();
    }
  }

  Future<void> _loadTextContent() async {
    setState(() => _isLoading = true);
    try {
      final file = File(widget.file.path);
      if (await file.exists()) {
        final content = await file.readAsString();
        setState(() {
          _textContent = content;
        });
      }
    } catch (e) {
      setState(() {
        _textContent = 'Failed to load text: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.setSource(DeviceFileSource(widget.file.path));

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (_isPlaying) {
            _rotationController.repeat();
          } else {
            _rotationController.stop();
          }
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() {
          _duration = d;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });
  }

  void _initVideoPlayer() {
    _videoController = VideoPlayerController.file(File(widget.file.path))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController!.play();
          _hideControlsAfterDelay();
        }
      });
  }

  void _hideControlsAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _videoController != null && _videoController!.value.isPlaying) {
        setState(() {
          _showVideoControls = false;
        });
      }
    });
  }

  @override
  void dispose() {
    final String pathExt = p.extension(widget.file.path).replaceAll('.', '').toLowerCase().trim();
    final String modelExt = widget.file.extension.replaceAll('.', '').toLowerCase().trim();
    final ext = modelExt.isNotEmpty ? modelExt : pathExt;

    _rotationController.dispose();

    if (['mp3', 'wav', 'm4a', 'flac'].contains(ext)) {
      _audioPlayer.dispose();
    }
    if (_videoController != null) {
      _videoController!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String pathExt = p.extension(widget.file.path).replaceAll('.', '').toLowerCase().trim();
    final String modelExt = widget.file.extension.replaceAll('.', '').toLowerCase().trim();
    final ext = modelExt.isNotEmpty ? modelExt : pathExt;

    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
    final isAudio = ['mp3', 'wav', 'm4a', 'flac'].contains(ext);
    final isVideo = ['mp4', 'mkv', 'avi', 'mov'].contains(ext);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.file.name,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Secure In-App Viewer',
              style: TextStyle(
                color: AppColors.primary.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: AppColors.primary)
              : isImage
                  ? _buildImageViewer()
                  : isAudio
                      ? _buildAudioPlayer()
                      : isVideo
                          ? _buildVideoPlayer()
                          : ext == 'txt'
                              ? _buildTextViewer()
                              : _buildUnsupportedViewer(),
        ),
      ),
    );
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      panEnabled: true,
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.file(
        File(widget.file.path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              Text(
                'Failed to render secure image',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAudioPlayer() {
    final audioColor = const Color(0xFFFF00AA);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Elegant rotating record animation
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationController.value * 2 * 3.14159,
                child: child,
              );
            },
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF111218),
                border: Border.all(color: audioColor.withOpacity(0.4), width: 6),
                boxShadow: [
                  BoxShadow(
                    color: audioColor.withOpacity(0.2),
                    blurRadius: 32,
                    spreadRadius: 4,
                  )
                ],
              ),
              child: Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [audioColor, audioColor.withOpacity(0.5)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, color: Colors.white, size: 36),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            widget.file.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Custom glowing slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: audioColor,
              inactiveTrackColor: Colors.white10,
              thumbColor: audioColor,
              overlayColor: audioColor.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: _position.inSeconds.toDouble(),
              max: _duration.inSeconds.toDouble() > 0
                  ? _duration.inSeconds.toDouble()
                  : 1.0,
              onChanged: (val) async {
                await _audioPlayer.seek(Duration(seconds: val.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Control buttons
          GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                await _audioPlayer.resume();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: audioColor,
                boxShadow: [
                  BoxShadow(
                    color: audioColor.withOpacity(0.4),
                    blurRadius: 16,
                  )
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isVideoInitialized) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text('Preparing secure video...', style: TextStyle(color: Colors.white54)),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showVideoControls = !_showVideoControls;
        });
        if (_showVideoControls) _hideControlsAfterDelay();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered Video Player
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),

          // Glassmorphic overlays and custom controls
          if (_showVideoControls)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 20),
                    // Large center Play/Pause overlay
                    IconButton(
                      iconSize: 64,
                      icon: Icon(
                        _videoController!.value.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_videoController!.value.isPlaying) {
                            _videoController!.pause();
                          } else {
                            _videoController!.play();
                            _showVideoControls = false;
                          }
                        });
                      },
                    ),
                    // Bottom seekbar & duration controls
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoProgressIndicator(
                            _videoController!,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: AppColors.primary,
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white10,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_videoController!.value.position),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              Text(
                                _formatDuration(_videoController!.value.duration),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextViewer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: SelectableText(
          _textContent,
          style: GoogleFonts.spaceMono(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupportedViewer() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFFB300),
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'External App Required',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This file type cannot be displayed securely inside SentryKey. Opening it externally will save a temporary copy, which SentryKey will delete afterwards.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
