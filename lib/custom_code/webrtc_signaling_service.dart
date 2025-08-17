import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'webrtc_connection_manager.dart';
import 'webrtc_audio_handler.dart';

class WebRTCSignalingService {
  WebSocketChannel? _channel;
  final WebRTCConnectionManager _connectionManager;
  final WebRTCAudioHandler _audioHandler;
  Function(String)? onError;
  bool _webrtcInitialized = false; // Prevent duplicate initialization

  WebRTCSignalingService(this._connectionManager, this._audioHandler);

  Future<void> connect(String signedUrl, String token) async {
    try {
      print('🌐 Starting WebSocket connection process...');
      print('📋 Connection parameters:');
      print('   - Signed URL: $signedUrl');
      print('   - Token: ${token.substring(0, 10)}...');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');

      // Use the signed URL directly without transformation
      // The BuildShip endpoint already provides the correct WebSocket URL
      final websocketUrl = signedUrl;

      print('🔍 Validating WebSocket URL...');
      // Validate URL before attempting connection
      if (!websocketUrl.startsWith('wss://') &&
          !websocketUrl.startsWith('ws://')) {
        print('❌ Invalid WebSocket URL: $websocketUrl');
        throw Exception('Invalid WebSocket URL: $websocketUrl');
      }
      print('✅ WebSocket URL validation passed');

      // Add token to URL as query parameter if not already present
      print('🔧 Preparing connection URI with authentication token...');
      final uri = Uri.parse(websocketUrl);
      final updatedUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'token': token,
      });
      print('📝 Final connection URI: $updatedUri');

      print('🔌 Attempting to establish WebSocket connection...');
      _channel = WebSocketChannel.connect(updatedUri);

      print('📡 Setting up WebSocket stream listeners...');
      _channel!.stream.listen(
        (message) {
          try {
            final decodedMessage = jsonDecode(message);
            _handleSignalingMessage(decodedMessage);
          } catch (e) {
            print('❌ Error parsing WebSocket message: $e');
            onError?.call('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          onError?.call('WebSocket connection error: $error');
        },
        onDone: () {
          print('🔚 WebSocket closed');
          if (_channel != null) {
            onError?.call('WebSocket connection closed unexpectedly');
          }
        },
      );

      print('✅ WebSocket connected to ElevenLabs');

      // CRITICAL: Send ElevenLabs initialization immediately after connection
      print('📧 Sending conversation initialization...');
      try {
        _sendElevenLabsInitializationMessage();
        print('✅ Conversation initialization sent');
        print('⏳ Waiting for conversation metadata to start WebRTC...');
      } catch (initError) {
        print('❌ Failed to send ElevenLabs initialization: $initError');
        onError
            ?.call('Failed to initialize ElevenLabs conversation: $initError');
      }
    } on SocketException catch (e) {
      print('❌ Network connection error (SocketException):');
      print('   - Error details: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      print('🔍 Diagnosed as: Network connectivity issue');

      onError?.call(
          'Network connection error: Please check your internet connection and try again.');
      rethrow;
    } on WebSocketChannelException catch (e) {
      print('❌ WebSocket connection error (WebSocketChannelException):');
      print('   - Error details: $e');
      print('   - Error message: ${e.message}');
      print('   - Error type: ${e.runtimeType}');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      print('🔍 Diagnosed as: WebSocket protocol error');

      onError?.call('WebSocket connection failed: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Failed to connect to WebSocket (Unknown error):');
      print('   - Error details: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      print('🔍 Diagnosed as: General connection failure');

      onError?.call('Failed to connect to WebSocket: ${e.toString()}');
      rethrow;
    }
  }

  void _handleSignalingMessage(Map<String, dynamic> message) async {
    print('📨 Received: ${message['type']}');

    // Validate message structure
    if (message['type'] == null) {
      print('❌ Invalid signaling message: missing type field');
      print('🔍 Raw message: $message');
      return;
    }

    try {
      switch (message['type']) {
        // WebRTC signaling messages
        case 'offer':
          print('📞 Processing WebRTC offer...');
          if (message['sdp'] == null) {
            print('❌ Invalid offer message: missing SDP');
            break;
          }
          await _handleOffer(message['sdp']);
          break;
        case 'answer':
          print('📞 Processing WebRTC answer...');
          if (message['sdp'] == null) {
            print('❌ Invalid answer message: missing SDP');
            break;
          }
          await _handleAnswer(message['sdp']);
          break;
        case 'ice-candidate':
          print('🧊 Processing ICE candidate...');
          if (message['candidate'] == null) {
            print('❌ Invalid ICE candidate message: missing candidate data');
            break;
          }
          await _handleIceCandidate(message['candidate']);
          break;
        case 'connection-type':
          print('🔗 Connection type message received:');
          print('   - Connection type: ${message['connectionType']}');
          if (message['connectionType'] == 'webrtc') {
            print('✅ WebRTC connection type confirmed');
            print(
                '⏳ WebRTC will initialize after conversation metadata is received');
          } else {
            print(
                '⚠️ Unsupported connection type: ${message['connectionType']}');
          }
          break;

        // ElevenLabs Conversational AI specific messages
        case 'conversation_initiation_metadata':
          _handleConversationMetadata(message);
          break;
        case 'audio':
          await _handleAudioMessage(message);
          break;
        case 'user_transcript':
          _handleUserTranscript(message);
          break;
        case 'agent_response':
          _handleAgentResponse(message);
          break;
        case 'conversation_interruption_notification':
          _handleInterruption(message);
          break;
        case 'internal_vad_notification':
          _handleVadNotification(message);
          break;

        default:
          print('⚠️ Unknown message type: ${message['type']}');
          print('🔍 Full message content: $message');
      }
    } catch (e) {
      print('❌ Error processing signaling message:');
      print('   - Error details: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Message type: ${message['type']}');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      onError?.call('Error processing signaling message: $e');
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> sdp) async {
    try {
      print('📞 Processing WebRTC offer...');
      print('📋 Offer SDP type: ${sdp['type']}');

      final offer = RTCSessionDescription(sdp['sdp'], sdp['type']);
      print('📞 Setting remote description for offer...');
      await _connectionManager.setRemoteDescription(offer);
      print('✅ Remote description set for offer');

      print('📞 Creating answer...');
      final answer = await _connectionManager.createAnswer();
      print('✅ Answer created successfully');

      print('📤 Sending answer to remote peer...');
      _sendMessage({
        'type': 'answer',
        'sdp': {'sdp': answer.sdp, 'type': answer.type}
      });
      print('✅ Answer sent successfully');
    } catch (e) {
      print('❌ Error handling offer: $e');
      onError?.call('Failed to handle WebRTC offer: $e');
      rethrow;
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> sdp) async {
    try {
      print('📞 Processing WebRTC answer...');
      print('📋 Answer SDP type: ${sdp['type']}');

      final answer = RTCSessionDescription(sdp['sdp'], sdp['type']);
      print('📞 Setting remote description for answer...');
      await _connectionManager.setRemoteDescription(answer);
      print('✅ Remote description set for answer');
    } catch (e) {
      print('❌ Error handling answer: $e');
      onError?.call('Failed to handle WebRTC answer: $e');
      rethrow;
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> candidateData) async {
    try {
      print('🧊 Processing ICE candidate...');
      print('📋 Candidate SDP Mid: ${candidateData['sdpMid']}');

      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );
      print('🧊 Adding ICE candidate to peer connection...');
      await _connectionManager.addIceCandidate(candidate);
      print('✅ ICE candidate added successfully');
    } catch (e) {
      print('❌ Error handling ICE candidate: $e');
      onError?.call('Failed to handle ICE candidate: $e');
      rethrow;
    }
  }

  void _sendMessage(Map<String, dynamic> message) {
    try {
      final messageJson = jsonEncode(message);
      print('📤 Sending signaling message: ${message['type']}');
      print('📋 Message content: $messageJson');

      _channel?.sink.add(messageJson);
      print('✅ Signaling message sent successfully');
    } catch (e) {
      print('❌ Failed to send message: $e');
      onError?.call('Failed to send message: $e');
    }
  }

  Future<void> _initializeWebRTCConnection() async {
    if (_webrtcInitialized) {
      print('⚠️ WebRTC already initialized, skipping duplicate initialization');
      return;
    }

    _webrtcInitialized = true;
    final startTime = DateTime.now();
    try {
      print('🚀 Starting WebRTC connection initialization...');

      // Create peer connection
      print('🔗 Creating WebRTC peer connection...');
      print('   - Step 2/6: Peer connection creation');
      try {
        await _connectionManager.initializePeerConnection();
        print('✅ WebRTC peer connection created successfully');
        print(
            '   - Peer connection ID: ${_connectionManager.peerConnection.hashCode}');
      } catch (pcError) {
        print('❌ Failed to create peer connection: $pcError');
        throw Exception('Peer connection creation failed: $pcError');
      }

      // Get user media
      print('🎤 Getting user media...');
      print('   - Step 3/6: User media acquisition');
      MediaStream? localStream;
      try {
        localStream = await _connectionManager.getUserMedia();
        print('✅ User media obtained successfully');
        print('   - Stream ID: ${localStream.id}');
        print('   - Track count: ${localStream.getTracks().length}');

        // Log track details
        for (int i = 0; i < localStream.getTracks().length; i++) {
          final track = localStream.getTracks()[i];
          print(
              '   - Track $i: ${track.kind} (ID: ${track.id}, Enabled: ${track.enabled})');
        }
      } catch (mediaError) {
        print('❌ Failed to get user media: $mediaError');
        throw Exception('User media acquisition failed: $mediaError');
      }

      // Verify tracks were added to peer connection in getUserMedia
      print('📡 Verifying tracks in peer connection...');
      print('   - Step 4/6: Track verification');
      try {
        final senders = await _connectionManager.peerConnection!.getSenders();
        print('📡 Peer connection has ${senders.length} senders');

        for (int i = 0; i < senders.length; i++) {
          final sender = senders[i];
          print(
              '   - Sender $i: ${sender.track?.kind} (ID: ${sender.track?.id}, Enabled: ${sender.track?.enabled})');
        }

        if (senders.isEmpty) {
          print(
              '⚠️ No senders found in peer connection - tracks may not have been added properly');
        } else {
          print('✅ Tracks verified in peer connection');
        }
      } catch (verifyError) {
        print('❌ Error verifying tracks: $verifyError');
        throw Exception('Track verification failed: $verifyError');
      }

      // Create initial offer
      print('📞 Creating WebRTC offer...');
      print('   - Step 5/6: Offer creation');
      RTCSessionDescription? offer;
      try {
        offer = await _connectionManager.createOffer();
        print('✅ WebRTC offer created successfully');
        print('   - Offer type: ${offer.type}');
        print('   - SDP length: ${offer.sdp?.length ?? 0} characters');
      } catch (offerError) {
        print('❌ Failed to create offer: $offerError');
        throw Exception('Offer creation failed: $offerError');
      }

      // Send offer to remote peer
      print('📤 Sending offer to remote peer...');
      print('   - Step 6/6: Offer transmission');
      try {
        final offerMessage = {
          'type': 'offer',
          'sdp': {'sdp': offer.sdp ?? '', 'type': offer.type ?? ''}
        };
        _sendMessage(offerMessage);
        print('✅ Offer sent successfully');
        print('   - Message type: ${offerMessage['type']}');
        print('   - SDP type: ${offer.type}');
      } catch (sendError) {
        print('❌ Failed to send offer: $sendError');
        throw Exception('Offer transmission failed: $sendError');
      }

      final endTime = DateTime.now();
      print('🎉 WebRTC connection initialization completed successfully');
      print(
          '   - Total time: ${endTime.difference(startTime).inMilliseconds}ms');
    } catch (e) {
      print('❌ Error during WebRTC initialization:');
      print('   - Error details: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      onError?.call('WebRTC initialization failed: $e');
      rethrow;
    }
  }

  /// Send ElevenLabs conversation initialization message
  /// This MUST be sent first according to ElevenLabs API documentation
  void _sendElevenLabsInitializationMessage() {
    print('📧 Preparing ElevenLabs conversation initialization message...');

    // Create the exact initialization message format required by ElevenLabs
    // Based on: https://elevenlabs.io/docs/conversational-ai/api-reference/conversational-ai/websocket
    final initializationMessage = {
      'type': 'conversation_initiation_client_data',
      'conversation_config_override': {
        'agent': {
          'prompt': {
            'prompt':
                'You are a helpful AI assistant. Respond naturally and conversationally.'
          },
          'first_message': 'Hello! How can I help you today?',
          'language': 'en'
        },
        'tts': {
          'voice_id': 'pNInz6obpgDQGcFmaJgB' // Default ElevenLabs voice (Adam)
        }
      }
    };

    print('📋 ElevenLabs initialization message structure:');
    print('   - Type: ${initializationMessage['type']}');
    print(
        '   - Has conversation_config_override: ${initializationMessage['conversation_config_override'] != null}');

    final configOverride = initializationMessage['conversation_config_override']
        as Map<String, dynamic>?;
    final agent = configOverride?['agent'] as Map<String, dynamic>?;
    final prompt = agent?['prompt'] as Map<String, dynamic>?;
    final tts = configOverride?['tts'] as Map<String, dynamic>?;

    print('   - Agent prompt configured: ${prompt?['prompt'] != null}');
    print('   - First message configured: ${agent?['first_message'] != null}');
    print('   - Language configured: ${agent?['language'] != null}');
    print('   - Voice ID configured: ${tts?['voice_id'] != null}');

    try {
      final messageJson = jsonEncode(initializationMessage);
      print('🔍 Message size: ${messageJson.length} characters');
      print('📤 Sending ElevenLabs initialization message...');

      _channel?.sink.add(messageJson);
      print('✅ ElevenLabs initialization message sent successfully');
      print(
          '⚠️ CRITICAL: This message format must match ElevenLabs API specification exactly');
    } catch (e) {
      print('❌ Error sending ElevenLabs initialization message: $e');
      throw Exception('Failed to send ElevenLabs initialization: $e');
    }
  }

  /// Handle ElevenLabs conversation metadata response
  void _handleConversationMetadata(Map<String, dynamic> message) {
    try {
      print('📋 Processing conversation metadata:');
      print('   - Conversation ID: ${message['conversation_id']}');
      print('   - Agent ID: ${message['agent_id']}');
      print('   - User ID: ${message['user_id']}');

      // Store conversation metadata for later use
      // This confirms the conversation was successfully initialized
      print('✅ Conversation successfully initialized with ElevenLabs');

      // CRITICAL: Start WebRTC initialization now that conversation is established
      if (!_webrtcInitialized) {
        print('🚀 Starting WebRTC initialization after conversation setup...');
        _initializeWebRTCConnection().catchError((error) {
          print('❌ WebRTC initialization failed: $error');
          onError?.call('WebRTC initialization failed: $error');
        });
      } else {
        print(
            '✅ WebRTC already initialized, skipping duplicate initialization');
      }
    } catch (e) {
      print('❌ Error processing conversation metadata: $e');
      onError?.call('Failed to process conversation metadata: $e');
    }
  }

  /// Handle ElevenLabs audio data messages
  Future<void> _handleAudioMessage(Map<String, dynamic> message) async {
    try {
      print('🎵 Processing audio message:');
      final audioEvent = message['audio_event'];
      if (audioEvent != null && audioEvent['audio_base_64'] != null) {
        final base64String = audioEvent['audio_base_64'];
        print(
            '   - Audio data size: ${base64String.length} bytes (base64)');
        print('   - Event type: ${audioEvent['event_type']}');

        // Play the audio using the audio handler
        await _audioHandler.playBase64Audio(base64String);

        print('✅ Audio message processed and played successfully');
      } else {
        print('⚠️ No audio data found in the message');
      }
    } catch (e) {
      print('❌ Error processing audio message: $e');
      onError?.call('Failed to process audio message: $e');
    }
  }

  /// Handle user transcript messages
  void _handleUserTranscript(Map<String, dynamic> message) {
    try {
      print('📝 Processing user transcript:');
      print(
          '   - Transcript: ${message['user_transcription_event']?['user_transcript']}');
      print(
          '   - Duration: ${message['user_transcription_event']?['duration_ms']}ms');

      // This is the transcription of what the user said
      // Can be used to update the UI with user's spoken words
      print('✅ User transcript processed successfully');
    } catch (e) {
      print('❌ Error processing user transcript: $e');
      onError?.call('Failed to process user transcript: $e');
    }
  }

  /// Handle agent response messages
  void _handleAgentResponse(Map<String, dynamic> message) {
    try {
      print('🤖 Processing agent response:');
      print(
          '   - Response: ${message['agent_response_event']?['agent_response']}');
      print(
          '   - Event type: ${message['agent_response_event']?['event_type']}');

      // This is the text response from the AI agent
      // Can be used to update conversation UI
      print('✅ Agent response processed successfully');
    } catch (e) {
      print('❌ Error processing agent response: $e');
      onError?.call('Failed to process agent response: $e');
    }
  }

  /// Handle conversation interruption notifications
  void _handleInterruption(Map<String, dynamic> message) {
    try {
      print('🛑 Processing interruption notification:');
      print('   - Interruption type: ${message['interruption_type']}');
      print('   - Timestamp: ${message['timestamp']}');

      // Handle conversation interruption (user speaking while agent is talking)
      print('✅ Interruption notification processed successfully');
    } catch (e) {
      print('❌ Error processing interruption: $e');
      onError?.call('Failed to process interruption: $e');
    }
  }

  /// Handle voice activity detection notifications
  void _handleVadNotification(Map<String, dynamic> message) {
    try {
      print('🎙️ Processing VAD notification:');
      print(
          '   - Activity detected: ${message['vad_event']?['is_speech_detected']}');
      print('   - Probability: ${message['vad_event']?['probability']}');

      // Voice Activity Detection helps determine when user is speaking
      print('✅ VAD notification processed successfully');
    } catch (e) {
      print('❌ Error processing VAD notification: $e');
      onError?.call('Failed to process VAD notification: $e');
    }
  }

  /// Dispose resources and close connection
  void dispose() {
    try {
      print('🧹 Disposing WebRTC signaling service...');
      _channel?.sink.close();
      _channel = null;
      _webrtcInitialized = false; // Reset flag for future use
      print('✅ WebRTC signaling service disposed successfully');
    } catch (e) {
      print('❌ Error disposing signaling service: $e');
    }
  }
}
