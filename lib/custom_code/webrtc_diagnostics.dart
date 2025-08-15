import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_connection_manager.dart';
import 'webrtc_audio_handler.dart';
import 'webrtc_signaling_service.dart';
import 'conversational_ai_service.dart';

class WebRTCDiagnostics {
  static final WebRTCDiagnostics _instance = WebRTCDiagnostics._internal();
  factory WebRTCDiagnostics() => _instance;
  WebRTCDiagnostics._internal();

  /// Run comprehensive diagnostics to identify WebRTC connection issues
  Future<Map<String, dynamic>> runDiagnostics() async {
    print('🔍 Starting WebRTC diagnostics...');

    final results = <String, dynamic>{};

    // Test 1: Check WebRTC support
    results['webrtcSupport'] = await _checkWebRTCSupport();

    // Test 2: Check media permissions
    results['mediaPermissions'] = await _checkMediaPermissions();

    // Test 3: Test local media stream
    results['localMediaStream'] = await _testLocalMediaStream();

    // Test 4: Test peer connection creation
    results['peerConnection'] = await _testPeerConnection();

    // Test 5: Test audio handler
    results['audioHandler'] = await _testAudioHandler();

    print('🔍 Diagnostics completed');
    return results;
  }

  /// Check if WebRTC is supported
  Future<Map<String, dynamic>> _checkWebRTCSupport() async {
    print('📱 Checking WebRTC support...');

    try {
      // Check if WebRTC is available by trying to create a peer connection
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'}
        ],
      };
      final peerConnection = await createPeerConnection(configuration);
      await peerConnection.close();
      await peerConnection.dispose();

      print('✅ WebRTC is supported');

      return {
        'supported': true,
        'userAgent': 'Flutter WebRTC',
        'error': null,
      };
    } catch (e) {
      print('❌ WebRTC support check failed: $e');
      return {
        'supported': false,
        'userAgent': 'Flutter WebRTC',
        'error': e.toString(),
      };
    }
  }

  /// Check media permissions
  Future<Map<String, dynamic>> _checkMediaPermissions() async {
    print('🎤 Checking media permissions...');

    try {
      // Check if we can get user media
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      // Stop the stream immediately after testing
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();

      print('✅ Media permissions granted');

      return {
        'audioPermission': true,
        'videoPermission': false, // We didn't request video
        'error': null,
      };
    } catch (e) {
      print('❌ Media permissions check failed: $e');
      return {
        'audioPermission': false,
        'videoPermission': false,
        'error': e.toString(),
      };
    }
  }

  /// Test local media stream creation
  Future<Map<String, dynamic>> _testLocalMediaStream() async {
    print('🎵 Testing local media stream creation...');

    try {
      final connectionManager = WebRTCConnectionManager();

      // Test getting user media
      final stream = await connectionManager.getUserMedia();

      final tracks = stream.getTracks();
      final audioTracks = tracks.where((t) => t.kind == 'audio').toList();

      print('✅ Local media stream created successfully');
      print(
          '📊 Stream contains ${tracks.length} tracks (${audioTracks.length} audio)');

      // Clean up
      await connectionManager.close();

      return {
        'success': true,
        'totalTracks': tracks.length,
        'audioTracks': audioTracks.length,
        'videoTracks': tracks.where((t) => t.kind == 'video').length,
        'tracks': tracks
            .map((t) => {
                  'kind': t.kind,
                  'id': t.id,
                  'enabled': t.enabled,
                })
            .toList(),
        'error': null,
      };
    } catch (e) {
      print('❌ Local media stream creation failed: $e');
      return {
        'success': false,
        'totalTracks': 0,
        'audioTracks': 0,
        'videoTracks': 0,
        'tracks': [],
        'error': e.toString(),
      };
    }
  }

  /// Test peer connection creation
  Future<Map<String, dynamic>> _testPeerConnection() async {
    print('🔗 Testing peer connection creation...');

    try {
      final connectionManager = WebRTCConnectionManager();

      // Create peer connection
      final peerConnection = await connectionManager.initializePeerConnection();

      print('✅ Peer connection created successfully');
      print('📊 Connection state: ${peerConnection.connectionState}');
      print('📊 ICE connection state: ${peerConnection.iceConnectionState}');

      // Clean up
      await connectionManager.close();

      return {
        'success': true,
        'connectionState': peerConnection.connectionState.toString(),
        'iceConnectionState': peerConnection.iceConnectionState.toString(),
        'signalingState': peerConnection.signalingState.toString(),
        'error': null,
      };
    } catch (e) {
      print('❌ Peer connection creation failed: $e');
      return {
        'success': false,
        'connectionState': 'Unknown',
        'iceConnectionState': 'Unknown',
        'signalingState': 'Unknown',
        'error': e.toString(),
      };
    }
  }

  /// Test audio handler
  Future<Map<String, dynamic>> _testAudioHandler() async {
    print('🎵 Testing audio handler...');

    try {
      final audioHandler = WebRTCAudioHandler();

      // Initialize audio handler
      await audioHandler.initialize();

      print('✅ Audio handler initialized successfully');

      // Get audio stats
      final stats = audioHandler.getAudioStats();

      print('📊 Audio handler stats: $stats');

      // Clean up
      await audioHandler.dispose();

      return {
        'success': true,
        'initialized': true,
        'stats': stats,
        'error': null,
      };
    } catch (e) {
      print('❌ Audio handler test failed: $e');
      return {
        'success': false,
        'initialized': false,
        'stats': {},
        'error': e.toString(),
      };
    }
  }

  /// Print diagnostic results in a readable format
  void printResults(Map<String, dynamic> results) {
    print('\n📋 WEBRTC DIAGNOSTIC RESULTS');
    print('=' * 50);

    // WebRTC Support
    final webrtcSupport = results['webrtcSupport'];
    print('📱 WebRTC Support:');
    print('  Supported: ${webrtcSupport['supported']}');
    print('  User Agent: ${webrtcSupport['userAgent']}');
    if (webrtcSupport['error'] != null) {
      print('  Error: ${webrtcSupport['error']}');
    }
    print('');

    // Media Permissions
    final mediaPermissions = results['mediaPermissions'];
    print('🎤 Media Permissions:');
    print('  Audio Permission: ${mediaPermissions['audioPermission']}');
    print('  Video Permission: ${mediaPermissions['videoPermission']}');
    if (mediaPermissions['error'] != null) {
      print('  Error: ${mediaPermissions['error']}');
    }
    print('');

    // Local Media Stream
    final localMediaStream = results['localMediaStream'];
    print('🎵 Local Media Stream:');
    print('  Success: ${localMediaStream['success']}');
    print('  Total Tracks: ${localMediaStream['totalTracks']}');
    print('  Audio Tracks: ${localMediaStream['audioTracks']}');
    print('  Video Tracks: ${localMediaStream['videoTracks']}');
    if (localMediaStream['error'] != null) {
      print('  Error: ${localMediaStream['error']}');
    }
    print('');

    // Peer Connection
    final peerConnection = results['peerConnection'];
    print('🔗 Peer Connection:');
    print('  Success: ${peerConnection['success']}');
    print('  Connection State: ${peerConnection['connectionState']}');
    print('  ICE Connection State: ${peerConnection['iceConnectionState']}');
    print('  Signaling State: ${peerConnection['signalingState']}');
    if (peerConnection['error'] != null) {
      print('  Error: ${peerConnection['error']}');
    }
    print('');

    // Audio Handler
    final audioHandler = results['audioHandler'];
    print('🎵 Audio Handler:');
    print('  Success: ${audioHandler['success']}');
    print('  Initialized: ${audioHandler['initialized']}');
    print('  Stats: ${audioHandler['stats']}');
    if (audioHandler['error'] != null) {
      print('  Error: ${audioHandler['error']}');
    }
    print('');

    print('=' * 50);
    print('🔍 Diagnostic complete!\n');
  }

  /// Generate recommendations based on diagnostic results
  List<String> generateRecommendations(Map<String, dynamic> results) {
    final recommendations = <String>[];

    // Check WebRTC support
    if (!results['webrtcSupport']['supported']) {
      recommendations.add('❌ WebRTC is not supported on this device/browser');
    }

    // Check media permissions
    if (!results['mediaPermissions']['audioPermission']) {
      recommendations
          .add('❌ Audio permission not granted - check app permissions');
    }

    // Check local media stream
    if (!results['localMediaStream']['success']) {
      recommendations.add(
          '❌ Failed to create local media stream - check microphone access');
    } else if (results['localMediaStream']['audioTracks'] == 0) {
      recommendations.add('⚠️ No audio tracks found in local stream');
    }

    // Check peer connection
    if (!results['peerConnection']['success']) {
      recommendations.add('❌ Failed to create peer connection');
    }

    // Check audio handler
    if (!results['audioHandler']['success']) {
      recommendations.add('❌ Audio handler initialization failed');
    }

    if (recommendations.isEmpty) {
      recommendations
          .add('✅ All basic WebRTC components are working correctly');
      recommendations
          .add('🔍 The issue may be in the signaling or remote connection');
    }

    return recommendations;
  }

  /// Test media stream flow to verify frames are being received and processed
  Future<Map<String, dynamic>> testMediaStreamFlow() async {
    print('🔄 Testing media stream flow...');

    try {
      final results = <String, dynamic>{};

      // Create a test connection manager
      final connectionManager = WebRTCConnectionManager();

      // Set up event listeners to track stream flow
      final streamReceived = Completer<bool>();
      final tracksReceived = Completer<bool>();
      final connectionEstablished = Completer<bool>();

      connectionManager.onRemoteStream = (stream) {
        print('🎵 Test: Remote stream received');
        results['remoteStreamReceived'] = true;
        results['remoteStreamId'] = stream.id;
        results['remoteStreamTracks'] = stream.getTracks().length;

        if (!streamReceived.isCompleted) {
          streamReceived.complete(true);
        }
      };

      connectionManager.onRemoteTrack = (track) {
        print('🎵 Test: Remote track received: ${track.kind}');
        results['remoteTrackReceived'] = true;
        results['remoteTrackKind'] = track.kind;
        results['remoteTrackId'] = track.id;
        results['remoteTrackEnabled'] = track.enabled;

        if (!tracksReceived.isCompleted) {
          tracksReceived.complete(true);
        }
      };

      connectionManager.onConnected = () {
        print('🔗 Test: Connection established');
        results['connectionEstablished'] = true;

        if (!connectionEstablished.isCompleted) {
          connectionEstablished.complete(true);
        }
      };

      // Create peer connection
      final peerConnection = await connectionManager.initializePeerConnection();
      results['peerConnectionCreated'] = true;

      // Get user media
      final localStream = await connectionManager.getUserMedia();
      results['localStreamCreated'] = true;
      results['localStreamId'] = localStream.id;
      results['localStreamTracks'] = localStream.getTracks().length;

      // Check if tracks were added to peer connection
      final senders = await peerConnection.getSenders();
      results['sendersCount'] = senders.length;
      results['tracksAddedToPeerConnection'] = senders.isNotEmpty;

      // Wait for connection establishment (with timeout)
      final connectionResult = await connectionEstablished.future.timeout(
        Duration(seconds: 10),
        onTimeout: () => false,
      );
      results['connectionEstablished'] = connectionResult;

      // Wait for stream reception (with timeout)
      final streamResult = await streamReceived.future.timeout(
        Duration(seconds: 10),
        onTimeout: () => false,
      );
      results['remoteStreamReceived'] = streamResult;

      // Wait for track reception (with timeout)
      final trackResult = await tracksReceived.future.timeout(
        Duration(seconds: 10),
        onTimeout: () => false,
      );
      results['remoteTrackReceived'] = trackResult;

      // Get connection stats
      final stats = await connectionManager.getConnectionStats();
      results['connectionStats'] = stats;

      // Check if there are any active media flows
      bool hasActiveMediaFlow = false;
      if (stats.isNotEmpty) {
        // Look for stats that indicate media flow
        for (final reportId in stats.keys) {
          final report = stats[reportId];
          if (report is Map<String, dynamic>) {
            // Check for bytes sent/received
            if (report['bytesSent'] != null ||
                report['bytesReceived'] != null) {
              hasActiveMediaFlow = true;
              break;
            }
            // Check for packets sent/received
            if (report['packetsSent'] != null ||
                report['packetsReceived'] != null) {
              hasActiveMediaFlow = true;
              break;
            }
          }
        }
      }
      results['hasActiveMediaFlow'] = hasActiveMediaFlow;

      // Clean up
      await connectionManager.close();

      print('✅ Media stream flow test completed');
      return results;
    } catch (e) {
      print('❌ Media stream flow test failed: $e');
      return {
        'error': e.toString(),
        'success': false,
      };
    }
  }

  /// Print media stream flow test results
  void printMediaStreamFlowResults(Map<String, dynamic> results) {
    print('\n📋 MEDIA STREAM FLOW TEST RESULTS');
    print('=' * 50);

    if (results['error'] != null) {
      print('❌ Test failed with error: ${results['error']}');
      return;
    }

    print('🔗 Peer Connection:');
    print('  Created: ${results['peerConnectionCreated'] ?? false}');
    print('');

    print('🎤 Local Stream:');
    print('  Created: ${results['localStreamCreated'] ?? false}');
    if (results['localStreamCreated'] == true) {
      print('  Stream ID: ${results['localStreamId']}');
      print('  Tracks: ${results['localStreamTracks']}');
    }
    print('');

    print('📡 Track Addition:');
    print('  Senders Count: ${results['sendersCount'] ?? 0}');
    print(
        '  Tracks Added to Peer Connection: ${results['tracksAddedToPeerConnection'] ?? false}');
    print('');

    print('🔗 Connection:');
    print('  Established: ${results['connectionEstablished'] ?? false}');
    print('');

    print('🎵 Remote Stream:');
    print('  Received: ${results['remoteStreamReceived'] ?? false}');
    if (results['remoteStreamReceived'] == true) {
      print('  Stream ID: ${results['remoteStreamId']}');
      print('  Tracks: ${results['remoteStreamTracks']}');
    }
    print('');

    print('🎵 Remote Track:');
    print('  Received: ${results['remoteTrackReceived'] ?? false}');
    if (results['remoteTrackReceived'] == true) {
      print('  Track Kind: ${results['remoteTrackKind']}');
      print('  Track ID: ${results['remoteTrackId']}');
      print('  Track Enabled: ${results['remoteTrackEnabled']}');
    }
    print('');

    print('📊 Media Flow:');
    print('  Active Media Flow: ${results['hasActiveMediaFlow'] ?? false}');
    if (results['hasActiveMediaFlow'] == true) {
      print('  ✅ Media is flowing between peers');
    } else {
      print('  ❌ No media flow detected');
    }
    print('');

    print('=' * 50);
    print('🔍 Media stream flow test complete!\n');
  }
}
