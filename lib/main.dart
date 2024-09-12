import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invidious YouTube App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  List _videos = [];
  VideoPlayerController? _videoPlayerController;
  String _server = 'https://invidious.nerdvpn.de';

  Future<void> _searchVideos(String query) async {
    try {
      final response = await http.get(Uri.parse('$_server/api/v1/search?q=$query'));
      if (response.statusCode == 200) {
        setState(() {
          _videos = json.decode(utf8.decode(response.bodyBytes));
        });
      } else {
        _showError('Failed to load search results');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _playVideo(String videoId) async {
    try {
      final response = await http.get(Uri.parse('$_server/api/v1/videos/$videoId'));
      if (response.statusCode == 200) {
        final videoData = json.decode(response.body);
        final videoUrl = videoData['adaptiveFormats'].firstWhere(
              (format) => format['type'].startsWith('video'),
          orElse: () => null,
        )['url'];
        if (_videoPlayerController != null) {
          await _videoPlayerController!.dispose();
        }
        _videoPlayerController = VideoPlayerController.network(videoUrl)
          ..initialize().then((_) {
            setState(() {});
            _videoPlayerController!.play();
          });
      } else {
        _showError('Failed to load video');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _downloadVideo(String videoId) async {
    try {
      final response = await http.get(Uri.parse('$_server/api/v1/videos/$videoId'));
      if (response.statusCode == 200) {
        final videoData = json.decode(response.body);
        final videoUrl = videoData['adaptiveFormats'].firstWhere(
              (format) => format['type'].startsWith('video'),
          orElse: () => null,
        )['url'];
        final status = await Permission.storage.request();
        if (status.isGranted) {
          final directory = await getExternalStorageDirectory();
          final filePath = '${directory!.path}/video.mp4';
          final videoResponse = await http.get(Uri.parse(videoUrl));
          final file = File(filePath);
          await file.writeAsBytes(videoResponse.bodyBytes);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video downloaded to $filePath')));
        }
      } else {
        _showError('Failed to download video');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invidious YouTube App'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Search',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () => _searchVideos(_controller.text),
                  ),
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                final video = _videos[index];
                return ListTile(
                  title: Text(video['title']),
                  onTap: () => _playVideo(video['videoId']),
                  trailing: IconButton(
                    icon: Icon(Icons.download),
                    onPressed: () => _downloadVideo(video['videoId']),
                  ),
                );
              },
            ),
            if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController!),
              ),
          ],
        ),
      ),
    );
  }
}
