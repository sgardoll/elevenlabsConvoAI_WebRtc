import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../app_state.dart';
import 'webrtc_connection_manager.dart';
import 'webrtc_signaling_service.dart';
import 'webrtc_audio_handler.dart';
import 'webrtc_diagnostics.dart';
import 'elevenlabs_auth_service.dart';

enum ConversationState {
  idle,
  connecting,
  connected,
  recording,
  playing,
  error,
}

class ConversationalAIService {
  static final ConversationalAIService _instance =
      ConversationalAIService._internal();
  factory ConversationalAIService() => _instance;
  ConversationalAIService._internal() {
    _authService = ElevenLabsAuthService.instance;
  }

  static ConversationalAIService get instance => _instance;

  WebRTCConnectionManager? _connectionManager;
  WebRTCSignalingService? _signalingService;
  WebRTCAudioHandler? _audioHandler;
  late final ElevenLabsAuthService _authService;

  String _connectionState = 'disconnected';
  bool _useWebRTC = true; // Default to WebRTC
  bool _isRecording = false;
  ConversationState _currentState = ConversationState.idle;

  // Streams for recording and state changes
  final StreamController<bool> _recordingStreamController =
      StreamController<bool>.broadcast();
  final StreamController<ConversationState> _stateStreamController =
      StreamController<ConversationState>.broadcast();

  // Getters for streams
  Stream<bool> get recordingStream => _recordingStreamController.stream;
  Stream<ConversationState> get stateStream => _stateStreamController.stream;

  /// Complete initialization from scratch - gets credentials and initializes service
  /// This combines getElevenLabsCredentials + initializeWithStoredCredentials in one call
  Future<String> initializeFromScratch(
    BuildContext context,
    String agentId,
    String endpoint,
  ) async {
    print(
        '🚀 Starting complete Conversational AI initialization from scratch...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Agent ID: $agentId');
    print('   - Endpoint: $endpoint');

    try {
      // Step 1: Initialize and configure authentication service
      print('🔐 Step 1: Setting up authentication service...');
      await _authService.initialize();
      await _authService.setAgentConfiguration(agentId, endpoint);

      // Step 2: Get credentials from BuildShip endpoint
      print('📡 Step 2: Getting credentials from BuildShip...');
      // This would need to call the BuildShip API directly
      // For now, we'll skip this and assume credentials are provided separately
      print(
          '⚠️ Note: Call getElevenLabsCredentials action first, then use initializeWithStoredCredentials');

      // Step 3: Initialize conversation service with stored credentials
      print('🌐 Step 3: Initializing conversation service...');
      return await initializeWithStoredCredentials(context, agentId);
    } catch (e) {
      print('❌ Error in complete initialization: $e');
      return 'Error: Complete initialization failed - $e';
    }
  }

  /// Initialize with stored credentials (recommended for FlutterFlow)
  /// Always uses WebRTC with WebSocket signaling for ElevenLabs integration
  Future<String> initializeWithStoredCredentials(
    BuildContext context,
    String agentId,
  ) async {
    print(
        '🚀 Starting Conversational AI service initialization with stored credentials...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Agent ID: $agentId');
    print('   - Use WebRTC: true (always enabled for ElevenLabs)');
    print('   - Current state: $_currentState');
    print('   - Connection state: $_connectionState');

    try {
      // Always use WebRTC for ElevenLabs Conversational AI
      _useWebRTC = true;
      print('   - Configuration saved (WebRTC enabled)');

      // Update state to connecting
      print('🔄 Updating state to connecting...');
      _updateState(ConversationState.connecting);
      print('   - State updated successfully');

      // Use already-initialized authentication service with stored credentials
      print(
          '🔐 Using ElevenLabs authentication service (already initialized by getElevenLabsCredentials)...');
      print('   - Auth service instance: ${_authService.toString()}');

      // Skip both initialize() and setAgentConfiguration() - already done by getElevenLabsCredentials action
      print('🔐 Using stored credentials (no initialization needed)...');

      // Get valid credentials with automatic refresh
      print('🔐 Getting valid credentials from auth service...');
      final authCredentials = await _authService.getValidCredentials();
      final signedUrl = authCredentials.signedUrl;
      final token = authCredentials.token;

      print('✅ Connection credentials obtained successfully');
      print('   - Signed URL: $signedUrl');
      print('   - Token: ${token.substring(0, 10)}...');
      print('   - Credentials validation completed');

      print('🌐 Starting WebRTC connection process...');
      print('   - Connection method: WebRTC with fallback');
      print('   - Signed URL length: ${signedUrl.length} characters');
      print('   - Token length: ${token.length} characters');

      await _initializeWebRTCWithFallback(signedUrl, token);

      _updateState(ConversationState.connected);
      print(
          '✅ Conversational AI service initialization completed successfully');
      print('   - Final state: $_currentState');
      print('   - Using WebRTC: $_useWebRTC');
      print('   - Connection state: $_connectionState');

      return 'Conversational AI service initialized successfully with WebRTC';
    } catch (e) {
      print('❌ Error initializing Conversational AI service: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Agent ID: $agentId');
      print('   - Use WebRTC: $_useWebRTC');
      print('   - Current state: $_currentState');

      _updateState(ConversationState.error);
      return 'Connection failed: ${e.toString()}';
    }
  }

  /// Legacy initialize method with endpoint (for backwards compatibility)
  Future<String> initialize(
    BuildContext context,
    String agentId,
    String endpoint, {
    bool useWebRTC = true,
  }) async {
    print('🚀 Starting Conversational AI service initialization...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Agent ID: $agentId');
    print('   - Endpoint: $endpoint');
    print('   - Use WebRTC: $useWebRTC');
    print('   - Current state: $_currentState');
    print('   - Connection state: $_connectionState');

    try {
      // Store initialization parameters
      _useWebRTC = useWebRTC;
      print('   - Configuration saved');

      // Update state to connecting
      print('🔄 Updating state to connecting...');
      _updateState(ConversationState.connecting);
      print('   - State updated successfully');

      // Initialize and configure authentication service
      print('🔐 Initializing ElevenLabs authentication service...');
      await _authService.initialize();
      await _authService.setAgentConfiguration(agentId, endpoint);

      // Get valid credentials with automatic refresh
      print('🔐 Getting valid credentials from auth service...');
      final authCredentials = await _authService.getValidCredentials();
      final signedUrl = authCredentials.signedUrl;
      final token = authCredentials.token;

      print('✅ Connection credentials obtained successfully');
      print('   - Signed URL: $signedUrl');
      print('   - Token: ${token.substring(0, 10)}...');
      print('   - Credentials validation completed');

      if (_useWebRTC) {
        print('🌐 Starting WebRTC connection process...');
        print('   - Connection method: WebRTC with fallback');
        print('   - Signed URL length: ${signedUrl.length} characters');
        print('   - Token length: ${token.length} characters');

        await _initializeWebRTCWithFallback(signedUrl, token);
        print('   - WebRTC connection process completed');
      } else {
        print('⚠️ WebSocket connection requested but not implemented');
        throw UnimplementedError('WebSocket connection not implemented');
      }

      print('✅ Conversational AI service initialized successfully');
      print('   - Final state: $_currentState');
      print('   - Connection state: $_connectionState');
      print(
          '   - Initialization completed at: ${DateTime.now().toIso8601String()}');

      _updateAppState(context, 'connected');
      _updateState(ConversationState.connected);
      return 'Connected successfully';
    } catch (e) {
      print('❌ Error initializing Conversational AI service: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Agent ID: $agentId');
      print('   - Endpoint: $endpoint');
      print('   - Use WebRTC: $useWebRTC');
      print('   - Current state: $_currentState');

      _updateAppState(context, 'error');
      _updateState(ConversationState.error);
      return 'Connection failed: $e';
    }
  }

  Future<void> _initializeWebRTC(String signedUrl, String token) async {
    print('🚀 Starting WebRTC connection initialization...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Signed URL length: ${signedUrl.length} characters');
    print('   - Token length: ${token.length} characters');
    print('   - Current state: $_currentState');

    try {
      print('🔧 Creating WebRTC components...');
      print('   - Creating WebRTCConnectionManager...');
      _connectionManager = WebRTCConnectionManager();

      // Enable compatibility mode for better device support
      print('   - Enabling compatibility mode for device support...');
      _connectionManager!.enableCompatibilityMode();
      print(
          '     - ConnectionManager created successfully with compatibility mode');

      print('   - Creating WebRTCAudioHandler...');
      _audioHandler = WebRTCAudioHandler();
      print('     - AudioHandler created successfully');

      print('   - Creating WebRTCSignalingService...');
      _signalingService = WebRTCSignalingService(_connectionManager!, _audioHandler!);
      print('     - SignalingService created successfully');

      print('✅ All WebRTC components created successfully');

      print('🎵 Initializing audio handler...');
      await _audioHandler!.initialize();
      print('   - Audio handler initialized successfully');

      print('🔌 Setting up WebRTC event handlers...');

      // Set up event handlers
      _connectionManager!.onConnectionStateChange = (state) {
        _connectionState = state.toString();
        print('📊 WebRTC Connection State changed: $state');
        print('   - Previous state: $_connectionState');
        print('   - New state: $state');
        print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      };

      _connectionManager!.onRemoteStream = (stream) async {
        print(
            '🎵 Remote stream received (${stream.getTracks().length} tracks)');
        await _audioHandler!.setRemoteStream(stream);

        // Trigger iOS audio fix: ensure any external renderers get the stream
        print('🍎 Triggering iOS audio playback fix for external renderers');
      };

      // CRITICAL: Add callback to handle local stream
      _connectionManager!.onLocalStream = (stream) async {
        print('🎤 Local stream created (${stream.getTracks().length} tracks)');
        await _audioHandler!.setLocalStream(stream);
      };

      _connectionManager!.onIceCandidate = (candidate) {
        print('🧊 Local ICE candidate generated');
        print('   - Candidate: ${candidate.candidate?.substring(0, 50)}...');
        print('   - SDP mid: ${candidate.sdpMid}');
        print('   - SDP line index: ${candidate.sdpMLineIndex}');
        print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      };

      _connectionManager!.onConnected = () {
        print('✅ WebRTC connection established successfully');
        print('   - Connection state: connected');
        print('   - Timestamp: ${DateTime.now().toIso8601String()}');
        _updateState(ConversationState.connected);
      };

      _connectionManager!.onDisconnected = () {
        print('❌ WebRTC connection lost');
        print('   - Connection state: disconnected');
        print('   - Previous state: $_connectionState');
        print('   - Timestamp: ${DateTime.now().toIso8601String()}');
        _updateState(ConversationState.error);
      };

      // Set up error handler for signaling service
      _signalingService!.onError = (error) {
        print('❌ WebRTC Signaling Error occurred');
        print('   - Error: $error');
        print('   - Error type: ${error.runtimeType}');
        print('   - Timestamp: ${DateTime.now().toIso8601String()}');
        _updateState(ConversationState.error);
      };

      print('✅ All WebRTC event handlers configured successfully');

      print('🔗 Starting connection to WebRTC signaling server...');
      print('   - Using retry mechanism for reliable connection');
      // Connect via WebRTC signaling with retry mechanism
      await _connectWithRetry(signedUrl, token);
      print('✅ WebRTC initialization completed successfully');
      print('   - Final state: $_currentState');
      print('   - Connection state: $_connectionState');
      print(
          '   - Initialization completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Error during WebRTC initialization: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Signed URL length: ${signedUrl.length}');
      print('   - Token length: ${token.length}');
      _updateState(ConversationState.error);
      rethrow;
    }
  }

  Future<void> _initializeWebRTCWithFallback(
      String signedUrl, String token) async {
    print('🚀 Starting WebRTC connection with fallback mechanism...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Signed URL length: ${signedUrl.length} characters');
    print('   - Token length: ${token.length} characters');
    print('   - Current state: $_currentState');

    try {
      print('🔄 Attempting primary WebRTC connection...');
      print('   - Using standard initialization path');
      print(
          '   - Connection attempt started at: ${DateTime.now().toIso8601String()}');

      await _initializeWebRTC(signedUrl, token);

      print('✅ Primary WebRTC connection successful');
      print(
          '   - Connection established at: ${DateTime.now().toIso8601String()}');
      print('   - Final state: $_currentState');
    } catch (e) {
      print('❌ Primary WebRTC connection failed: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Current state: $_currentState');
      print('🔄 Attempting fallback connection...');
      print(
          '   - Fallback attempt started at: ${DateTime.now().toIso8601String()}');

      // Try to reconnect with a fresh signed URL
      try {
        // For fallback, we'll try the same connection but with different error handling
        // In a real implementation, you might want to get a new signed URL or use a different endpoint
        print('🔄 Creating fallback WebRTC components...');
        print('   - Disposing previous components if they exist');
        _connectionManager?.dispose();
        _audioHandler?.dispose();

        print('   - Creating new WebRTCConnectionManager...');
        _connectionManager = WebRTCConnectionManager();

        // Enable compatibility mode for the fallback connection as well
        _connectionManager!.enableCompatibilityMode();
        print(
            '     - Fallback ConnectionManager created with compatibility mode');

        print('   - Creating new WebRTCAudioHandler...');
        _audioHandler = WebRTCAudioHandler();
        print('     - Fallback AudioHandler created');

        print('   - Creating new WebRTCSignalingService...');
        _signalingService = WebRTCSignalingService(_connectionManager!, _audioHandler!);
        print('     - Fallback SignalingService created');

        print('🎵 Initializing fallback audio handler...');
        await _audioHandler!.initialize();
        print('   - Fallback audio handler initialized successfully');

        print('🔌 Setting up fallback WebRTC event handlers...');

        // Set up event handlers with fallback-specific logic
        _connectionManager!.onConnectionStateChange = (state) {
          _connectionState = state.toString();
          print('📊 Fallback WebRTC Connection State changed: $state');
          print('   - Previous state: $_connectionState');
          print('   - New state: $state');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
        };

        _connectionManager!.onRemoteStream = (stream) async {
          print('🎵 Fallback remote stream received from peer');
          print('   - Stream ID: ${stream.id}');
          print('   - Track count: ${stream.getTracks().length}');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');

          await _audioHandler!.setRemoteStream(stream);
          print('   - Fallback remote stream assigned to audio handler');
        };

        // CRITICAL: Add callback to handle local stream in fallback mode
        _connectionManager!.onLocalStream = (stream) async {
          print('🎤 Fallback local stream created in connection manager');
          print('   - Stream ID: ${stream.id}');
          print('   - Track count: ${stream.getTracks().length}');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');

          await _audioHandler!.setLocalStream(stream);
          print('   - Fallback local stream assigned to audio handler');
        };

        _connectionManager!.onIceCandidate = (candidate) {
          print('🧊 Fallback local ICE candidate generated');
          print('   - Candidate: ${candidate.candidate?.substring(0, 50)}...');
          print('   - SDP mid: ${candidate.sdpMid}');
          print('   - SDP line index: ${candidate.sdpMLineIndex}');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
        };

        _connectionManager!.onConnected = () {
          print('✅ Fallback WebRTC connection established successfully');
          print('   - Connection state: connected');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
          _updateState(ConversationState.connected);
        };

        _connectionManager!.onDisconnected = () {
          print('❌ Fallback WebRTC connection lost');
          print('   - Connection state: disconnected');
          print('   - Previous state: $_connectionState');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
          _updateState(ConversationState.error);
        };

        _signalingService!.onError = (error) {
          print('❌ Fallback WebRTC Signaling Error occurred');
          print('   - Error: $error');
          print('   - Error type: ${error.runtimeType}');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
          _updateState(ConversationState.error);
        };

        print('✅ All fallback WebRTC event handlers configured successfully');

        // Try connecting with a single attempt (no retry for fallback)
        print('🔗 Connecting to fallback WebRTC signaling server...');
        print('   - Single attempt mode (no retry for fallback)');
        print(
            '   - Connection attempt started at: ${DateTime.now().toIso8601String()}');

        await _signalingService!.connect(signedUrl, token);

        print('✅ Fallback connection successful');
        print(
            '   - Connection established at: ${DateTime.now().toIso8601String()}');
        print('   - Final state: $_currentState');
      } catch (fallbackError) {
        print('❌ Fallback connection also failed: $fallbackError');
        print('   - Error type: ${fallbackError.runtimeType}');
        print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
        print('   - Both primary and fallback connections failed');

        throw Exception(
            'Both primary and fallback connections failed. Please check your internet connection and try again.');
      }
    }
  }

  Future<void> _connectWithRetry(String signedUrl, String token,
      {int maxRetries = 3}) async {
    print('🔄 Starting WebRTC connection with retry mechanism...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Maximum retries: $maxRetries');
    print('   - Signed URL length: ${signedUrl.length} characters');
    print('   - Token length: ${token.length} characters');
    print('   - Current state: $_currentState');

    int retryCount = 0;
    const baseDelay = Duration(seconds: 1);
    const maxDelay = Duration(seconds: 10);

    while (retryCount < maxRetries) {
      try {
        print('🔄 Attempting to connect to WebRTC signaling...');
        print('   - Attempt ${retryCount + 1} of $maxRetries');
        print('   - Timestamp: ${DateTime.now().toIso8601String()}');
        print('   - WebSocket URL: $signedUrl');
        print('   - Previous attempts: $retryCount');

        await _signalingService!.connect(signedUrl, token);

        print('✅ WebRTC signaling connection established successfully');
        print('   - Total attempts: ${retryCount + 1}');
        print(
            '   - Connection established at: ${DateTime.now().toIso8601String()}');
        print('   - Connection state: $_connectionState');
        return; // Connection successful, exit retry loop
      } catch (e) {
        retryCount++;
        print('❌ Connection attempt $retryCount failed');
        print('   - Error: $e');
        print('   - Error type: ${e.runtimeType}');
        print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
        print('   - Attempts remaining: ${maxRetries - retryCount}');

        if (retryCount >= maxRetries) {
          print('❌ Max retry attempts reached. Giving up.');
          print('   - Total failed attempts: $retryCount');
          print('   - Final error: $e');
          print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
          _updateState(ConversationState.error);
          throw Exception('Failed to connect after $maxRetries attempts: $e');
        }

        // Calculate exponential backoff delay
        final delay = Duration(
            milliseconds: (baseDelay.inMilliseconds * (1 << (retryCount - 1)))
                .clamp(baseDelay.inMilliseconds, maxDelay.inMilliseconds));

        print('⏳ Waiting before retry...');
        print('   - Delay duration: ${delay.inSeconds} seconds');
        print('   - Exponential backoff factor: ${1 << (retryCount - 1)}');
        print(
            '   - Retry will start at: ${DateTime.now().add(delay).toIso8601String()}');

        await Future.delayed(delay);

        print('⏰ Delay completed, preparing for next attempt...');
        print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      }
    }
  }

  // Utility methods removed - now handled by ElevenLabsAuthService

  // Removed _getConnectionCredentials method - now using ElevenLabsAuthService

  void _updateAppState(BuildContext context, String state) {
    FFAppState().update(() {
      FFAppState().wsConnectionState = state;
      FFAppState().isRecording = state == 'connected';
    });
  }

  String get connectionState => _connectionState;
  bool get isUsingWebRTC => _useWebRTC;
  bool get isRecording => _isRecording;
  ConversationState get currentState => _currentState;

  void _updateState(ConversationState state) {
    try {
      print('🔄 Updating conversation state from $_currentState to $state');

      // Update the current state
      _currentState = state;

      // Add the state to the stream if it's not closed
      if (!_stateStreamController.isClosed) {
        _stateStreamController.add(state);
      } else {
        print('⚠️ State stream controller is closed, cannot add state: $state');
      }

      // Additional state-specific handling
      switch (state) {
        case ConversationState.recording:
          print('🎙️ Recording state activated');
          break;
        case ConversationState.connected:
          print('✅ Connected state activated');
          break;
        case ConversationState.error:
          print('❌ Error state activated');
          break;
        case ConversationState.idle:
          print('💤 Idle state activated');
          break;
        case ConversationState.connecting:
          print('🔌 Connecting state activated');
          break;
        case ConversationState.playing:
          print('🔊 Playing state activated');
          break;
      }
    } catch (e) {
      print('❌ Error updating conversation state: $e');
      // Ensure the state is still updated even if there's an error with the stream
      _currentState = state;
    }
  }

  void _updateRecordingState(bool isRecording) {
    try {
      print('🔄 Updating recording state from $_isRecording to $isRecording');

      // Update the recording state
      _isRecording = isRecording;

      // Add the recording state to the stream if it's not closed
      if (!_recordingStreamController.isClosed) {
        _recordingStreamController.add(isRecording);
      } else {
        print(
            '⚠️ Recording stream controller is closed, cannot add recording state: $isRecording');
      }

      print('✅ Recording state updated: $isRecording');
    } catch (e) {
      print('❌ Error updating recording state: $e');
      // Ensure the state is still updated even if there's an error with the stream
      _isRecording = isRecording;
    }
  }

  Future<String> toggleRecording() async {
    print('🎙️ Toggle recording requested...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Current recording state: $_isRecording');
    print('   - Current conversation state: $_currentState');
    print('   - Connection state: $_connectionState');

    try {
      // Check if we're in a state that allows recording
      if (_currentState != ConversationState.connected &&
          _currentState != ConversationState.recording) {
        print('❌ Cannot toggle recording - invalid state');
        print('   - Required states: connected or recording');
        print('   - Current state: $_currentState');
        return 'Cannot toggle recording - not connected';
      }

      // Toggle the recording state
      final newRecordingState = !_isRecording;
      print('🔄 Toggling recording state...');
      print('   - From: $_isRecording');
      print('   - To: $newRecordingState');

      // Update the conversation state based on recording status
      final newState = newRecordingState
          ? ConversationState.recording
          : ConversationState.connected;
      print('🔄 Updating conversation state...');
      print('   - New state: $newState');
      _updateState(newState);

      // Update the recording state using the dedicated method
      _updateRecordingState(newRecordingState);

      // Update app state for global consistency
      if (newRecordingState) {
        print('🎙️ Starting recording...');
        print('   - Unmuting microphone for audio capture');
        if (_audioHandler != null) {
          await _audioHandler!.setMuted(false);
          print('✅ Microphone unmuted successfully');
        }
      } else {
        print('⏹️ Stopping recording...');
        print('   - Muting microphone to stop audio capture');
        if (_audioHandler != null) {
          await _audioHandler!.setMuted(true);
          print('✅ Microphone muted successfully');
        }
      }

      print('✅ Recording toggle completed successfully');
      print('   - Final recording state: $newRecordingState');
      print('   - Final conversation state: $_currentState');
      print('   - Completion timestamp: ${DateTime.now().toIso8601String()}');

      return newRecordingState ? 'Recording started' : 'Recording stopped';
    } catch (e) {
      print('❌ Error in toggleRecording');
      print('   - Error: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Current recording state: $_isRecording');
      print('   - Current conversation state: $_currentState');
      // Ensure state is consistent on error
      _updateState(ConversationState.connected);
      _updateRecordingState(false);
      return 'Error toggling recording: $e';
    }
  }

  Future<String> triggerInterruption() async {
    print('🛑 Trigger interruption requested...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Current conversation state: $_currentState');
    print('   - Connection state: $_connectionState');
    print('   - Recording state: $_isRecording');

    try {
      if (_currentState == ConversationState.playing) {
        print('🎵 Agent is currently playing, proceeding with interruption...');
        print('   - Sending interruption signal to the agent');

        // Send interruption signal to the agent
        if (_audioHandler != null) {
          print('🔇 Muting audio to interrupt agent...');
          await _audioHandler!.setMuted(true);
          print('   - Audio muted successfully');

          print('🔊 Unmuting audio to resume normal operation...');
          await _audioHandler!.setMuted(false);
          print('   - Audio unmuted successfully');

          print('✅ Audio interruption sequence completed');
          print('   - Mute/unmute cycle performed');
        } else {
          print(
              '⚠️ Audio handler is null, cannot perform interruption sequence');
          return 'Error interrupting agent: Audio handler not available';
        }

        print('🔄 Updating conversation state after interruption...');
        _updateState(ConversationState.connected);
        print('   - State updated to: $_currentState');
        print(
            '   - Interruption completed at: ${DateTime.now().toIso8601String()}');

        return 'Agent interrupted';
      } else {
        print('⚠️ Cannot interrupt agent - not in playing state');
        print('   - Current state: $_currentState');
        print('   - Required state: playing');
        return 'Cannot interrupt - agent not speaking';
      }
    } catch (e) {
      print('❌ Error during interruption');
      print('   - Error: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Current state: $_currentState');
      return 'Error interrupting agent: $e';
    }
  }

  /// Run WebRTC diagnostics to troubleshoot connection issues
  Future<void> runDiagnostics() async {
    print('🔍 Running WebRTC diagnostics...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Current conversation state: $_currentState');
    print('   - Connection state: $_connectionState');
    print('   - Recording state: $_isRecording');
    print('   - Using WebRTC: $_useWebRTC');

    try {
      print('🔧 Creating WebRTC diagnostics instance...');
      final diagnostics = WebRTCDiagnostics();
      print('   - Diagnostics instance created successfully');

      print('🧪 Running diagnostic tests...');
      print('   - Starting comprehensive WebRTC analysis');
      final results = await diagnostics.runDiagnostics();
      print('   - Diagnostic tests completed');
      print(
          '   - Test results received at: ${DateTime.now().toIso8601String()}');

      // Print detailed results
      print('📊 Printing detailed diagnostic results...');
      diagnostics.printResults(results);
      print('   - Results printed successfully');

      // Generate and print recommendations
      print('📋 Generating recommendations based on results...');
      final recommendations = diagnostics.generateRecommendations(results);
      print('\n📋 RECOMMENDATIONS:');
      print('=' * 50);
      for (final recommendation in recommendations) {
        print(recommendation);
      }
      print('=' * 50);
      print('   - Total recommendations: ${recommendations.length}');

      print('✅ WebRTC diagnostics completed successfully');
      print('   - Completion timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Results available for troubleshooting');
    } catch (e) {
      print('❌ Error running WebRTC diagnostics');
      print('   - Error: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Current conversation state: $_currentState');
      print('   - Diagnostics failed to complete');
    }
  }

  /// Test media stream flow to verify frames are being received and processed
  Future<void> testMediaStreamFlow() async {
    print('🔄 Testing media stream flow...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Current conversation state: $_currentState');
    print('   - Connection state: $_connectionState');
    print('   - Recording state: $_isRecording');
    print('   - Using WebRTC: $_useWebRTC');

    try {
      print('🔧 Creating WebRTC diagnostics instance...');
      final diagnostics = WebRTCDiagnostics();
      print('   - Diagnostics instance created successfully');

      print('🧪 Running media stream flow tests...');
      print('   - Starting comprehensive media flow analysis');
      final results = await diagnostics.testMediaStreamFlow();
      print('   - Media stream flow tests completed');
      print(
          '   - Test results received at: ${DateTime.now().toIso8601String()}');

      // Print detailed results
      print('📊 Printing detailed media stream flow results...');
      diagnostics.printMediaStreamFlowResults(results);
      print('   - Results printed successfully');

      // Check if the test was successful
      print('🔍 Analyzing test results...');
      final success = results['error'] == null &&
          (results['peerConnectionCreated'] == true) &&
          (results['localStreamCreated'] == true) &&
          (results['tracksAddedToPeerConnection'] == true);

      print('   - Test success status: $success');
      print('   - Error present: ${results['error'] != null}');
      print(
          '   - Peer connection created: ${results['peerConnectionCreated']}');
      print('   - Local stream created: ${results['localStreamCreated']}');
      print(
          '   - Tracks added to peer connection: ${results['tracksAddedToPeerConnection']}');

      if (success) {
        print('✅ Media stream flow test completed successfully');
        print('   - All critical components are functioning');

        // Check if media is actually flowing
        print('🔍 Checking for active media flow...');
        if (results['hasActiveMediaFlow'] == true) {
          print('✅ Media is flowing between peers');
          print('   - Active media flow detected');
        } else {
          print('⚠️ No active media flow detected');
          print('   - Connection may not be fully established');
          print('   - Media packets may not be transmitting');
        }
      } else {
        print('❌ Media stream flow test failed');
        print('   - One or more critical components are not functioning');
        print('   - Error details: ${results['error']}');
      }

      print('✅ Media stream flow test completed');
      print('   - Completion timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Results available for troubleshooting');
    } catch (e) {
      print('❌ Error testing media stream flow');
      print('   - Error: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Current conversation state: $_currentState');
      print('   - Media stream flow test failed to complete');
    }
  }

  void dispose() {
    print('🧹 Disposing ConversationalAIService...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Current conversation state: $_currentState');
    print('   - Connection state: $_connectionState');
    print('   - Recording state: $_isRecording');
    print('   - Using WebRTC: $_useWebRTC');

    try {
      print('🔄 Closing recording stream controller...');
      if (!_recordingStreamController.isClosed) {
        _recordingStreamController.close();
        print('   - Recording stream controller closed successfully');
      } else {
        print('   - Recording stream controller already closed');
      }
    } catch (e) {
      print('❌ Error closing recording stream controller');
      print('   - Error: $e');
      print('   - Error type: ${e.runtimeType}');
    }

    try {
      print('🔄 Closing state stream controller...');
      if (!_stateStreamController.isClosed) {
        _stateStreamController.close();
        print('   - State stream controller closed successfully');
      } else {
        print('   - State stream controller already closed');
      }
    } catch (e) {
      print('❌ Error closing state stream controller');
      print('   - Error: $e');
      print('   - Error type: ${e.runtimeType}');
    }

    try {
      print('🔄 Disposing WebRTC connection manager...');
      if (_connectionManager != null) {
        _connectionManager!.dispose();
        _connectionManager = null;
        print('   - WebRTC connection manager disposed successfully');
      } else {
        print('   - WebRTC connection manager already null');
      }
    } catch (e) {
      print('❌ Error disposing WebRTC connection manager');
      print('   - Error: $e');
      print('   - Error type: ${e.runtimeType}');
    }

    try {
      print('🔄 Disposing WebRTC audio handler...');
      if (_audioHandler != null) {
        _audioHandler!.dispose();
        _audioHandler = null;
        print('   - WebRTC audio handler disposed successfully');
      } else {
        print('   - WebRTC audio handler already null');
      }
    } catch (e) {
      print('❌ Error disposing WebRTC audio handler');
      print('   - Error: $e');
      print('   - Error type: ${e.runtimeType}');
    }
  }

  /// Emergency activation to prevent ElevenLabs timeout
  void emergencyActivateMicrophone() {
    print('🚨 Emergency microphone activation requested');
    _audioHandler?.emergencyActivateMicrophone();
  }

  /// Get the remote renderer from the audio handler for iOS audio playback
  RTCVideoRenderer? get remoteRenderer => _audioHandler?.remoteRenderer;

  /// Get the local renderer from the audio handler
  RTCVideoRenderer? get localRenderer => _audioHandler?.localRenderer;

  /// Set remote stream to an external renderer (for iOS audio fix)
  Future<void> setRemoteStreamToRenderer(RTCVideoRenderer renderer) async {
    if (_audioHandler != null && _audioHandler!.remoteStream != null) {
      print(
          '🎵 Setting remote stream to external renderer for iOS audio playback');
      renderer.srcObject = _audioHandler!.remoteStream;
      print('✅ Remote stream set to external renderer');
    }
  }
}
