// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/api_requests/api_calls.dart';
import '../elevenlabs_auth_service.dart';

/// Enhanced action to get ElevenLabs credentials and store them in the auth service
Future<String> getCredentials(
  String agentId,
  String endpoint,
) async {
  try {
    debugPrint('🔐 Getting ElevenLabs credentials...');
    debugPrint('   - Agent ID: $agentId');
    debugPrint('   - Endpoint: $endpoint');

    // Configure the auth service (but don't initialize - we'll handle credentials manually)
    final authService = ElevenLabsAuthService.instance;
    debugPrint('⚙️ Configuring ElevenLabs agent and endpoint...');
    await authService.setAgentConfiguration(agentId, endpoint);

    debugPrint(
        '🔄 Skipping auth service initialization - getting fresh credentials manually...');

    // Call the BuildShip endpoint to get credentials
    debugPrint('📡 Calling BuildShip endpoint...');
    final response = await GetSignedURLViaBuildShipCallCall.call(
      agentId: agentId,
      endpoint: endpoint,
    );

    debugPrint('📋 Response analysis:');
    debugPrint('   - Success: ${response.succeeded}');
    debugPrint('   - Status Code: ${response.statusCode}');
    debugPrint('   - Has JSON Body: ${response.jsonBody != null}');

    if (response.jsonBody != null) {
      debugPrint('📥 Raw response body: ${response.jsonBody}');
      debugPrint('   - Keys: ${response.jsonBody!.keys.toList()}');
      debugPrint(
          '   - signedUrl present: ${response.jsonBody!.containsKey('signedUrl')}');
      debugPrint(
          '   - token present: ${response.jsonBody!.containsKey('token')}');
    }

    if (response.succeeded && response.jsonBody != null) {
      final signedUrl = response.jsonBody!['signedUrl']?.toString();
      final token = response.jsonBody!['token']?.toString();

      debugPrint('🔍 Extracted values:');
      debugPrint('   - signedUrl length: ${signedUrl?.length ?? 0}');
      debugPrint('   - token length: ${token?.length ?? 0}');
      debugPrint(
          '   - signedUrl starts with wss: ${signedUrl?.startsWith('wss://') ?? false}');

      if (signedUrl != null &&
          signedUrl.isNotEmpty &&
          token != null &&
          token.isNotEmpty) {
        // Store credentials in the auth service
        debugPrint('💾 Storing credentials in auth service...');
        await authService.setCredentialsFromFlutterFlow({
          'signedUrl': signedUrl,
          'token': token,
        });

        debugPrint('✅ Credentials successfully stored in auth service');
        return 'Credentials obtained and stored successfully';
      } else {
        debugPrint('❌ Invalid credentials received:');
        debugPrint(
            '   - signedUrl valid: ${signedUrl != null && signedUrl.isNotEmpty}');
        debugPrint('   - token valid: ${token != null && token.isNotEmpty}');
        return 'Error: Invalid credentials received from server';
      }
    } else {
      debugPrint('❌ API call failed:');
      debugPrint('   - Success: ${response.succeeded}');
      debugPrint('   - Status: ${response.statusCode}');
      debugPrint('   - Body: ${response.jsonBody}');
      return 'Error: Failed to get credentials (${response.statusCode})';
    }
  } catch (e) {
    debugPrint('❌ Exception in getElevenLabsCredentials: $e');
    debugPrint('   - Error type: ${e.runtimeType}');
    debugPrint('   - Stack trace: ${StackTrace.current}');
    return 'Error: Exception occurred - $e';
  }
}
