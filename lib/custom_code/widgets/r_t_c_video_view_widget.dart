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
  // Remote video renderer for iOS audio playback
  late RTCVideoRenderer remoteRenderer;
  // Timer for remote stream sync
  Timer? _remoteStreamSyncTimer;
  // Flag to track initialization status
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderer();
  }

  /// Initialize the RTCVideoRenderer and setup sync with ConversationalAIService
  Future<void> _initializeRenderer() async {
    try {
      print('🎵 Initializing RTCVideoViewWidget for iOS audio playback fix');

      remoteRenderer = RTCVideoRenderer();
      await remoteRenderer.initialize();

      setState(() {
        _isInitialized = true;
      });

      // Setup sync with ConversationalAIService for iOS audio fix
      _setupRemoteStreamSync();

      print('✅ RTCVideoViewWidget initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize RTCVideoViewWidget: $e');
    }
  }

  @override
  void dispose() {
    print('🧹 Disposing RTCVideoViewWidget');
    _remoteStreamSyncTimer?.cancel();
    if (_isInitialized) {
      remoteRenderer.dispose();
    }
    super.dispose();
  }

  /// Setup sync with ConversationalAIService remote stream for iOS audio fix
  void _setupRemoteStreamSync() {
    print('🎵 Setting up remote stream sync for iOS audio playback');

    // Periodically check for remote stream and sync it to our renderer
    _remoteStreamSyncTimer =
        Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!_isInitialized) return;

      try {
        final service = ConversationalAIService.instance;
        final audioHandler = service.remoteRenderer;

        if (audioHandler != null && audioHandler.srcObject != null) {
          // If the service has a remote stream, sync it to our renderer
          if (remoteRenderer.srcObject != audioHandler.srcObject) {
            print(
                '🔄 Syncing remote stream to RTCVideoViewWidget for iOS audio');
            remoteRenderer.srcObject = audioHandler.srcObject;
          }
        }

        // Also try to get the stream directly from the service
        service.setRemoteStreamToRenderer(remoteRenderer);
      } catch (e) {
        // Silent catch - this is expected if no stream is available yet
        // Uncomment for debugging: print('⚠️ Stream sync attempt: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return SizedBox(
        width: widget.width ?? 1,
        height: widget.height ?? 1,
      );
    }

    return SizedBox(
      width: widget.width ?? 1,
      height: widget.height ?? 1,
      child: RTCVideoView(
        remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        placeholderBuilder: (context) => Container(
          width: widget.width ?? 1,
          height: widget.height ?? 1,
          color: Colors.transparent,
        ),
      ),
    );
  }
}
