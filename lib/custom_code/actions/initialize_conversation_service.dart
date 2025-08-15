// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../conversational_ai_service.dart';

/// Initialize the Conversational AI Service with WebRTC Support
/// Uses stored credentials from getElevenLabsCredentials action
Future<String> initializeConversationService(
  BuildContext context,
  String agentId,
) async {
  try {
    debugPrint('🚀 Initializing Conversational AI Service with WebRTC');
    debugPrint('📍 Agent ID: $agentId');
    debugPrint('🔐 Using stored credentials from authentication service');

    final service = ConversationalAIService.instance;

    // Uses WebRTC with WebSocket signaling - no endpoint needed, uses stored credentials
    final result = await service.initializeWithStoredCredentials(
      context,
      agentId,
    );

    debugPrint('✅ Service initialization result: $result');

    // Update FlutterFlow App State based on connection type
    final connectionType = service.isUsingWebRTC ? 'webrtc' : 'websocket';
    FFAppState().update(() {
      FFAppState().connectionType = connectionType;
      FFAppState().wsConnectionState = service.connectionState;
      FFAppState().isRecording = service.connectionState.contains('connected');
    });

    return result;
  } catch (e) {
    debugPrint('❌ Error initializing conversation service: $e');

    // Update App State to reflect error
    FFAppState().update(() {
      FFAppState().wsConnectionState = 'error';
      FFAppState().isRecording = false;
      FFAppState().connectionType = 'websocket'; // Fallback indicator
    });

    return 'error: ${e.toString()}';
  }
}
