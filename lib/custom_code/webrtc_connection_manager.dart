import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';

class WebRTCConnectionManager {
  // Production-Ready WebRTC Configuration optimized for ElevenLabs Conversational AI
  static const Map<String, dynamic> _baseConfiguration = {
    'iceServers': [
      // Primary Google STUN servers for ICE gathering (global availability)
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},

      // Additional reliable STUN servers for geographic redundancy
      {'urls': 'stun:stun.cloudflare.com:3478'},
      {'urls': 'stun:stun.nextcloud.com:443'},
      {'urls': 'stun:stun.stunprotocol.org:3478'},
      {'urls': 'stun:stun.voiparound.com'},
      {'urls': 'stun:stun.voipbuster.com'},

      // Production TURN servers for NAT traversal in restricted networks
      // Multiple transports and ports for maximum compatibility
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
        'credentialType': 'password',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
        'credentialType': 'password',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
        'credentialType': 'password',
      },
      {
        'urls': 'turns:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
        'credentialType': 'password',
      },
    ],
    'sdpSemantics': 'unified-plan',

    // Optimized ICE configuration for conversational AI latency requirements
    'iceCandidatePoolSize': 16, // Increased for better connectivity options
    'iceTransportPolicy':
        'all', // Use both STUN and TURN for maximum connectivity
    'bundlePolicy':
        'max-bundle', // Bundle all media on single transport for efficiency
    'rtcpMuxPolicy': 'require', // Multiplex RTP and RTCP on same port

    // Enhanced security configuration
    'enableDtlsSrtp': true,
    'enableRtpDataChannel': false, // Audio-only optimization

    // Performance optimizations for real-time conversation
    'continualGatheringPolicy': 'gather_continually',
    'enableCpuOveruseDetection': true,
    'enableHighStartBitrate': false, // Optimize for audio quality over video

    // ElevenLabs-specific optimizations
    'enableDscp': true, // Enable DSCP marking for QoS prioritization
    'enableIPv6': true, // Enable IPv6 for broader connectivity
    'maxIPv6Networks': 5, // Limit IPv6 networks for performance
    'disableIPv6OnWifi': false, // Allow IPv6 on WiFi
    'enableStunCandidateGeneration': true,
    'enableRelayUdpPortRange': true,

    // Audio-specific WebRTC optimizations
    'enableAudioNetworkAdaptor': true,
    'enableOpusDtx':
        true, // Discontinuous transmission for bandwidth efficiency
    'enableOpusFec':
        true, // Forward error correction for packet loss resilience
  };

  // Peer Connection Constraints
  static const Map<String, dynamic> _constraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  // Optimized Media Constraints for ElevenLabs Conversational AI
  // Based on ElevenLabs requirement: 16kHz mono audio with advanced processing
  static const Map<String, dynamic> _elevenLabsMediaConstraints = {
    'audio': {
      // ElevenLabs requirements
      'sampleRate': 16000,
      'channelCount': 1,
      'sampleSize': 16,

      // Essential WebRTC processing
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,

      // Opus codec settings for ElevenLabs
      'googOpusMaxPlaybackRate': 16000,
      'googOpusFec': true,
      'googOpusDtx': false, // Disable for ElevenLabs compatibility

      // Low latency settings
      'latency': 0.020, // 20ms for stability
      'bufferSize': 512, // Larger buffer for stability
    },
    'video': false,
  };

  // Fallback media constraints for compatibility
  // Simple, reliable constraints that work across most devices
  static const Map<String, dynamic> _fallbackMediaConstraints = {
    'audio': {
      // Basic WebRTC audio processing
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,

      // ElevenLabs requirements
      'sampleRate': 16000,
      'channelCount': 1,

      // Opus codec optimization (compatible settings)
      'opusMaxPlaybackRate': 16000,
      'opusFec': true, // Forward error correction
      'opusDtx': false, // Disable DTX for better compatibility
    },
    'video': false,
  };

  // Private members
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final List<RTCIceCandidate> _localCandidates = [];
  final List<RTCIceCandidate> _remoteCandidates = [];

  RTCPeerConnectionState _connectionState =
      RTCPeerConnectionState.RTCPeerConnectionStateNew;
  RTCIceConnectionState _iceConnectionState =
      RTCIceConnectionState.RTCIceConnectionStateNew;

  bool _isConnected = false;
  bool _isDisposed = false;

  // Configuration management
  Map<String, dynamic>? _customConfiguration;
  Map<String, dynamic>? _customMediaConstraints;
  bool _useProductionConfig =
      false; // Default to fallback constraints for device compatibility

  // Event handlers
  Function(RTCIceCandidate)? onIceCandidate;
  Function(RTCPeerConnectionState)? onConnectionStateChange;
  Function(RTCIceConnectionState)? onIceConnectionStateChange;
  Function(MediaStream)? onRemoteStream;
  Function(MediaStream)? onLocalStream; // CRITICAL: Callback for local stream
  Function(MediaStreamTrack)? onRemoteTrack;
  Function(String)? onError;
  Function()? onConnected;
  Function()? onDisconnected;

  // Getters
  RTCPeerConnection? get peerConnection => _peerConnection;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  RTCPeerConnectionState get connectionState => _connectionState;
  RTCIceConnectionState get iceConnectionState => _iceConnectionState;
  bool get isConnected => _isConnected;
  bool get isDisposed => _isDisposed;
  List<RTCIceCandidate> get localCandidates =>
      List.unmodifiable(_localCandidates);
  List<RTCIceCandidate> get remoteCandidates =>
      List.unmodifiable(_remoteCandidates);

  /// Configure custom TURN servers for production deployment
  ///
  /// Example usage:
  /// ```
  /// connectionManager.configureTurnServers([
  ///   {
  ///     'urls': 'turn:your-turn-server.com:3478',
  ///     'username': 'your-username',
  ///     'credential': 'your-password',
  ///   }
  /// ]);
  /// ```
  void configureTurnServers(List<Map<String, dynamic>> turnServers) {
    print('🔧 Configuring custom TURN servers...');
    print('   - Number of TURN servers: ${turnServers.length}');

    // Create custom configuration with provided TURN servers
    final customIceServers = List<Map<String, dynamic>>.from(
        _baseConfiguration['iceServers'] as List);

    // Add custom TURN servers
    for (final turnServer in turnServers) {
      if (turnServer['urls'] != null) {
        customIceServers.add(turnServer);
        print('   - Added TURN server: ${turnServer['urls']}');
      }
    }

    _customConfiguration = Map<String, dynamic>.from(_baseConfiguration);
    _customConfiguration!['iceServers'] = customIceServers;

    print('✅ Custom TURN servers configured');
    print('   - Total ICE servers: ${customIceServers.length}');
  }

  /// Configure media constraints for specific use cases
  ///
  /// Example usage:
  /// ```
  /// connectionManager.configureMediaConstraints({
  ///   'audio': {
  ///     'sampleRate': 48000,
  ///     'channelCount': 2,
  ///     'echoCancellation': false,
  ///   }
  /// });
  /// ```
  void configureMediaConstraints(Map<String, dynamic> constraints) {
    print('🎵 Configuring custom media constraints...');
    _customMediaConstraints = Map<String, dynamic>.from(constraints);
    print('✅ Custom media constraints configured');
    print('   - Audio constraints: ${constraints['audio']}');
    print('   - Video constraints: ${constraints['video']}');
  }

  /// Enable or disable production-optimized configuration
  void setProductionMode(bool enabled) {
    print('⚙️ ${enabled ? 'Enabling' : 'Disabling'} production mode...');
    _useProductionConfig = enabled;
    print('✅ Production mode ${enabled ? 'enabled' : 'disabled'}');
    if (enabled) {
      print('   - Using advanced ElevenLabs media constraints');
      print(
          '   - ⚠️ Note: Complex constraints may cause issues on some devices');
    } else {
      print('   - Using simplified fallback media constraints');
      print('   - ✅ Better device compatibility, basic audio quality');
    }
  }

  /// Enable compatibility mode for better device support
  /// This uses simplified media constraints that work on most devices
  void enableCompatibilityMode() {
    print('🛡️ Enabling compatibility mode for better device support...');
    setProductionMode(false);
    print('✅ Compatibility mode enabled');
    print('   - Simplified media constraints active');
    print('   - Reduced audio processing complexity');
    print('   - Better cross-device compatibility');
  }

  /// Enable debug mode with verbose logging and fallback constraints
  void enableDebugMode() {
    print('🐛 Enabling debug mode...');
    enableCompatibilityMode();
    print('✅ Debug mode enabled');
    print('   - Using fallback media constraints for stability');
    print('   - Enhanced logging active');
    print('   - Device compatibility prioritized over optimization');
  }

  /// Optimize SDP for Opus codec preference (ElevenLabs requirement)
  /// This method can be called to modify SDP offers/answers to prefer Opus codec
  String optimizeSDPForOpus(String sdp) {
    print('🎵 Optimizing SDP for Opus codec preference...');

    // Split SDP into lines for processing
    final lines = sdp.split('\r\n');
    final optimizedLines = <String>[];

    // Track audio media section
    bool inAudioSection = false;
    String? audioMLine;
    final List<String> audioCodecs = [];
    final List<String> opusPayloads = [];

    for (final line in lines) {
      if (line.startsWith('m=audio')) {
        inAudioSection = true;
        audioMLine = line;
        // Extract payload types from m=audio line
        final parts = line.split(' ');
        if (parts.length > 3) {
          audioCodecs.addAll(parts.sublist(3));
        }
      } else if (line.startsWith('m=')) {
        inAudioSection = false;
      }

      // Find Opus codec payload types
      if (inAudioSection &&
          line.contains('rtpmap') &&
          line.toLowerCase().contains('opus')) {
        final match = RegExp(r'a=rtpmap:(\d+)\s+opus', caseSensitive: false)
            .firstMatch(line);
        if (match != null) {
          opusPayloads.add(match.group(1)!);
          print('   - Found Opus codec with payload type: ${match.group(1)}');
        }
      }

      optimizedLines.add(line);
    }

    // Reorder codecs to prefer Opus
    if (audioMLine != null && opusPayloads.isNotEmpty) {
      print('   - Reordering audio codecs to prefer Opus...');
      final parts = audioMLine.split(' ');
      if (parts.length > 3) {
        final nonOpusCodecs = audioCodecs
            .where((codec) => !opusPayloads.contains(codec))
            .toList();
        final reorderedCodecs = [...opusPayloads, ...nonOpusCodecs];

        final newMLine =
            '${parts.sublist(0, 3).join(' ')} ${reorderedCodecs.join(' ')}';

        // Replace the m=audio line in optimizedLines
        for (int i = 0; i < optimizedLines.length; i++) {
          if (optimizedLines[i].startsWith('m=audio')) {
            optimizedLines[i] = newMLine;
            print('   - Updated m=audio line: $newMLine');
            break;
          }
        }
      }
    }

    final optimizedSDP = optimizedLines.join('\r\n');
    print('✅ SDP optimized for Opus codec preference');
    return optimizedSDP;
  }

  /// Get current configuration (for debugging)
  Map<String, dynamic> getCurrentConfiguration() {
    return Map<String, dynamic>.from(
        _customConfiguration ?? _baseConfiguration);
  }

  /// Get current media constraints (for debugging)
  Map<String, dynamic> getCurrentMediaConstraints() {
    final constraints = _customMediaConstraints ??
        (_useProductionConfig
            ? _elevenLabsMediaConstraints
            : _fallbackMediaConstraints);
    return Map<String, dynamic>.from(constraints);
  }

  /// Initialize and create WebRTC peer connection
  Future<RTCPeerConnection> initializePeerConnection() async {
    if (_isDisposed) {
      print(
          '❌ Cannot create peer connection: WebRTCConnectionManager has been disposed');
      throw Exception('WebRTCConnectionManager has been disposed');
    }

    if (_peerConnection != null) {
      print('⚠️ Peer connection already exists, skipping creation');
      return _peerConnection!;
    }

    try {
      // Get current configuration (custom or default)
      final configuration = getCurrentConfiguration();

      print('🔗 Creating WebRTC peer connection...');

      // Create the actual peer connection using flutter_webrtc API
      _peerConnection = await createPeerConnection(configuration, _constraints);

      // Set up event listeners
      _setupEventListeners();
      print('✅ WebRTC peer connection created successfully');

      return _peerConnection!;
    } catch (e) {
      final error = 'Failed to create peer connection: $e';
      print('❌ $error');
      print('🔍 Diagnostics:');
      print('   - Configuration: ${getCurrentConfiguration()}');
      print('   - Constraints: $_constraints');
      print('   - Production mode: $_useProductionConfig');
      print('   - Custom config: ${_customConfiguration != null}');
      onError?.call(error);
      rethrow;
    }
  }

  /// Get user media with optimized constraints for conversational AI
  Future<MediaStream> getUserMedia() async {
    if (_isDisposed) {
      print(
          '❌ Cannot get user media: WebRTCConnectionManager has been disposed');
      throw Exception('WebRTCConnectionManager has been disposed');
    }

    try {
      // Get current media constraints (custom or default)
      final mediaConstraints = getCurrentMediaConstraints();

      print('🎤 Requesting user media with optimized constraints:');
      print('   - Production mode: $_useProductionConfig');
      print(
          '   - Using constraints: ${_customMediaConstraints != null ? 'Custom' : (_useProductionConfig ? 'ElevenLabs Optimized' : 'Fallback')}');
      print('   - Audio constraints: ${mediaConstraints['audio']}');
      print('   - Video constraints: ${mediaConstraints['video']}');

      // MediaDevices is always available in flutter_webrtc

      print('📡 Calling getUserMedia with enhanced audio constraints...');

      // Try with optimized constraints first, fallback if needed
      try {
        _localStream =
            await navigator.mediaDevices.getUserMedia(mediaConstraints);
        print('✅ User media obtained with optimized constraints');
      } catch (optimizedError) {
        print('⚠️ Optimized constraints failed, trying fallback...');
        print('   - Error: $optimizedError');

        _localStream = await navigator.mediaDevices
            .getUserMedia(_fallbackMediaConstraints);
        print('✅ User media obtained with fallback constraints');
        print(
            '   - Consider updating your media constraints for better compatibility');
      }

      print('✅ Local media stream obtained successfully');
      print('📊 Stream details:');
      print('   - Stream ID: ${_localStream!.id}');
      print('   - Track count: ${_localStream!.getTracks().length}');

      // Verify tracks are valid
      if (_localStream!.getTracks().isEmpty) {
        print('❌ No tracks found in local media stream');
        throw Exception('No tracks found in local media stream');
      }

      // Log each track with detailed information
      print('🎵 Local tracks analysis:');
      for (final track in _localStream!.getTracks()) {
        print('   - Track kind: ${track.kind}');
        print('     ID: ${track.id}');
        print('     Enabled: ${track.enabled}');
      }

      // Add tracks to peer connection if it exists
      if (_peerConnection != null && _localStream != null) {
        print('🔗 Adding tracks to peer connection...');
        int tracksAdded = 0;
        int tracksFailed = 0;

        for (final track in _localStream!.getTracks()) {
          try {
            print(
                '📤 Adding ${track.kind} track (ID: ${track.id}, Enabled: ${track.enabled}) to peer connection...');
            final sender = await _peerConnection!.addTrack(track, _localStream!);
            tracksAdded++;
            print(
                '✅ Successfully added ${track.kind} track to peer connection with sender: ${sender.senderId}');
          } catch (trackError) {
            tracksFailed++;
            print(
                '❌ Failed to add ${track.kind} track to peer connection: $trackError');
            print(
                '🔍 Track details: kind=${track.kind}, id=${track.id}, enabled=${track.enabled}');
            onError?.call('Failed to add ${track.kind} track: $trackError');
          }
        }

        print('📊 Track addition summary:');
        print('   - Tracks added: $tracksAdded');
        print('   - Tracks failed: $tracksFailed');
        print('   - Total tracks: ${_localStream!.getTracks().length}');

        if (tracksAdded == 0) {
          print('❌ No tracks were successfully added to peer connection');
          throw Exception(
              'No tracks were successfully added to peer connection');
        }

        // Verify tracks were added by checking senders
        print('🔍 Verifying track addition through peer connection senders...');
        final senders = await _peerConnection!.getSenders();
        print(
            '📊 Peer connection has ${senders.length} senders after adding tracks');

        for (int i = 0; i < senders.length; i++) {
          final sender = senders[i];
          print('   - Sender $i:');
          print('     Track kind: ${sender.track?.kind}');
          print('     Track ID: ${sender.track?.id}');
          print('     Track enabled: ${sender.track?.enabled}');
        }
      } else {
        print('⚠️ Cannot add tracks - peer connection or local stream is null');
        if (_peerConnection == null) {
          print('❌ Peer connection is null, cannot add tracks');
          throw Exception('Peer connection is null, cannot add tracks');
        }
        if (_localStream == null) {
          print('❌ Local stream is null, cannot add tracks');
          throw Exception('Local stream is null, cannot add tracks');
        }
      }

      print(
          '🎉 User media acquisition and track addition completed successfully');

      // CRITICAL: Notify the callback about the local stream
      print('📤 Calling onLocalStream callback...');
      onLocalStream?.call(_localStream!);
      print('✅ onLocalStream callback completed');

      return _localStream!;
    } catch (e) {
      final error = 'Failed to get user media: $e';
      print('❌ $error');
      print(
          '🔍 Diagnostics: Media constraints=${getCurrentMediaConstraints()}, PeerConnection exists=${_peerConnection != null}');
      onError?.call(error);
      rethrow;
    }
  }

  /// Create WebRTC offer
  Future<RTCSessionDescription> createOffer({
    Map<String, dynamic>? constraints,
  }) async {
    if (_peerConnection == null) {
      throw Exception('PeerConnection not initialized');
    }

    try {
      final offerConstraints = constraints ??
          {
            'offerToReceiveAudio': true,
            'offerToReceiveVideo': false,
          };

      final offer = await _peerConnection!.createOffer(offerConstraints);
      await _peerConnection!.setLocalDescription(offer);

      print('WebRTC offer created: ${offer.type}');
      return offer;
    } catch (e) {
      final error = 'Failed to create offer: $e';
      print(error);
      onError?.call(error);
      rethrow;
    }
  }

  /// Create WebRTC answer
  Future<RTCSessionDescription> createAnswer({
    Map<String, dynamic>? constraints,
  }) async {
    if (_peerConnection == null) {
      throw Exception('PeerConnection not initialized');
    }

    try {
      final answerConstraints = constraints ??
          {
            'offerToReceiveAudio': true,
            'offerToReceiveVideo': false,
          };

      final answer = await _peerConnection!.createAnswer(answerConstraints);
      await _peerConnection!.setLocalDescription(answer);

      print('WebRTC answer created: ${answer.type}');
      return answer;
    } catch (e) {
      final error = 'Failed to create answer: $e';
      print(error);
      onError?.call(error);
      rethrow;
    }
  }

  /// Set remote session description
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (_peerConnection == null) {
      throw Exception('PeerConnection not initialized');
    }

    try {
      await _peerConnection!.setRemoteDescription(description);
      print('Remote description set: ${description.type}');

      // Add any queued remote candidates
      for (final candidate in _remoteCandidates) {
        await _peerConnection!.addCandidate(candidate);
      }
      _remoteCandidates.clear();
    } catch (e) {
      final error = 'Failed to set remote description: $e';
      print(error);
      onError?.call(error);
      rethrow;
    }
  }

  /// Add ICE candidate
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) {
      print('❌ Cannot add ICE candidate: PeerConnection not initialized');
      throw Exception('PeerConnection not initialized');
    }

    try {
      print('🧊 Processing ICE candidate:');
      print('   - Candidate: ${candidate.candidate}');
      print('   - SDP Mid: ${candidate.sdpMid}');
      print('   - SDP MLineIndex: ${candidate.sdpMLineIndex}');

      // Add candidate directly to peer connection
      print('🔗 Adding ICE candidate to peer connection...');
      await _peerConnection!.addCandidate(candidate);
      print('✅ ICE candidate added successfully to peer connection');
      print('📊 Total candidates processed: ${_remoteCandidates.length + 1}');
    } catch (e) {
      final error = 'Failed to add ICE candidate: $e';
      print('❌ $error');
      print(
          '🔍 Candidate details: candidate=${candidate.candidate}, sdpMid=${candidate.sdpMid}, sdpMLineIndex=${candidate.sdpMLineIndex}');
      print('🔍 Peer connection state: ${_peerConnection?.connectionState}');
      print(
          '🔍 Remote description exists: ${_peerConnection?.getRemoteDescription() != null}');
      onError?.call(error);
      rethrow;
    }
  }

  /// Get connection statistics
  Future<Map<String, dynamic>> getConnectionStats() async {
    if (_peerConnection == null) {
      return <String, dynamic>{};
    }

    try {
      final reports = await _peerConnection!.getStats();
      final Map<String, dynamic> result = <String, dynamic>{};

      // Handle StatsReport objects returned by getStats()
      for (var report in reports) {
        result[report.id] = report.values;
      }

      return result;
    } catch (e) {
      print('Failed to get connection stats: $e');
      return <String, dynamic>{};
    }
  }

  /// Toggle local audio track
  Future<void> toggleAudio({bool? enabled}) async {
    if (_localStream == null) return;

    try {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = enabled ?? !track.enabled;
      }
      print(
          'Audio tracks ${enabled ?? !audioTracks.first.enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      print('Failed to toggle audio: $e');
      onError?.call('Failed to toggle audio: $e');
    }
  }

  /// Mute/unmute local audio
  Future<void> muteAudio(bool mute) async {
    await toggleAudio(enabled: !mute);
  }

  /// Check if local audio is muted
  bool get isAudioMuted {
    if (_localStream == null) return true;
    final audioTracks = _localStream!.getAudioTracks();
    return audioTracks.isEmpty || !audioTracks.first.enabled;
  }

  /// Restart ICE connection
  Future<void> restartIce() async {
    if (_peerConnection == null) return;

    try {
      print('🔄 Restarting ICE connection...');
      await _peerConnection!.restartIce();
      print('✅ ICE connection restarted successfully');
    } catch (e) {
      print('❌ Failed to restart ICE: $e');
      onError?.call('Failed to restart ICE: $e');
    }
  }

  /// Monitor connection quality and performance
  Future<Map<String, dynamic>> getConnectionQuality() async {
    if (_peerConnection == null) {
      return {'status': 'disconnected', 'quality': 'unknown'};
    }

    try {
      print('📊 Analyzing connection quality...');
      final stats = await _peerConnection!.getStats();

      // Analyze statistics for quality metrics
      var audioQuality = 'unknown';
      var latency = 0.0;
      var packetLoss = 0.0;
      var jitter = 0.0;
      var bandwidth = 0.0;

      for (var report in stats) {
        final values = report.values;

        // Analyze audio quality metrics
        if (values['kind'] == 'audio') {
          if (values['type'] == 'inbound-rtp') {
            packetLoss = (values['packetsLost'] ?? 0).toDouble();
            jitter = (values['jitter'] ?? 0).toDouble();
            final bytesReceived = (values['bytesReceived'] ?? 0).toDouble();
            bandwidth = bytesReceived * 8 / 1000; // Convert to kbps
          }

          if (values['type'] == 'candidate-pair' &&
              values['state'] == 'succeeded') {
            latency = (values['currentRoundTripTime'] ?? 0).toDouble() *
                1000; // Convert to ms
          }
        }
      }

      // Determine overall quality
      if (packetLoss > 5.0 || latency > 300 || jitter > 0.1) {
        audioQuality = 'poor';
      } else if (packetLoss > 1.0 || latency > 150 || jitter > 0.05) {
        audioQuality = 'fair';
      } else if (latency < 100 && packetLoss < 0.5 && jitter < 0.03) {
        audioQuality = 'excellent';
      } else {
        audioQuality = 'good';
      }

      final qualityMetrics = <String, dynamic>{
        'status': 'connected',
        'quality': audioQuality,
        'latency_ms': latency,
        'packet_loss_percent': packetLoss,
        'jitter_seconds': jitter,
        'bandwidth_kbps': bandwidth,
        'connection_state': _connectionState.toString(),
        'ice_connection_state': _iceConnectionState.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('📊 Connection quality analysis complete:');
      print('   - Overall quality: $audioQuality');
      print('   - Latency: ${latency.toStringAsFixed(1)}ms');
      print('   - Packet loss: ${packetLoss.toStringAsFixed(2)}%');
      print('   - Jitter: ${(jitter * 1000).toStringAsFixed(1)}ms');
      print('   - Bandwidth: ${bandwidth.toStringAsFixed(1)} kbps');

      return qualityMetrics;
    } catch (e) {
      print('❌ Error analyzing connection quality: $e');
      return <String, dynamic>{
        'status': 'error',
        'quality': 'unknown',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Check if connection meets ElevenLabs quality requirements
  Future<bool> meetsElevenLabsQualityRequirements() async {
    final quality = await getConnectionQuality();

    final latency = quality['latency_ms'] ?? 1000.0;
    final packetLoss = quality['packet_loss_percent'] ?? 100.0;
    final jitter = quality['jitter_seconds'] ?? 1.0;

    // ElevenLabs requirements for real-time conversation
    final meetsRequirements =
        latency < 200 && packetLoss < 2.0 && jitter < 0.05;

    print('🎯 ElevenLabs quality check:');
    print(
        '   - Latency requirement (< 200ms): ${latency < 200 ? '✅' : '❌'} (${latency.toStringAsFixed(1)}ms)');
    print(
        '   - Packet loss requirement (< 2%): ${packetLoss < 2.0 ? '✅' : '❌'} (${packetLoss.toStringAsFixed(2)}%)');
    print(
        '   - Jitter requirement (< 50ms): ${jitter < 0.05 ? '✅' : '❌'} (${(jitter * 1000).toStringAsFixed(1)}ms)');
    print('   - Overall: ${meetsRequirements ? '✅ PASSED' : '❌ FAILED'}');

    return meetsRequirements;
  }

  /// Set up event listeners for peer connection
  void _setupEventListeners() {
    if (_peerConnection == null) return;

    // ICE candidate event
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _localCandidates.add(candidate);
      print('Local ICE candidate: ${candidate.candidate}');
      onIceCandidate?.call(candidate);
    };

    // Connection state change
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      final previousState = _connectionState;
      _connectionState = state;

      print('🔄 WebRTC connection state changed:');
      print('   - Previous state: $previousState');
      print('   - New state: $state');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');

      // Log detailed state information
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateNew:
          print('   - Status: Peer connection created but not yet connected');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
          print('   - Status: ICE connection is in progress');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          print('   - Status: Peer connection is established and working');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          print('   - Status: Peer connection is disconnected');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          print('   - Status: Peer connection has failed');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          print('   - Status: Peer connection has been closed');
          break;
      }

      onConnectionStateChange?.call(state);
      _updateConnectionStatus();
    };

    // ICE connection state change
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      final previousState = _iceConnectionState;
      _iceConnectionState = state;

      print('🧊 ICE connection state changed:');
      print('   - Previous state: $previousState');
      print('   - New state: $state');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');

      // Log detailed state information
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateNew:
          print('   - Status: ICE agent is gathering addresses');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateChecking:
          print('   - Status: ICE agent is checking candidates');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          print('   - Status: ICE agent has found a usable connection');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          print(
              '   - Status: ICE agent has finished gathering and checking candidates');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          print(
              '   - Status: ICE agent has checked all candidates and none worked');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          print('   - Status: ICE agent is disconnected');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          print(
              '   - Status: ICE agent has shut down and is no longer responding');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateCount:
          print('   - Status: ICE connection state count (internal use)');
          break;
      }

      onIceConnectionStateChange?.call(state);
      _updateConnectionStatus();
    };

    // Remote stream event
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print('🎵 Remote track event received: ${event.track.kind}');

      if (event.streams.isNotEmpty && event.track.kind == 'audio') {
        _remoteStream = event.streams[0];
        print('✅ Remote audio stream set successfully');

        // CRITICAL: Ensure audio tracks are enabled
        for (final track in _remoteStream!.getAudioTracks()) {
          track.enabled = true;
          print('✅ Enabled remote audio track: ${track.id}');
        }

        // Notify audio handler about remote stream
        onRemoteStream?.call(_remoteStream!);
      }

      onRemoteTrack?.call(event.track);
    };

    // Data channel event (not used for audio-only, but included for completeness)
    _peerConnection!.onDataChannel = (RTCDataChannel channel) {
      print('Data channel received: ${channel.label}');
    };

    // ICE gathering state change
    _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state: $state');
    };

    // Signaling state change
    _peerConnection!.onSignalingState = (RTCSignalingState state) {
      print('Signaling state: $state');
    };
  }

  /// Update connection status based on states
  void _updateConnectionStatus() {
    final wasConnected = _isConnected;

    _isConnected = (_connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
        _iceConnectionState ==
            RTCIceConnectionState.RTCIceConnectionStateConnected ||
        _iceConnectionState ==
            RTCIceConnectionState.RTCIceConnectionStateCompleted);

    if (_isConnected && !wasConnected) {
      print('WebRTC connection established');
      // Verify media streams are flowing
      _verifyMediaStreams();
      onConnected?.call();
    } else if (!_isConnected && wasConnected) {
      print('WebRTC connection lost');
      onDisconnected?.call();
    }
  }

  /// Verify media streams are flowing properly
  Future<void> _verifyMediaStreams() async {
    if (_peerConnection == null) {
      print('Cannot verify media streams: peer connection is null');
      return;
    }

    print('Verifying media streams are flowing properly...');

    // Check local stream
    if (_localStream != null) {
      final localTracks = _localStream!.getTracks();
      print('Local stream has ${localTracks.length} tracks');
      for (final track in localTracks) {
        print(
            'Local track: ${track.kind} (ID: ${track.id}, Enabled: ${track.enabled})');
      }
    } else {
      print('Local stream is null');
    }

    // Check remote stream
    if (_remoteStream != null) {
      final remoteTracks = _remoteStream!.getTracks();
      print('Remote stream has ${remoteTracks.length} tracks');
      for (final track in remoteTracks) {
        print(
            'Remote track: ${track.kind} (ID: ${track.id}, Enabled: ${track.enabled})');
        // Ensure remote audio tracks are enabled
        if (track.kind == 'audio' && !track.enabled) {
          print('Enabling remote audio track');
          track.enabled = true;
        }
      }
    } else {
      print('Remote stream is null');
    }

    // Check peer connection senders
    try {
      final senders = await _peerConnection!.getSenders();
      print('Peer connection has ${senders.length} senders');
      for (final sender in senders) {
        print(
            'Sender: ${sender.track?.kind} (ID: ${sender.track?.id}, Enabled: ${sender.track?.enabled})');
      }
    } catch (e) {
      print('Error getting senders: $e');
    }

    // Check peer connection receivers
    try {
      final receivers = await _peerConnection!.getReceivers();
      print('Peer connection has ${receivers.length} receivers');
      for (final receiver in receivers) {
        print(
            'Receiver: ${receiver.track?.kind} (ID: ${receiver.track?.id}, Enabled: ${receiver.track?.enabled})');
        // Ensure receiver tracks are enabled
        if (receiver.track?.kind == 'audio' &&
            !(receiver.track?.enabled ?? false)) {
          print('Enabling receiver audio track');
          receiver.track?.enabled = true;
        }
      }
    } catch (e) {
      print('Error getting receivers: $e');
    }

    // Get connection stats to verify media is flowing
    try {
      final stats = await getConnectionStats();
      print('Connection stats: $stats');
    } catch (e) {
      print('Error getting connection stats: $e');
    }
  }

  /// Close peer connection and clean up resources
  Future<void> close() async {
    if (_isDisposed) return;

    try {
      // Stop all tracks
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
      }

      if (_remoteStream != null) {
        await _remoteStream!.dispose();
        _remoteStream = null;
      }

      // Close peer connection
      if (_peerConnection != null) {
        await _peerConnection!.close();
        await _peerConnection!.dispose();
        _peerConnection = null;
      }

      // Clear candidates
      _localCandidates.clear();
      _remoteCandidates.clear();

      // Reset state
      _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateClosed;
      _iceConnectionState = RTCIceConnectionState.RTCIceConnectionStateClosed;
      _isConnected = false;

      print('WebRTC connection closed and resources cleaned up');
    } catch (e) {
      print('Error during WebRTC cleanup: $e');
    }
  }

  /// Dynamically optimize connection for current network conditions
  Future<void> optimizeForNetworkConditions() async {
    if (_peerConnection == null) {
      print('⚠️ Cannot optimize: peer connection not available');
      return;
    }

    try {
      print('🔧 Analyzing network conditions for optimization...');

      // Get current connection quality metrics
      final quality = await getConnectionQuality();
      final latency = quality['latency_ms'] ?? 0.0;
      final packetLoss = quality['packet_loss_percent'] ?? 0.0;
      final jitter = quality['jitter_seconds'] ?? 0.0;
      final bandwidth = quality['bandwidth_kbps'] ?? 0.0;

      print('📊 Current network metrics:');
      print('   - Latency: ${latency.toStringAsFixed(1)}ms');
      print('   - Packet Loss: ${packetLoss.toStringAsFixed(2)}%');
      print('   - Jitter: ${(jitter * 1000).toStringAsFixed(1)}ms');
      print('   - Bandwidth: ${bandwidth.toStringAsFixed(1)} kbps');

      // Determine network condition category
      String networkCondition = 'excellent';
      Map<String, dynamic> optimizedConstraints =
          Map<String, dynamic>.from(_elevenLabsMediaConstraints);

      if (packetLoss > 5.0 || latency > 300) {
        networkCondition = 'poor';
        print('📶 Poor network detected - applying aggressive optimizations');

        // Reduce quality for stability
        optimizedConstraints['audio']['sampleRate'] = 8000; // Reduce to 8kHz
        optimizedConstraints['audio']['opusMaxAverageBitrate'] =
            16000; // Lower bitrate
        optimizedConstraints['audio']['opusPtime'] = 40; // Larger packets
        optimizedConstraints['audio']['googNoiseSuppression'] =
            false; // Reduce processing
        optimizedConstraints['audio']['googAudioProcessing64Ms'] =
            true; // Larger processing window
      } else if (packetLoss > 2.0 || latency > 150) {
        networkCondition = 'fair';
        print('📶 Fair network detected - applying moderate optimizations');

        // Balanced optimization
        optimizedConstraints['audio']['sampleRate'] = 16000; // Keep 16kHz
        optimizedConstraints['audio']['opusMaxAverageBitrate'] =
            24000; // Moderate bitrate
        optimizedConstraints['audio']['opusPtime'] = 30; // Medium packets
        optimizedConstraints['audio']['googNoiseSuppression2'] =
            false; // Disable advanced NS
      } else if (latency < 50 && packetLoss < 0.5) {
        networkCondition = 'excellent';
        print('📶 Excellent network detected - applying quality optimizations');

        // High quality settings
        optimizedConstraints['audio']['sampleRate'] = 16000; // Keep 16kHz
        optimizedConstraints['audio']['opusMaxAverageBitrate'] =
            48000; // Higher bitrate
        optimizedConstraints['audio']['opusPtime'] =
            10; // Smaller packets for lower latency
        optimizedConstraints['audio']['latency'] = 0.003; // Ultra-low latency
        optimizedConstraints['audio']['bufferSize'] = 128; // Smaller buffer
      }

      print(
          '🎯 Applied optimizations for $networkCondition network conditions');

      // Store optimized constraints for future use
      _customMediaConstraints = optimizedConstraints;
      print('✅ Network optimization completed');
    } catch (e) {
      print('❌ Error optimizing for network conditions: $e');
      onError?.call('Network optimization failed: $e');
    }
  }

  /// Monitor connection stability and auto-optimize
  Future<void> startConnectionMonitoring(
      {Duration interval = const Duration(seconds: 30)}) async {
    print(
        '📡 Starting connection monitoring (interval: ${interval.inSeconds}s)');

    Timer.periodic(interval, (timer) async {
      if (_isDisposed || !_isConnected) {
        timer.cancel();
        print('📡 Connection monitoring stopped');
        return;
      }

      try {
        // Check if connection meets ElevenLabs requirements
        final meetsRequirements = await meetsElevenLabsQualityRequirements();

        if (!meetsRequirements) {
          print('⚠️ Connection quality below requirements - auto-optimizing');
          await optimizeForNetworkConditions();
        }

        // Log periodic quality check
        final quality = await getConnectionQuality();
        print(
            '📊 Periodic quality check: ${quality['quality']} (${quality['latency_ms']}ms)');
      } catch (e) {
        print('❌ Error during connection monitoring: $e');
      }
    });
  }

  /// Get comprehensive connection diagnostics for ElevenLabs optimization
  Future<Map<String, dynamic>> getElevenLabsDiagnostics() async {
    if (_peerConnection == null) {
      return <String, dynamic>{
        'status': 'no_connection',
        'error': 'Peer connection not available'
      };
    }

    try {
      print('🔍 Running ElevenLabs-specific diagnostics...');

      final quality = await getConnectionQuality();

      // Analyze audio-specific metrics
      var audioMetrics = <String, dynamic>{};
      var codecInfo = <String, dynamic>{};

      for (var report in await _peerConnection!.getStats()) {
        final values = report.values;

        if (values['type'] == 'inbound-rtp' && values['kind'] == 'audio') {
          audioMetrics = <String, dynamic>{
            'packetsReceived': values['packetsReceived'] ?? 0,
            'packetsLost': values['packetsLost'] ?? 0,
            'bytesReceived': values['bytesReceived'] ?? 0,
            'jitter': values['jitter'] ?? 0,
            'audioLevel': values['audioLevel'] ?? 0,
          };
        }

        if (values['type'] == 'codec' &&
            values['mimeType']?.contains('audio') == true) {
          codecInfo = <String, dynamic>{
            'mimeType': values['mimeType'] ?? 'unknown',
            'clockRate': values['clockRate'] ?? 0,
            'channels': values['channels'] ?? 0,
            'sdpFmtpLine': values['sdpFmtpLine'] ?? '',
          };
        }
      }

      // Calculate ElevenLabs-specific scores
      final latencyScore = quality['latency_ms'] < 100
          ? 100
          : quality['latency_ms'] < 200
              ? 75
              : quality['latency_ms'] < 300
                  ? 50
                  : 25;

      final qualityScore = quality['packet_loss_percent'] < 1.0
          ? 100
          : quality['packet_loss_percent'] < 2.0
              ? 75
              : quality['packet_loss_percent'] < 5.0
                  ? 50
                  : 25;

      final overallScore = (latencyScore + qualityScore) / 2;

      final diagnostics = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'overall_score': overallScore,
        'status': overallScore >= 75
            ? 'excellent'
            : overallScore >= 50
                ? 'good'
                : overallScore >= 25
                    ? 'fair'
                    : 'poor',
        'connection_quality': quality,
        'audio_metrics': audioMetrics,
        'codec_info': codecInfo,
        'meets_elevenlabs_requirements':
            await meetsElevenLabsQualityRequirements(),
        'ice_connection_state': _iceConnectionState.toString(),
        'peer_connection_state': _connectionState.toString(),
        'local_candidates_count': _localCandidates.length,
        'remote_candidates_count': _remoteCandidates.length,
        'recommendations': _generateOptimizationRecommendations(quality),
      };

      print('📊 ElevenLabs diagnostics completed:');
      print('   - Overall Score: ${overallScore.toStringAsFixed(1)}/100');
      print('   - Status: ${diagnostics['status']}');
      print(
          '   - Meets Requirements: ${diagnostics['meets_elevenlabs_requirements']}');

      return diagnostics;
    } catch (e) {
      print('❌ Error running ElevenLabs diagnostics: $e');
      return <String, dynamic>{'status': 'error', 'error': e.toString()};
    }
  }

  /// Generate optimization recommendations based on current metrics
  List<String> _generateOptimizationRecommendations(
      Map<String, dynamic> quality) {
    final recommendations = <String>[];

    final latency = quality['latency_ms'] ?? 0.0;
    final packetLoss = quality['packet_loss_percent'] ?? 0.0;
    final jitter = quality['jitter_seconds'] ?? 0.0;
    final bandwidth = quality['bandwidth_kbps'] ?? 0.0;

    if (latency > 200) {
      recommendations.add(
          'High latency detected: Consider using a closer TURN server or optimizing network path');
    }

    if (packetLoss > 2.0) {
      recommendations.add(
          'Packet loss detected: Enable Opus FEC and consider reducing bitrate');
    }

    if (jitter > 0.05) {
      recommendations.add(
          'High jitter detected: Consider enabling adaptive jitter buffer or QoS prioritization');
    }

    if (bandwidth < 20) {
      recommendations.add(
          'Low bandwidth detected: Reduce audio bitrate and enable Opus DTX');
    }

    if (_localCandidates.length < 3) {
      recommendations
          .add('Few ICE candidates: Verify STUN/TURN server configuration');
    }

    if (recommendations.isEmpty) {
      recommendations
          .add('Connection quality is excellent - no optimizations needed');
    }

    return recommendations;
  }

  /// Dispose the connection manager
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    await close();

    // Clear event handlers
    onIceCandidate = null;
    onConnectionStateChange = null;
    onIceConnectionStateChange = null;
    onRemoteStream = null;
    onRemoteTrack = null;
    onError = null;
    onConnected = null;
    onDisconnected = null;

    print('WebRTCConnectionManager disposed');
  }
}
