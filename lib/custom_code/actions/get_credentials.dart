// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../elevenlabs_auth_service.dart';

Future<String> getCredentials(String agentId, String endpoint) async {
  try {
    debugPrint('🔐 Getting ElevenLabs credentials via AuthService...');
    final authService = ElevenLabsAuthService.instance;
    await authService.fetchAndStoreCredentials(agentId, endpoint);
    return 'Credentials obtained and stored successfully';
  } catch (e) {
    debugPrint('❌ Exception in getCredentials: $e');
    return 'Error: Exception occurred - $e';
  }
}
