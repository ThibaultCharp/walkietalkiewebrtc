import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Walkie Talkie',
      theme: ThemeData.dark(),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  WebSocketChannel? _channel;
  int _peerCount = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _getUserMedia();
    _joinChannel();
  }

  void _joinChannel() {
    _channel = WebSocketChannel.connect(Uri.parse("ws://localhost:8000"));
    _channel!.stream.listen((message) async {
      Map<String, dynamic> data = jsonDecode(message);
      if (data["type"] == "offer") {
        await _setRemoteDescription(data);
        await _createAnswer();
      } else if (data["type"] == "answer") {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], 'answer'),
        );
      } else if (data["type"] == "candidate") {
        RTCIceCandidate candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
      } else if (data["type"] == "peerCount") {
        setState(() {
          _peerCount = data["count"];
        });
      }
    });
  }

  Future<void> _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {'audio': true, 'video': false};
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    setState(() {
      _localRenderer.srcObject = _localStream;
    });
  }

  Future<void> _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [{"urls": "stun:stun.l.google.com:19302"}]
    };
    _peerConnection = await createPeerConnection(configuration);
    _peerConnection!.onIceCandidate = (e) {
      if (e.candidate != null) {
        _channel!.sink.add(jsonEncode({
          "type": "candidate",
          "candidate": e.candidate,
          "sdpMid": e.sdpMid,
          "sdpMLineIndex": e.sdpMLineIndex,
        }));
      }
    };
    _peerConnection!.onTrack = (event) {
      setState(() {
        _remoteRenderer.srcObject = event.streams.first;
      });
    };
    for (var track in _localStream!.getTracks()) {
      _peerConnection!.addTrack(track, _localStream!);
    }
  }

  Future<void> _createOffer() async {
    await _createPeerConnection();
    RTCSessionDescription description = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(description);
    _channel!.sink.add(jsonEncode({"type": "offer", "sdp": description.sdp}));
  }

  Future<void> _createAnswer() async {
    RTCSessionDescription description = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(description);
    _channel!.sink.add(jsonEncode({"type": "answer", "sdp": description.sdp}));
  }

  Future<void> _setRemoteDescription(Map<String, dynamic> data) async {
    await _createPeerConnection();
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(data['sdp'], 'offer'),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Walkie Talkie"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Connected Peers: $_peerCount", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createOffer,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Join Channel"),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 100,
              width: 200,
              child: RTCVideoView(_localRenderer, mirror: true),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 100,
              width: 200,
              child: RTCVideoView(_remoteRenderer),
            ),
          ],
        ),
      ),
    );
  }
}
