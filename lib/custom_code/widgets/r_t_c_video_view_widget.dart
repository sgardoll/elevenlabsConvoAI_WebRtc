// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../conversational_ai_service.dart';
import 'dart:async';

/// Custom widget for iOS audio playback fix using hidden RTCVideoView This
/// widget creates a hidden RTCVideoRenderer that syncs with the
/// ConversationalAIService to ensure remote audio streams are played
/// correctly on iOS devices
class RTCVideoViewWidget extends StatefulWidget {
  const RTCVideoViewWidget({
    super.key,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;

  @override
  State<RTCVideoViewWidget> createState() => _RTCVideoViewWidgetState();
}

class _RTCVideoViewWidgetState extends State<RTCVideoViewWidget> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    _subscribeToService();
  }

  void _subscribeToService() {
    final service = ConversationalAIService.instance;
    _stateSubscription = service.stateStream.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ConversationalAIService.instance;
    final localStream = service.localRenderer?.srcObject;
    final remoteStream = service.remoteRenderer?.srcObject;

    if (localStream != null) {
      _localRenderer.srcObject = localStream;
    }

    if (remoteStream != null) {
      _remoteRenderer.srcObject = remoteStream;
    }

    // Render both local and remote video views in a stack.
    // They are 1x1 pixels, so they won't be visible.
    return Stack(
      children: [
        SizedBox(
          width: 1.0,
          height: 1.0,
          child: RTCVideoView(
            _localRenderer,
            mirror: true,
          ),
        ),
        SizedBox(
          width: 1.0,
          height: 1.0,
          child: RTCVideoView(
            _remoteRenderer,
            mirror: true,
          ),
        ),
      ],
    );
  }
}
