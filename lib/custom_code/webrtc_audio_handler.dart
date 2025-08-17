import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart'; // STEP 1: Add audio_session package
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

// Custom AudioSource for playing from a byte stream
class MyCustomSource extends StreamAudioSource {
  final List<int> bytes;
  MyCustomSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}

class WebRTCAudioHandler {
  // Audio renderers for WebRTC streams
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  AudioPlayer? _audioPlayer;

  // Stream references
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Audio control state
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isAgentSpeaking = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  // Advanced audio control
  double _inputVolume = 1.0;
  double _outputVolume = 1.0;
  String _currentAudioDevice = 'default';
  List<Map<String, dynamic>> _availableAudioDevices = [];

  // Audio quality monitoring
  double _audioQualityScore = 0.0;
  int _audioDropouts = 0;
  int _totalAudioPackets = 0;
  int _lostAudioPackets = 0;
  Timer? _qualityMonitorTimer;

  // Audio level monitoring
  double _inputLevel = 0.0;
  double _outputLevel = 0.0;
  Timer? _audioLevelTimer;
  Timer? _micGatingTimer;

  // Audio processing effects
  bool _echoCancellationEnabled = true;
  bool _noiseSuppressionEnabled = true;
  bool _autoGainControlEnabled = true;
  double _noiseSuppressionLevel = 0.8;
  double _echoCancellationLevel = 0.9;

  // Voice Activity Detection
  bool _vadEnabled = true;
  double _vadThreshold = 0.01;
  int _vadConsecutiveFrames = 0;
  static const int _vadRequiredFrames = 3;

  // Echo cancellation settings
  int _micGatingDelayMs = 100;

  // Event callbacks
  Function(double)? onInputLevelChanged;
  Function(double)? onOutputLevelChanged;
  Function(bool)? onVoiceActivityDetected;
  Function(bool)? onAgentSpeakingChanged;
  Function(String)? onError;
  Function(double)? onInputVolumeChanged;
  Function(double)? onOutputVolumeChanged;
  Function(String)? onAudioDeviceChanged;
  Function(List<Map<String, dynamic>>)? onAudioDevicesUpdated;
  Function(double)? onAudioQualityChanged;
  Function(Map<String, dynamic>)? onAudioStatsUpdated;

  // STEP 6: Updated ElevenLabs media constraints for better compatibility
  static const Map<String, dynamic> _enhancedAudioConstraints = {
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
      'sampleRate': 16000,
      'channelCount': 1,
      'latency': 0.020, // 20ms for stability
      'bufferSize': 512, // Larger buffer for stability
      // Remove Google-specific constraints that may not be supported
      'googEchoCancellation': true,
      'googAutoGainControl': true,
      'googNoiseSuppression': true,
      'googHighpassFilter': true,
    },
    'video': false,
  };

  // Getters
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isAgentSpeaking => _isAgentSpeaking;
  bool get isInitialized => _isInitialized;
  double get inputLevel => _inputLevel;
  double get outputLevel => _outputLevel;
  bool get vadEnabled => _vadEnabled;
  double get vadThreshold => _vadThreshold;
  double get inputVolume => _inputVolume;
  double get outputVolume => _outputVolume;
  String get currentAudioDevice => _currentAudioDevice;
  List<Map<String, dynamic>> get availableAudioDevices =>
      List.unmodifiable(_availableAudioDevices);
  double get audioQualityScore => _audioQualityScore;
  bool get echoCancellationEnabled => _echoCancellationEnabled;
  bool get noiseSuppressionEnabled => _noiseSuppressionEnabled;
  bool get autoGainControlEnabled => _autoGainControlEnabled;
  double get noiseSuppressionLevel => _noiseSuppressionLevel;
  double get echoCancellationLevel => _echoCancellationLevel;
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  MediaStream? get remoteStream => _remoteStream;

  Future<void> playBase64Audio(String base64String) async {
    try {
      final bytes = base64Decode(base64String);
      final source = MyCustomSource(bytes);
      await _audioPlayer!.setAudioSource(source);
      await _audioPlayer!.play();
    } catch (e) {
      print('Failed to play base64 audio: $e');
      onError?.call('Failed to play base64 audio: $e');
    }
  }

  /// Initialize the audio handler with full WebRTC setup
  Future<void> initialize() async {
    print('🎵 Starting WebRTC audio handler initialization...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print(
        '   - Initial state: initialized=$_isInitialized, disposed=$_isDisposed');

    if (_isDisposed) {
      print('❌ Cannot initialize - WebRTCAudioHandler has been disposed');
      throw Exception('WebRTCAudioHandler has been disposed');
    }

    if (_isInitialized) {
      print(
          '⚠️ WebRTCAudioHandler already initialized - skipping initialization');
      return;
    }

    try {
      print('🔧 Creating audio handler components...');
      print('   - Creating RTCVideoRenderer for local stream');
      _localRenderer = RTCVideoRenderer();
      print('   - Creating RTCVideoRenderer for remote stream');
      _remoteRenderer = RTCVideoRenderer();
      print('   - Creating AudioPlayer instance');
      _audioPlayer = AudioPlayer();

      print('⏳ Initializing video renderers...');
      print('   - Initializing local renderer');
      await _localRenderer!.initialize();
      print('   - Local renderer initialized successfully');
      print('   - Initializing remote renderer');
      await _remoteRenderer!.initialize();
      print('   - Remote renderer initialized successfully');

      print('🔊 Configuring audio session for optimal WebRTC performance...');
      await _configureAudioSession();
      print('   - Audio session configuration completed');

      print('📊 Starting audio level monitoring...');
      _startAudioLevelMonitoring();
      print('   - Audio level monitoring started');

      print('🎧 Enumerating available audio devices...');
      await _enumerateAudioDevices();
      print('   - Audio device enumeration completed');

      print('📈 Starting audio quality monitoring...');
      _startAudioQualityMonitoring();
      print('   - Audio quality monitoring started');

      _isInitialized = true;
      print('✅ WebRTCAudioHandler initialized successfully');
      print('   - Final state: initialized=$_isInitialized');
      print(
          '   - Initialization completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      final error = 'Failed to initialize WebRTCAudioHandler: $e';
      print('❌ Initialization error: $error');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      onError?.call(error);
      rethrow;
    }
  }

  /// Get user media with enhanced echo cancellation
  Future<MediaStream> getUserMediaWithEchoCancellation() async {
    print(
        '🎤 Starting user media acquisition with enhanced echo cancellation...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Handler initialized: $_isInitialized');

    if (!_isInitialized) {
      print('❌ Cannot get user media - WebRTCAudioHandler not initialized');
      throw Exception('WebRTCAudioHandler not initialized');
    }

    try {
      print('📋 Audio constraints configuration:');
      print(
          '   - Echo cancellation: ${_enhancedAudioConstraints['audio']['echoCancellation']}');
      print(
          '   - Noise suppression: ${_enhancedAudioConstraints['audio']['noiseSuppression']}');
      print(
          '   - Auto gain control: ${_enhancedAudioConstraints['audio']['autoGainControl']}');
      print(
          '   - Sample rate: ${_enhancedAudioConstraints['audio']['sampleRate']}');
      print(
          '   - Channel count: ${_enhancedAudioConstraints['audio']['channelCount']}');

      print('⏳ Requesting user media from device...');
      _localStream =
          await navigator.mediaDevices.getUserMedia(_enhancedAudioConstraints);

      print('✅ User media obtained successfully');
      print('   - Stream ID: ${_localStream!.id}');
      print('   - Track count: ${_localStream!.getTracks().length}');

      // Log each track in the stream
      for (final track in _localStream!.getTracks()) {
        print(
            '   - Track: ${track.kind} (ID: ${track.id}, Enabled: ${track.enabled})');
      }

      if (_localRenderer != null) {
        print('📺 Setting local renderer source object...');
        _localRenderer!.srcObject = _localStream;
        print('   - Local renderer source object set successfully');
      } else {
        print('⚠️ Local renderer is null - cannot set source object');
      }

      print('✅ User media obtained with enhanced echo cancellation');
      print('   - Operation completed at: ${DateTime.now().toIso8601String()}');
      return _localStream!;
    } catch (e) {
      final error = 'Failed to get user media: $e';
      print('❌ User media acquisition error: $error');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Constraints used: $_enhancedAudioConstraints');
      onError?.call(error);
      rethrow;
    }
  }

  /// Set local audio stream
  Future<void> setLocalStream(MediaStream stream) async {
    print('🎤 Setting local stream (${stream.getTracks().length} tracks)');

    if (!_isInitialized) {
      print('⚠️ Cannot set local stream - handler not initialized');
      return;
    }

    try {
      // Log each track in the stream
      for (final track in stream.getTracks()) {
        print(
            '   - Track: ${track.kind} (ID: ${track.id}, Enabled: ${track.enabled})');
      }

      print('📋 Assigning stream to local handler...');
      _localStream = stream;
      print('   - Stream assigned successfully');

      // CRITICAL: Ensure microphone is not muted by default
      print('🎤 Ensuring local audio tracks are properly enabled...');
      final audioTracks = stream.getAudioTracks();
      for (final track in audioTracks) {
        if (!track.enabled) {
          print('   - Enabling audio track: ${track.id}');
          track.enabled = true;
          print('   - Audio track enabled successfully');
        } else {
          print('   - Audio track already enabled: ${track.id}');
        }
      }

      // Reset mute state to ensure audio is flowing
      if (_isMuted) {
        print(
            '⚠️ Local stream was muted - unmuting for ElevenLabs communication');
        _isMuted = false;
      }

      print('📊 Local stream status:');
      print('   - Muted: $_isMuted');
      print('   - Agent speaking: $_isAgentSpeaking');
      print(
          '   - Audio tracks enabled: ${audioTracks.where((t) => t.enabled).length}/${audioTracks.length}');

      if (_localRenderer != null) {
        print('📺 Setting local renderer source object...');
        _localRenderer!.srcObject = stream;
        print('   - Local renderer source object set successfully');
      } else {
        print('⚠️ Local renderer is null - cannot set source object');
      }

      print('✅ Local stream set successfully');
      print('   - Operation completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to set local stream: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Stream ID: ${stream.id}');
      onError?.call('Failed to set local stream: $e');
    }
  }

  /// STEP 5: Enhanced remote audio stream handling with proper playback
  Future<void> setRemoteStream(MediaStream stream) async {
    print('🎧 Setting remote stream (${stream.getTracks().length} tracks)');

    if (!_isInitialized) {
      print('⚠️ Cannot set remote stream - handler not initialized');
      return;
    }

    try {
      // Log each track in the remote stream
      for (final track in stream.getTracks()) {
        print(
            '   - Remote track: ${track.kind} (ID: ${track.id}, Enabled: ${track.enabled})');
      }

      print('📋 Assigning stream to remote handler...');
      _remoteStream = stream;
      print('   - Stream assigned successfully');

      if (_remoteRenderer != null) {
        print('📺 Setting remote renderer source object...');
        _remoteRenderer!.srcObject = stream;
        print('   - Remote renderer source object set successfully');
      } else {
        print('⚠️ Remote renderer is null - cannot set source object');
      }

      // STEP 5: CRITICAL - Enable all remote audio tracks immediately
      final audioTracks = stream.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = true;
        print('✅ Force enabled remote audio track: ${track.id}');
      }

      // STEP 5: iOS-specific audio session activation for remote playback
      if (Platform.isIOS) {
        try {
          final session = await AudioSession.instance;
          await session.setActive(true);

          // Force audio to speakers if speaker mode is enabled
          if (_isSpeakerOn) {
            await session.configure(session.configuration!.copyWith(
              avAudioSessionCategoryOptions:
                  AVAudioSessionCategoryOptions.defaultToSpeaker |
                      AVAudioSessionCategoryOptions.allowBluetooth,
            ));
          }
          print('✅ iOS audio session activated for remote playback');
        } catch (e) {
          print('⚠️ iOS audio session activation failed: $e');
        }
      }

      // Handle remote audio playback through system audio
      print('🔊 Handling remote audio playback...');
      await _handleRemoteAudioPlayback(stream);
      print('   - Remote audio playback handling completed');

      print('✅ Remote stream set successfully');
      print('   - Operation completed at: ${DateTime.now().toIso8601String()}');

      // Verify the stream is properly set
      if (_remoteStream != null) {
        print('✅ Remote stream verification successful');
        print(
            '   - Final remote stream has ${_remoteStream!.getTracks().length} tracks');
        for (final track in _remoteStream!.getTracks()) {
          print(
              '   - Final track: ${track.kind} (ID: ${track.id}, Enabled: ${track.enabled})');
        }
      } else {
        print('❌ ERROR: Remote stream is null after setting');
      }
    } catch (e) {
      print('❌ Failed to set remote stream: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Stream ID: ${stream.id}');
      onError?.call('Failed to set remote stream: $e');
    }
  }

  /// Handle remote audio playback through system audio
  Future<void> _handleRemoteAudioPlayback(MediaStream stream) async {
    print('🔊 Processing remote audio playback...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Stream ID: ${stream.id}');

    try {
      final audioTracks = stream.getAudioTracks();
      print('📋 Found ${audioTracks.length} audio tracks in remote stream');

      if (audioTracks.isNotEmpty) {
        // Log each audio track
        for (final track in audioTracks) {
          print(
              '   - Audio track: ${track.kind} (ID: ${track.id}, Enabled: ${track.enabled})');

          // Ensure track is enabled
          if (!track.enabled) {
            print('   - Enabling audio track: ${track.id}');
            track.enabled = true;
            print('   - Audio track enabled successfully');
          }
        }

        // Configure audio routing for optimal playback
        print('🎛️ Setting up system audio routing...');
        await _setupSystemAudioRouting();
        print('   - System audio routing configured');

        print('✅ Remote audio configured for playback');

        // Verify tracks are still enabled after configuration
        print('🔍 Verifying audio tracks after configuration...');
        for (final track in audioTracks) {
          print(
              '   - Audio track after configuration: ${track.kind} (ID: ${track.id}, Enabled: ${track.enabled})');
        }

        print('✅ Remote audio playback processing completed');
        print(
            '   - Operation completed at: ${DateTime.now().toIso8601String()}');
      } else {
        print('⚠️ No audio tracks found in remote stream');
        print('   - Stream ID: ${stream.id}');
        print('   - Total tracks: ${stream.getTracks().length}');
        onError?.call('No audio tracks found in remote stream');
      }
    } catch (e) {
      print('❌ Failed to configure remote audio playback: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Stream ID: ${stream.id}');
      onError?.call('Failed to configure remote audio playback: $e');
    }
  }

  /// Configure audio session for optimal WebRTC performance
  Future<void> _configureAudioSession() async {
    print('🔧 Starting audio session configuration for WebRTC...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Platform: ${Platform.operatingSystem}');
    print('   - Handler initialized: $_isInitialized');

    try {
      print('📋 Requesting necessary audio permissions...');
      await _requestAudioPermissions();
      print('   - Audio permissions obtained successfully');

      if (Platform.isAndroid) {
        print('🤖 Configuring Android-specific audio session...');
        await _configureAndroidAudioSession();
        print('   - Android audio session configuration completed');
      } else if (Platform.isIOS) {
        print('🍎 Configuring iOS-specific audio session...');
        await _configureIOSAudioSession();
        print('   - iOS audio session configuration completed');
      } else {
        print('🌐 Using default WebRTC audio for non-mobile platform...');
        print('   - Basic WebRTC functionality available');
      }

      print('✅ Audio session successfully configured for WebRTC');
      print(
          '   - Configuration completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to configure audio session: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Platform: ${Platform.operatingSystem}');
      onError?.call('Failed to configure audio session: $e');
    }
  }

  /// Request audio permissions for mobile platforms
  Future<void> _requestAudioPermissions() async {
    print('🔐 Starting audio permissions request...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Platform: ${Platform.operatingSystem}');

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        print('📱 Requesting microphone permission for mobile platform...');
        var micStatus = await Permission.microphone.request();

        if (micStatus != PermissionStatus.granted) {
          print('❌ Microphone permission denied: $micStatus');
          print('   - Permission status: $micStatus');
          throw Exception('Microphone permission denied');
        }

        print('✅ Microphone permission granted: $micStatus');

        // For Android 11+ and iOS, we may need additional permissions
        if (Platform.isAndroid) {
          print('📱 Requesting additional Android permissions...');
          var bluetoothStatus = await Permission.bluetoothConnect.request();

          if (bluetoothStatus != PermissionStatus.granted) {
            print('⚠️ Bluetooth connect permission denied: $bluetoothStatus');
            print('   - Bluetooth audio may not work');
            print('   - Permission status: $bluetoothStatus');
          } else {
            print('✅ Bluetooth connect permission granted: $bluetoothStatus');
          }
        }

        print('✅ All audio permissions successfully granted');
        print(
            '   - Permission check completed at: ${DateTime.now().toIso8601String()}');
      } else {
        print('⚠️ Skipping audio permission request - not on mobile platform');
      }
    } catch (e) {
      print('❌ Failed to request audio permissions: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Platform: ${Platform.operatingSystem}');
      onError?.call('Failed to request audio permissions: $e');
      rethrow;
    }
  }

  /// STEP 4: Configure audio session for Android using audio_session package
  Future<void> _configureAndroidAudioSession() async {
    print('🤖 Starting Android audio session configuration...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');

    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      print('✅ Android audio session configured successfully');
      print(
          '   - Configuration completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to configure Android audio session: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      rethrow;
    }
  }

  /// STEP 1: Configure audio session for iOS using audio_session package
  Future<void> _configureIOSAudioSession() async {
    print('🍎 Starting iOS audio session configuration...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');

    try {
      // Use audio_session package for proper iOS configuration
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.allowAirPlay |
                AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.videoChat,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      await session.setActive(true);
      print(
          '✅ iOS audio session configured successfully with audio_session package');
      print(
          '   - Configuration completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to configure iOS audio session: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      rethrow;
    }
  }

  /// Set up system audio routing
  Future<void> _setupSystemAudioRouting() async {
    print('🎛️ Starting system audio routing setup...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Platform: ${Platform.operatingSystem}');
    print('   - Speaker enabled: $_isSpeakerOn');

    try {
      if (Platform.isAndroid) {
        print('🤖 Setting up Android audio routing...');
        await _setupAndroidAudioRouting();
        print('   - Android audio routing setup completed');
      } else if (Platform.isIOS) {
        print('🍎 Setting up iOS audio routing...');
        await _setupIOSAudioRouting();
        print('   - iOS audio routing setup completed');
      } else {
        print('🌐 Setting up default audio routing for non-mobile platform...');
        await _configureAudioOutput();
        print('   - Default audio routing setup completed');
      }

      print('✅ System audio routing configured successfully');
      print(
          '   - Configuration completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to setup audio routing: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Platform: ${Platform.operatingSystem}');
      onError?.call('Failed to setup audio routing: $e');
    }
  }

  /// STEP 4: Set up audio routing for Android using audio_session
  Future<void> _setupAndroidAudioRouting() async {
    print('🤖 Starting Android audio routing setup...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Speaker enabled: $_isSpeakerOn');

    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: _isSpeakerOn
              ? AndroidAudioUsage.voiceCommunication
              : AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));

      print('✅ Android audio routing configured successfully');
      print(
          '   - Configuration completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to setup Android audio routing: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Speaker enabled: $_isSpeakerOn');
      rethrow;
    }
  }

  /// STEP 4: Set up audio routing for iOS using audio_session
  Future<void> _setupIOSAudioRouting() async {
    print('🍎 Starting iOS audio routing setup...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Speaker enabled: $_isSpeakerOn');

    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: _isSpeakerOn
            ? AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.allowAirPlay
            : AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.allowAirPlay,
        avAudioSessionMode: AVAudioSessionMode.videoChat,
      ));

      print('✅ iOS audio routing configured successfully');
      print(
          '   - Configuration completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to setup iOS audio routing: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Speaker enabled: $_isSpeakerOn');
      rethrow;
    }
  }

  /// Handle agent mode changes with intelligent gating
  void onAgentModeChange(String mode) async {
    print('🔄 Handling agent mode change...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - New mode: $mode');
    print('   - Current agent speaking state: $_isAgentSpeaking');

    try {
      final wasAgentSpeaking = _isAgentSpeaking;
      _isAgentSpeaking = (mode == 'speaking');

      print('   - Previous agent speaking state: $wasAgentSpeaking');
      print('   - New agent speaking state: $_isAgentSpeaking');

      if (_isAgentSpeaking && !wasAgentSpeaking) {
        print('🎤 Agent started speaking - pausing microphone immediately...');
        // Agent started speaking - pause microphone immediately
        await _pauseMicrophone();
        print('   - Microphone paused successfully');
      } else if (!_isAgentSpeaking && wasAgentSpeaking) {
        print(
            '🎤 Agent stopped speaking - resuming microphone with anti-echo delay...');
        // Agent stopped speaking - resume microphone with anti-echo delay
        await _resumeMicrophone();
        print('   - Microphone resume scheduled with delay');
      } else {
        print('⚠️ No agent speaking state change detected');
      }

      onAgentSpeakingChanged?.call(_isAgentSpeaking);
      print('✅ Agent mode change processed successfully');
      print('   - Final agent speaking state: $_isAgentSpeaking');
      print(
          '   - Processing completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Error handling agent mode change: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Mode: $mode');
      onError?.call('Error handling agent mode change: $e');
    }
  }

  /// Emergency microphone activation for ElevenLabs timeout prevention
  void emergencyActivateMicrophone() {
    print('🚨 EMERGENCY: Activating microphone to prevent ElevenLabs timeout');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Current muted state: $_isMuted');
    print('   - Current agent speaking: $_isAgentSpeaking');

    // Force unmute and ungate microphone
    _isMuted = false;
    _isAgentSpeaking = false;

    // Cancel any pending gating timers
    _micGatingTimer?.cancel();
    _micGatingTimer = null;

    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = true;
        print('   - Force enabled track: ${track.id}');
      }
    }

    print('✅ Emergency microphone activation completed');
  }

  /// Pause microphone during agent speech (echo prevention)
  Future<void> _pauseMicrophone() async {
    print('🎤 Starting microphone pause operation...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Local stream available: ${_localStream != null}');
    print('   - Agent speaking: $_isAgentSpeaking');

    if (_localStream == null) {
      print('⚠️ Cannot pause microphone - local stream is null');
      return;
    }

    try {
      final audioTracks = _localStream!.getAudioTracks();
      print('📋 Found ${audioTracks.length} audio tracks to pause');

      for (final track in audioTracks) {
        print(
            '   - Pausing track: ${track.kind} (ID: ${track.id}, Enabled: ${track.enabled})');
        track.enabled = false;
        print('   - Track disabled successfully');
      }

      // Cancel any pending resume timer
      if (_micGatingTimer != null) {
        print('⏱️ Canceling pending microphone resume timer...');
        _micGatingTimer?.cancel();
        print('   - Resume timer canceled successfully');
      }

      print('✅ Microphone paused successfully - agent speaking');
      print(
          '   - Pause operation completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to pause microphone: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Local stream ID: ${_localStream?.id}');
      onError?.call('Failed to pause microphone: $e');
    }
  }

  /// Resume microphone after agent stops speaking
  Future<void> _resumeMicrophone() async {
    print('🎤 Starting microphone resume operation...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Local stream available: ${_localStream != null}');
    print('   - Agent speaking: $_isAgentSpeaking');
    print('   - Muted state: $_isMuted');
    print('   - Gating delay: $_micGatingDelayMs ms');
    print('   - Timer active: ${_micGatingTimer != null}');

    if (_localStream == null) {
      print('⚠️ Cannot resume microphone - local stream is null');
      print('   - Resume operation aborted');
      return;
    }

    try {
      // Cancel any existing timer
      if (_micGatingTimer != null) {
        print('⏱️ Canceling existing microphone resume timer...');
        _micGatingTimer?.cancel();
        print('   - Existing timer canceled successfully');
      }

      // Add delay to prevent echo tail pickup
      print('⏱️ Scheduling microphone resume with anti-echo delay...');
      print('   - Resume will occur after $_micGatingDelayMs ms');
      print('   - Anti-echo protection enabled');

      _micGatingTimer =
          Timer(Duration(milliseconds: _micGatingDelayMs), () async {
        print('🎤 Executing scheduled microphone resume...');
        print('   - Resume timestamp: ${DateTime.now().toIso8601String()}');
        print('   - Local stream available: ${_localStream != null}');
        print('   - Agent speaking: $_isAgentSpeaking');
        print('   - Muted state: $_isMuted');
        print('   - Gating delay completed');

        if (_localStream != null && !_isMuted && !_isAgentSpeaking) {
          final audioTracks = _localStream!.getAudioTracks();
          print('📋 Found ${audioTracks.length} audio tracks to resume');

          for (final track in audioTracks) {
            print(
                '   - Resuming track: ${track.kind} (ID: ${track.id}, Enabled: ${track.enabled})');
            track.enabled = true;
            print('   - Track enabled successfully');
          }

          print('✅ Microphone resumed successfully - agent finished speaking');
          print(
              '   - Resume operation completed at: ${DateTime.now().toIso8601String()}');
          print('   - All ${audioTracks.length} audio tracks re-enabled');
        } else {
          print('⚠️ Microphone resume skipped - conditions not met');
          print('   - Local stream: ${_localStream != null}');
          print('   - Not muted: ${!_isMuted}');
          print('   - Agent not speaking: ${!_isAgentSpeaking}');
          print('   - All conditions must be true for resume');
        }
      });

      print('✅ Microphone resume scheduled successfully');
      print('   - Will execute after $_micGatingDelayMs ms delay');
      print('   - Timer hash: ${_micGatingTimer.hashCode}');
    } catch (e) {
      print('❌ Failed to resume microphone: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Local stream ID: ${_localStream?.id}');
      print('   - Gating delay: $_micGatingDelayMs ms');
      onError?.call('Failed to resume microphone: $e');
    }
  }

  /// Toggle microphone mute state
  Future<void> toggleMute() async {
    await setMuted(!_isMuted);
  }

  /// Set microphone mute state
  Future<void> setMuted(bool muted) async {
    print('🔇 Setting microphone mute state...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Requested state: ${muted ? 'muted' : 'unmuted'}');
    print('   - Current state: ${_isMuted ? 'muted' : 'unmuted'}');
    print('   - Local stream available: ${_localStream != null}');
    print('   - Agent speaking: $_isAgentSpeaking');

    if (_localStream == null) {
      print('⚠️ Cannot set mute state - local stream is null');
      return;
    }

    try {
      _isMuted = muted;
      print('   - Mute state updated to: ${muted ? 'muted' : 'unmuted'}');

      // Only apply mute if agent is not speaking (gating takes precedence)
      if (!_isAgentSpeaking) {
        print('🎤 Applying mute state to audio tracks...');
        final audioTracks = _localStream!.getAudioTracks();
        print('   - Found ${audioTracks.length} audio tracks');

        for (final track in audioTracks) {
          print(
              '   - Setting track: ${track.kind} (ID: ${track.id}) to ${!muted ? 'enabled' : 'disabled'}');
          track.enabled = !muted;
          print('   - Track state applied successfully');
        }
      } else {
        print(
            '⚠️ Skipping mute state application - agent is currently speaking');
        print('   - Gating takes precedence over mute state');
      }

      print('✅ Microphone ${muted ? 'muted' : 'unmuted'} successfully');
      print('   - Operation completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to set mute state: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Requested state: ${muted ? 'muted' : 'unmuted'}');
      print('   - Local stream ID: ${_localStream?.id}');
      onError?.call('Failed to set mute state: $e');
    }
  }

  /// Toggle speaker output
  Future<void> toggleSpeaker() async {
    await setSpeakerEnabled(!_isSpeakerOn);
  }

  /// Set speaker output state
  Future<void> setSpeakerEnabled(bool enabled) async {
    print('🔊 Setting speaker output state...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Requested state: ${enabled ? 'enabled' : 'disabled'}');
    print('   - Current state: ${_isSpeakerOn ? 'enabled' : 'disabled'}');

    try {
      _isSpeakerOn = enabled;
      print(
          '   - Speaker state updated to: ${enabled ? 'enabled' : 'disabled'}');

      print('🔧 Configuring audio output for new speaker state...');
      await _configureAudioOutput();
      print('   - Audio output configuration completed');

      print('✅ Speaker ${enabled ? 'enabled' : 'disabled'} successfully');
      print('   - Operation completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to toggle speaker: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Requested state: ${enabled ? 'enabled' : 'disabled'}');
      onError?.call('Failed to toggle speaker: $e');
    }
  }

  /// Configure audio output routing (speaker vs earpiece)
  Future<void> _configureAudioOutput() async {
    print('🔊 Starting audio output configuration...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Platform: ${Platform.operatingSystem}');
    print('   - Speaker enabled: $_isSpeakerOn');

    try {
      if (Platform.isAndroid) {
        print('🤖 Configuring Android audio output...');
        await _configureAndroidAudioOutput();
        print('   - Android audio output configuration completed');
      } else if (Platform.isIOS) {
        print('🍎 Configuring iOS audio output...');
        await _configureIOSAudioOutput();
        print('   - iOS audio output configuration completed');
      } else {
        print(
            '🌐 Using default audio configuration for non-mobile platform...');
        print('   - No platform-specific configuration needed');
      }

      print('✅ Audio output configured successfully');
      print('   - Final speaker state: $_isSpeakerOn');
      print(
          '   - Configuration completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to configure audio output: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Platform: ${Platform.operatingSystem}');
      print('   - Speaker enabled: $_isSpeakerOn');
      onError?.call('Failed to configure audio output: $e');
    }
  }

  /// Configure audio output for Android
  Future<void> _configureAndroidAudioOutput() async {
    print('🤖 Starting Android audio output configuration...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Speaker enabled: $_isSpeakerOn');

    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: _isSpeakerOn
              ? AndroidAudioUsage.media
              : AndroidAudioUsage.voiceCommunication,
        ),
      ));

      print('✅ Android audio output configured successfully');
      print(
          '   - Configuration completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to configure Android audio output: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Speaker enabled: $_isSpeakerOn');
      rethrow;
    }
  }

  /// Configure audio output for iOS
  Future<void> _configureIOSAudioOutput() async {
    print('🍎 Starting iOS audio output configuration...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Speaker enabled: $_isSpeakerOn');

    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: _isSpeakerOn
            ? AVAudioSessionCategoryOptions.defaultToSpeaker |
                AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.allowAirPlay
            : AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.allowAirPlay,
        avAudioSessionMode: AVAudioSessionMode.videoChat,
      ));

      print('✅ iOS audio output configured successfully');
      print(
          '   - Configuration completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Failed to configure iOS audio output: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Speaker enabled: $_isSpeakerOn');
      rethrow;
    }
  }

  /// STEP 8: Stream synchronization helper
  Future<void> syncAudioStreams() async {
    print('🔄 Synchronizing audio streams...');

    try {
      // Ensure local stream is active
      if (_localStream != null) {
        for (final track in _localStream!.getAudioTracks()) {
          track.enabled = !_isMuted && !_isAgentSpeaking;
        }
      }

      // Ensure remote stream is active
      if (_remoteStream != null) {
        for (final track in _remoteStream!.getAudioTracks()) {
          track.enabled = true;
        }

        // Set up proper audio session for playback
        if (Platform.isIOS) {
          final session = await AudioSession.instance;
          await session.setActive(true);
        }
      }

      print('✅ Audio streams synchronized successfully');
    } catch (e) {
      print('❌ Failed to sync audio streams: $e');
      onError?.call('Failed to sync audio streams: $e');
    }
  }

  /// STEP 9: Audio recovery mechanism
  Future<void> recoverAudioConnection() async {
    print('🚨 Attempting audio connection recovery...');

    try {
      // Reset audio session
      if (Platform.isIOS) {
        final session = await AudioSession.instance;
        await session.setActive(false);
        await session.setActive(true);
      }

      // Re-sync audio streams
      await syncAudioStreams();

      // Re-enable audio tracks
      emergencyActivateMicrophone();

      print('✅ Audio connection recovery completed');
    } catch (e) {
      print('❌ Audio recovery failed: $e');
    }
  }

  /// STEP 10 & 11: Comprehensive audio debugging
  Future<void> debugAudioState() async {
    print('🔍 === AUDIO DEBUG STATE ===');
    print('Local Stream: ${_localStream?.id ?? 'null'}');
    print('Remote Stream: ${_remoteStream?.id ?? 'null'}');
    print('Muted: $_isMuted');
    print('Speaker On: $_isSpeakerOn');
    print('Agent Speaking: $_isAgentSpeaking');
    print('Initialized: $_isInitialized');
    print('Disposed: $_isDisposed');

    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        print('Local Audio Track: ${track.id} - Enabled: ${track.enabled}');
      }
    }

    if (_remoteStream != null) {
      for (final track in _remoteStream!.getAudioTracks()) {
        print('Remote Audio Track: ${track.id} - Enabled: ${track.enabled}');
      }
    }

    // Check audio session state
    if (Platform.isIOS) {
      try {
        final session = await AudioSession.instance;
        // audio_session does not expose a direct `active` getter across versions;
        // print whether the session has been configured instead of calling a non-existent getter.
        print('iOS Audio Session Configured: ${session.configuration != null}');
        print(
            'iOS Audio Session Category: ${session.configuration?.avAudioSessionCategory}');
      } catch (e) {
        print('iOS Audio Session Error: $e');
      }
    }

    print('🔍 === END DEBUG STATE ===');
  }

  /// Start comprehensive audio level monitoring
  void _startAudioLevelMonitoring() {
    print('📊 Starting audio level monitoring...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Monitoring interval: 100ms');
    print('   - VAD enabled: $_vadEnabled');
    print('   - VAD threshold: $_vadThreshold');

    // Cancel any existing timer
    if (_audioLevelTimer != null) {
      print('⏱️ Canceling existing audio level timer...');
      _audioLevelTimer?.cancel();
      print('   - Existing timer canceled');
    }

    print('⏱️ Creating new periodic audio level timer...');
    _audioLevelTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _updateAudioLevels();

      // Every 30 seconds, log detailed status for ElevenLabs debugging
      if (DateTime.now().millisecondsSinceEpoch % 30000 < 100) {
        _logDetailedAudioStatus();
      }
    });

    print('✅ Audio level monitoring started successfully');
    print('   - Timer ID: ${_audioLevelTimer.hashCode}');
    print('   - Monitoring started at: ${DateTime.now().toIso8601String()}');
  }

  /// Log detailed audio status for ElevenLabs debugging
  void _logDetailedAudioStatus() {
    final localOk = _localStream != null;
    final remoteOk = _remoteStream != null;
    final shouldFlow = localOk && !_isMuted && !_isAgentSpeaking;

    print(
        '🔍 Audio Status: Local=$localOk Remote=$remoteOk Muted=$_isMuted AgentSpeaking=$_isAgentSpeaking ShouldFlow=$shouldFlow');
  }

  /// Update audio input and output levels with VAD
  void _updateAudioLevels() {
    try {
      // Update input and output levels
      _updateInputLevel();
      _updateOutputLevel();

      // Perform voice activity detection
      if (_vadEnabled) {
        _performVoiceActivityDetection();
      }
    } catch (e) {
      print('❌ Error updating audio levels: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - VAD enabled: $_vadEnabled');
      print('   - Input level: $_inputLevel');
      print('   - Output level: $_outputLevel');
    }
  }

  /// Update input audio level for VAD and UI
  void _updateInputLevel() {
    // TODO: Implement real audio level monitoring using WebRTC stats
    // For now, use simulated values for demonstration
    if (_localStream != null && !_isMuted && !_isAgentSpeaking) {
      _inputLevel = 0.1 + (DateTime.now().millisecondsSinceEpoch % 100) / 1000;
    } else {
      _inputLevel = 0.0;
    }

    onInputLevelChanged?.call(_inputLevel);
  }

  /// Update output audio level for monitoring
  void _updateOutputLevel() {
    // TODO: Implement real audio level monitoring using WebRTC stats
    // For now, use simulated values for demonstration
    if (_remoteStream != null && _isAgentSpeaking) {
      _outputLevel = 0.2 + (DateTime.now().millisecondsSinceEpoch % 150) / 1500;
    } else {
      _outputLevel = 0.0;
    }

    onOutputLevelChanged?.call(_outputLevel);
  }

  /// Perform voice activity detection
  void _performVoiceActivityDetection() {
    final previousConsecutiveFrames = _vadConsecutiveFrames;
    final previousActivity = previousConsecutiveFrames >= _vadRequiredFrames;

    if (_inputLevel > _vadThreshold) {
      _vadConsecutiveFrames++;
      if (_vadConsecutiveFrames >= _vadRequiredFrames) {
        if (!previousActivity) {
          print('🎤 Voice activity detected');
          print('   - Input level: $_inputLevel');
          print('   - Threshold: $_vadThreshold');
          print(
              '   - Consecutive frames: $_vadConsecutiveFrames/$_vadRequiredFrames');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
        }
        onVoiceActivityDetected?.call(true);
      }
    } else {
      if (_vadConsecutiveFrames > 0) {
        _vadConsecutiveFrames = 0;
        if (previousActivity) {
          print('🔇 Voice activity ended');
          print('   - Input level: $_inputLevel');
          print('   - Threshold: $_vadThreshold');
          print('   - Consecutive frames reset to 0');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
        }
        onVoiceActivityDetected?.call(false);
      }
    }
  }

  /// Set VAD threshold
  void setVADThreshold(double threshold) {
    print('🔧 Setting VAD threshold...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Requested threshold: $threshold');
    print('   - Current threshold: $_vadThreshold');

    _vadThreshold = threshold.clamp(0.0, 1.0);

    print('✅ VAD threshold set to: $_vadThreshold');
    print('   - Clamped to valid range: 0.0 - 1.0');
    print('   - Update completed at: ${DateTime.now().toIso8601String()}');
  }

  /// Enable/disable voice activity detection
  void setVADEnabled(bool enabled) {
    print('🔧 Setting VAD enabled state...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Requested state: ${enabled ? 'enabled' : 'disabled'}');
    print('   - Current state: ${_vadEnabled ? 'enabled' : 'disabled'}');
    print('   - Current consecutive frames: $_vadConsecutiveFrames');

    _vadEnabled = enabled;
    if (!enabled) {
      _vadConsecutiveFrames = 0;
      print('   - Consecutive frames reset to 0');
    }

    print('✅ VAD ${enabled ? 'enabled' : 'disabled'} successfully');
    print('   - Update completed at: ${DateTime.now().toIso8601String()}');
  }

  /// Set microphone gating delay
  void setMicGatingDelay(int delayMs) {
    print('🔧 Setting microphone gating delay...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Requested delay: $delayMs ms');
    print('   - Current delay: $_micGatingDelayMs ms');

    _micGatingDelayMs = delayMs.clamp(0, 1000);

    print('✅ Mic gating delay set to: $_micGatingDelayMs ms');
    print('   - Clamped to valid range: 0 - 1000 ms');
    print('   - Update completed at: ${DateTime.now().toIso8601String()}');
  }

  /// Get comprehensive audio statistics
  Map<String, dynamic> getAudioStats() {
    return <String, dynamic>{
      'inputLevel': _inputLevel,
      'outputLevel': _outputLevel,
      'isMuted': _isMuted,
      'isSpeakerOn': _isSpeakerOn,
      'isAgentSpeaking': _isAgentSpeaking,
      'vadEnabled': _vadEnabled,
      'vadThreshold': _vadThreshold,
      'micGatingDelayMs': _micGatingDelayMs,
      'hasLocalStream': _localStream != null,
      'hasRemoteStream': _remoteStream != null,
      'isInitialized': _isInitialized,
      'inputVolume': _inputVolume,
      'outputVolume': _outputVolume,
      'currentAudioDevice': _currentAudioDevice,
      'availableDeviceCount': _availableAudioDevices.length,
      'audioQualityScore': _audioQualityScore,
      'audioDropouts': _audioDropouts,
      'totalAudioPackets': _totalAudioPackets,
      'lostAudioPackets': _lostAudioPackets,
      'packetLossPercentage': _totalAudioPackets > 0
          ? (_lostAudioPackets / _totalAudioPackets) * 100
          : 0.0,
      'echoCancellationEnabled': _echoCancellationEnabled,
      'noiseSuppressionEnabled': _noiseSuppressionEnabled,
      'autoGainControlEnabled': _autoGainControlEnabled,
      'noiseSuppressionLevel': _noiseSuppressionLevel,
      'echoCancellationLevel': _echoCancellationLevel,
    };
  }

  /// Set input volume (0.0 to 2.0, where 1.0 is normal)
  Future<void> setInputVolume(double volume) async {
    print('🔉 Setting input volume...');
    print('   - Requested volume: $volume');
    print('   - Current volume: $_inputVolume');

    if (!_isInitialized) {
      throw Exception('WebRTCAudioHandler not initialized');
    }

    try {
      final clampedVolume = volume.clamp(0.0, 2.0);
      _inputVolume = clampedVolume;

      onInputVolumeChanged?.call(_inputVolume);
      print('✅ Input volume set to: $_inputVolume');
    } catch (e) {
      print('❌ Failed to set input volume: $e');
      onError?.call('Failed to set input volume: $e');
      rethrow;
    }
  }

  /// Set output volume (0.0 to 2.0, where 1.0 is normal)
  Future<void> setOutputVolume(double volume) async {
    print('🔊 Setting output volume...');
    print('   - Requested volume: $volume');
    print('   - Current volume: $_outputVolume');

    if (!_isInitialized) {
      throw Exception('WebRTCAudioHandler not initialized');
    }

    try {
      final clampedVolume = volume.clamp(0.0, 2.0);
      _outputVolume = clampedVolume;

      onOutputVolumeChanged?.call(_outputVolume);
      print('✅ Output volume set to: $_outputVolume');
    } catch (e) {
      print('❌ Failed to set output volume: $e');
      onError?.call('Failed to set output volume: $e');
      rethrow;
    }
  }

  /// Enumerate available audio devices
  Future<void> _enumerateAudioDevices() async {
    print('🎧 Enumerating audio devices...');
    print('   - Platform: ${Platform.operatingSystem}');

    try {
      try {
        // Try to enumerate devices (works on web and some mobile platforms)
        final devices = await navigator.mediaDevices.enumerateDevices();
        _availableAudioDevices.clear();
        for (final device in devices) {
          if (device.kind == 'audioinput' || device.kind == 'audiooutput') {
            _availableAudioDevices.add({
              'deviceId': device.deviceId,
              'label': device.label.isEmpty ? 'Unknown Device' : device.label,
              'kind': device.kind,
              'groupId':
                  (device.groupId?.isNotEmpty ?? false) ? device.groupId : '',
            });
          }
        }
      } catch (enumerationError) {
        print('⚠️ Device enumeration not supported: $enumerationError');
        _setDefaultAudioDevices();
      }

      onAudioDevicesUpdated?.call(_availableAudioDevices);
      print(
          '✅ Audio devices enumerated: ${_availableAudioDevices.length} devices');
    } catch (e) {
      print('❌ Error enumerating audio devices: $e');
      _setDefaultAudioDevices();
      onError?.call('Failed to enumerate audio devices: $e');
    }
  }

  /// Set default audio devices when enumeration is not supported
  void _setDefaultAudioDevices() {
    _availableAudioDevices = [
      {
        'deviceId': 'default',
        'label': 'Default Audio Input',
        'kind': 'audioinput',
        'groupId': 'default',
      },
      {
        'deviceId': 'default',
        'label': 'Default Audio Output',
        'kind': 'audiooutput',
        'groupId': 'default',
      },
    ];
  }

  /// Start audio quality monitoring
  void _startAudioQualityMonitoring() {
    print('📈 Starting audio quality monitoring...');

    _qualityMonitorTimer?.cancel();
    _qualityMonitorTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _updateAudioQualityMetrics();
    });

    print('✅ Audio quality monitoring started');
  }

  /// Update audio quality metrics
  void _updateAudioQualityMetrics() async {
    try {
      if (_localStream == null && _remoteStream == null) {
        return;
      }

      // Calculate quality score based on various factors
      double qualityScore = 0.8;

      if (_inputLevel > 0 || _outputLevel > 0) {
        qualityScore += 0.2;
      }

      // Simulate packet statistics
      _totalAudioPackets += 10;
      if (DateTime.now().millisecond % 100 < 2) {
        _lostAudioPackets += 1;
        _audioDropouts += 1;
      }

      // Apply processing effects to quality
      if (_echoCancellationEnabled) qualityScore += 0.05;
      if (_noiseSuppressionEnabled) qualityScore += 0.05;
      if (_autoGainControlEnabled) qualityScore += 0.02;

      _audioQualityScore = qualityScore.clamp(0.0, 1.0);

      onAudioQualityChanged?.call(_audioQualityScore);
      onAudioStatsUpdated?.call(getAudioStats());
    } catch (e) {
      print('❌ Error updating audio quality metrics: $e');
    }
  }

  /// Configure audio processing effects
  Future<void> configureAudioProcessing({
    bool? echoCancellation,
    bool? noiseSuppression,
    bool? autoGainControl,
    double? noiseSuppressionLevel,
    double? echoCancellationLevel,
  }) async {
    print('🎛️ Configuring audio processing effects...');

    if (!_isInitialized) {
      throw Exception('WebRTCAudioHandler not initialized');
    }

    try {
      if (echoCancellation != null) _echoCancellationEnabled = echoCancellation;
      if (noiseSuppression != null) _noiseSuppressionEnabled = noiseSuppression;
      if (autoGainControl != null) _autoGainControlEnabled = autoGainControl;
      if (noiseSuppressionLevel != null)
        _noiseSuppressionLevel = noiseSuppressionLevel.clamp(0.0, 1.0);
      if (echoCancellationLevel != null)
        _echoCancellationLevel = echoCancellationLevel.clamp(0.0, 1.0);

      print('✅ Audio processing effects configured');
    } catch (e) {
      print('❌ Failed to configure audio processing: $e');
      onError?.call('Failed to configure audio processing: $e');
      rethrow;
    }
  }

  /// Stop audio level monitoring
  void _stopAudioLevelMonitoring() {
    print('🛑 Stopping audio level monitoring...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Timer exists: ${_audioLevelTimer != null}');

    if (_audioLevelTimer != null) {
      print('⏱️ Canceling audio level timer...');
      _audioLevelTimer?.cancel();
      _audioLevelTimer = null;
      print('   - Timer canceled and set to null');
    } else {
      print('⚠️ No active timer to cancel');
    }

    print('✅ Audio level monitoring stopped successfully');
    print('   - Operation completed at: ${DateTime.now().toIso8601String()}');
  }

  /// Stop audio quality monitoring
  void _stopAudioQualityMonitoring() {
    print('🛑 Stopping audio quality monitoring...');

    if (_qualityMonitorTimer != null) {
      _qualityMonitorTimer?.cancel();
      _qualityMonitorTimer = null;
    }

    print('✅ Audio quality monitoring stopped');
  }

  /// Clean up all resources
  Future<void> dispose() async {
    print('🧹 Starting WebRTCAudioHandler disposal...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Already disposed: $_isDisposed');
    print('   - Initialized: $_isInitialized');
    print('   - Local stream exists: ${_localStream != null}');
    print('   - Remote stream exists: ${_remoteStream != null}');

    if (_isDisposed) {
      print('⚠️ WebRTCAudioHandler already disposed - skipping disposal');
      return;
    }

    _isDisposed = true;
    print('   - Marked as disposed');

    try {
      // Stop monitoring
      print('🛑 Stopping audio level monitoring...');
      _stopAudioLevelMonitoring();
      print('   - Audio level monitoring stopped');

      print('🛑 Stopping audio quality monitoring...');
      _stopAudioQualityMonitoring();
      print('   - Audio quality monitoring stopped');

      // Cancel timers
      print('⏱️ Canceling mic gating timer...');
      _micGatingTimer?.cancel();
      _micGatingTimer = null;
      print('   - Mic gating timer canceled');

      // Dispose components
      print('🗑️ Disposing audio components...');
      print('   - Disposing audio player...');
      await _audioPlayer?.dispose();
      print('   - Audio player disposed');

      print('   - Disposing local renderer...');
      _localRenderer?.dispose();
      print('   - Local renderer disposed');

      print('   - Disposing remote renderer...');
      _remoteRenderer?.dispose();
      print('   - Remote renderer disposed');

      // Clear streams (managed by connection manager)
      print('🧼 Clearing stream references...');
      _localStream = null;
      _remoteStream = null;
      print('   - Stream references cleared');

      // Clear callbacks
      print('🔌 Clearing callbacks...');
      onInputLevelChanged = null;
      onOutputLevelChanged = null;
      onVoiceActivityDetected = null;
      onAgentSpeakingChanged = null;
      onError = null;
      onInputVolumeChanged = null;
      onOutputVolumeChanged = null;
      onAudioDeviceChanged = null;
      onAudioDevicesUpdated = null;
      onAudioQualityChanged = null;
      onAudioStatsUpdated = null;
      print('   - All callbacks cleared');

      // Reset state
      print('🔄 Resetting state variables...');
      _isInitialized = false;
      _isMuted = false;
      _isSpeakerOn = true;
      _isAgentSpeaking = false;
      _inputLevel = 0.0;
      _outputLevel = 0.0;
      _vadConsecutiveFrames = 0;
      _inputVolume = 1.0;
      _outputVolume = 1.0;
      _currentAudioDevice = 'default';
      _availableAudioDevices.clear();
      _audioQualityScore = 0.0;
      _audioDropouts = 0;
      _totalAudioPackets = 0;
      _lostAudioPackets = 0;
      print('   - All state variables reset');

      print('✅ WebRTCAudioHandler disposed successfully');
      print('   - Disposal completed at: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('❌ Error disposing WebRTCAudioHandler: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
    }
  }
}
