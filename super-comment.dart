import 'package:flutter/material.dart'; // Flutterのマテリアルデザインライブラリをインポート
import 'package:http/http.dart' as http; // HTTPリクエストを処理するためのライブラリをインポート
import 'dart:convert'; // JSONエンコーディング/デコーディングのためのライブラリをインポート
import 'package:video_player/video_player.dart'; // 動画再生のためのライブラリをインポート
import 'package:path_provider/path_provider.dart'; // ストレージパスを取得するためのライブラリをインポート
import 'package:permission_handler/permission_handler.dart'; // パーミッション管理のためのライブラリをインポート
import 'dart:io'; // ファイル操作のためのライブラリをインポート

void main() => runApp(MyApp()); // アプリケーションを起動

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invidious App', // アプリのタイトル
      theme: ThemeData(
        primarySwatch: Colors.blue, // アプリのテーマカラーを青に設定
      ),
      home: MyHomePage(), // ホームページをMyHomePageクラスに設定
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState(); // ステートフルウィジェットの状態を生成
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController(); // テキストフィールドのコントローラー
  List _videos = []; // 動画リストを格納するためのリスト
  VideoPlayerController? _videoPlayerController; // 動画プレイヤーコントローラー
  String _server = 'https://invidious.nerdvpn.de'; // APIサーバーのURL

  // 動画を検索するための非同期メソッド
  Future<void> _searchVideos(String query) async {
    try {
      // APIにリクエストを送信
      final response = await http.get(Uri.parse('$_server/api/v1/search?q=$query'));
      if (response.statusCode == 200) {
        // 成功した場合、動画リストを更新
        setState(() {
          _videos = json.decode(utf8.decode(response.bodyBytes)); // JSONをデコードしてリストに格納
        });
      } else {
        // エラーメッセージを表示
        _showError('検索結果の読み込みに失敗しました');
      }
    } catch (e) {
      // エラーメッセージを表示
      _showError('エラー: $e');
    }
  }

  // 動画を再生するための非同期メソッド
  Future<void> _playVideo(String videoId) async {
    try {
      // 動画情報を取得するためにAPIにリクエストを送信
      final response = await http.get(Uri.parse('$_server/api/v1/videos/$videoId'));
      if (response.statusCode == 200) {
        final videoData = json.decode(response.body); // JSONをデコード
        final videoUrl = videoData['adaptiveFormats'].firstWhere(
              (format) => format['type'].startsWith('video'), // 動画フォーマットをフィルタリング
          orElse: () => null,
        )['url'];
        // 既存の動画プレイヤーコントローラーを破棄
        if (_videoPlayerController != null) {
          await _videoPlayerController!.dispose();
        }
        // 新しい動画プレイヤーコントローラーを初期化
        _videoPlayerController = VideoPlayerController.network(videoUrl)
          ..initialize().then((_) {
            setState(() {}); // UIの更新
            _videoPlayerController!.play(); // 動画再生
          });
      } else {
        // エラーメッセージを表示
        _showError('動画の読み込みに失敗しました');
      }
    } catch (e) {
      // エラーメッセージを表示
      _showError('エラー: $e');
    }
  }

  // 動画をダウンロードするための非同期メソッド
  Future<void> _downloadVideo(String videoId) async {
    try {
      // 動画情報を取得するためにAPIにリクエストを送信
      final response = await http.get(Uri.parse('$_server/api/v1/videos/$videoId'));
      if (response.statusCode == 200) {
        final videoData = json.decode(response.body); // JSONをデコード
        final videoUrl = videoData['adaptiveFormats'].firstWhere(
              (format) => format['type'].startsWith('video'), // 動画フォーマットをフィルタリング
          orElse: () => null,
        )['url'];
        // ストレージへの書き込みパーミッションをリクエスト
        final status = await Permission.storage.request();
        if (status.isGranted) {
          // ストレージディレクトリを取得
          final directory = await getExternalStorageDirectory();
          final filePath = '${directory!.path}/video.mp4'; // ダウンロード先のファイルパス
          final videoResponse = await http.get(Uri.parse(videoUrl)); // 動画データを取得
          final file = File(filePath); // ファイルオブジェクトを作成
          await file.writeAsBytes(videoResponse.bodyBytes); // バイトデータを書き込む
          // ダウンロード完了メッセージを表示
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('動画が $filePath にダウンロードされました')));
        }
      } else {
        // エラーメッセージを表示
        _showError('動画のダウンロードに失敗しました');
      }
    } catch (e) {
      // エラーメッセージを表示
      _showError('エラー: $e');
    }
  }

  // エラーメッセージを表示するためのメソッド
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); // スナックバーでエラーメッセージを表示
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose(); // 動画プレイヤーコントローラーを破棄
    super.dispose(); // スーパークラスのdisposeメソッドを呼び出す
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invidious App'), // アプリバーのタイトル
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0), // パディングを設定
              child: TextField(
                controller: _controller, // テキストフィールドのコントローラーを設定
                decoration: InputDecoration(
                  labelText: '検索', // ラベルテキスト
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search), // 検索アイコン
                    onPressed: () => _searchVideos(_controller.text), // 検索ボタンが押されたときの処理
                  ),
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true, // リストビューのサイズを調整
              physics: NeverScrollableScrollPhysics(), // スクロールの無効化
              itemCount: _videos.length, // 動画の数
              itemBuilder: (context, index) {
                final video = _videos[index]; // 動画データを取得
                return ListTile(
                  title: Text(video['title']), // 動画のタイトルを表示
                  onTap: () => _playVideo(video['videoId']), // タップで動画再生
                  trailing: IconButton(
                    icon: Icon(Icons.download), // ダウンロードアイコン
                    onPressed: () => _downloadVideo(video['videoId']), // ダウンロードボタンが押されたときの処理
                  ),
                );
              },
            ),
            // 動画プレイヤーの初期化が完了している場合は表示
            if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoPlayerController!.value.aspectRatio, // 動画のアスペクト比を設定
                child: VideoPlayer(_videoPlayerController!), // 動画プレイヤーを表示
              ),
          ],
        ),
      ),
    );
  }
}
