import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class RtspStreamScreen extends StatefulWidget {
  final String rtspUrl;
  const RtspStreamScreen({super.key, required this.rtspUrl});

  @override
  State<RtspStreamScreen> createState() => _RtspStreamScreenState();
}

class _RtspStreamScreenState extends State<RtspStreamScreen> {
  late VlcPlayerController _vlcViewController;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _vlcViewController = VlcPlayerController.network(
      widget.rtspUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );
  }

  @override
  void dispose() {
    _vlcViewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RTSP Stream')),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: VlcPlayer(
            controller: _vlcViewController,
            aspectRatio: 16 / 9,
            placeholder: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isPlaying = !_isPlaying;
            _isPlaying ? _vlcViewController.play() : _vlcViewController.pause();
          });
        },
        child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
