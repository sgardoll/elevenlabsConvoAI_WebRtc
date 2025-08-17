import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../app_state.dart';

/// Comprehensive ElevenLabs Authentication Service
///
/// Handles secure authentication, token management, and automatic refresh
/// for ElevenLabs Conversational AI API integration.
///
/// Features:
/// - Secure credential storage using Flutter Secure Storage
/// - Automatic token refresh and signed URL management
/// - Expiration tracking and proactive renewal
/// - Network-aware authentication with retry logic
/// - Comprehensive error handling and logging
class ElevenLabsAuthService {
  static final ElevenLabsAuthService _instance =
      ElevenLabsAuthService._internal();
  factory ElevenLabsAuthService() => _instance;
  ElevenLabsAuthService._internal();

  static ElevenLabsAuthService get instance => _instance;

  // Storage keys for secure credential management
  static const String _keyApiKey = 'elevenlabs_api_key';
  static const String _keySignedUrl = 'elevenlabs_signed_url';
  static const String _keyToken = 'elevenlabs_token';
  static const String _keyExpirationTime = 'elevenlabs_expiration_time';
  static const String _keyLastRefresh = 'elevenlabs_last_refresh';
  static const String _keyAgentId = 'elevenlabs_agent_id';
  static const String _keyEndpoint = 'elevenlabs_endpoint';

  // Service configuration
  static const Duration _tokenRefreshBuffer =
      Duration(minutes: 5); // Refresh 5 minutes before expiration
  static const Duration _defaultTokenDuration =
      Duration(hours: 1); // Default token lifetime
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Cache for frequently accessed values
  String? _cachedApiKey;
  String? _cachedSignedUrl;
  String? _cachedToken;
  DateTime? _cachedExpirationTime;
  String? _cachedAgentId;
  String? _cachedEndpoint;

  // State tracking
  bool _isInitialized = false;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  /// Initialize the authentication service with secure credential loading
  Future<void> initialize() async {
    if (_isInitialized) {
      print('🔐 ElevenLabs Auth Service already initialized');
      return;
    }

    try {
      print('🚀 Initializing ElevenLabs Authentication Service...');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');

      // Load cached credentials from secure storage
      print('📋 Loading cached credentials from secure storage...');
      await _loadCachedCredentials();

      // Check if credentials need refresh
      await _checkAndRefreshIfNeeded();

      // Set up automatic refresh timer
      _setupRefreshTimer();

      _isInitialized = true;
      print('✅ ElevenLabs Auth Service initialized successfully');
      print('   - Has API key: ${_cachedApiKey?.isNotEmpty ?? false}');
      print('   - Has signed URL: ${_cachedSignedUrl?.isNotEmpty ?? false}');
      print('   - Has token: ${_cachedToken?.isNotEmpty ?? false}');
      print(
          '   - Token expires: ${_cachedExpirationTime?.toIso8601String() ?? 'Unknown'}');
    } catch (e) {
      print('❌ Error initializing ElevenLabs Auth Service: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      rethrow;
    }
  }

  Future<void> fetchAndStoreCredentials(String agentId, String endpoint) async {
    try {
      await setAgentConfiguration(agentId, endpoint);
      final credentials = await _requestCredentialsWithRetry(endpoint, agentId);
      await _storeCredentials(credentials);
      _updateAppState(credentials);
    } catch (e) {
      print('❌ Error fetching and storing credentials: $e');
      rethrow;
    }
  }

  /// Store API key securely
  Future<void> setApiKey(String apiKey) async {
    print('🔐 Storing ElevenLabs API key securely...');

    if (apiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    try {
      await _secureStorage.write(key: _keyApiKey, value: apiKey);
      _cachedApiKey = apiKey;

      print('✅ API key stored successfully');
      print('   - Key length: ${apiKey.length} characters');
      print('   - Cached: true');
    } catch (e) {
      print('❌ Error storing API key: $e');
      rethrow;
    }
  }

  /// Get API key from secure storage
  Future<String?> getApiKey() async {
    if (_cachedApiKey != null) {
      return _cachedApiKey;
    }

    try {
      _cachedApiKey = await _secureStorage.read(key: _keyApiKey);
      return _cachedApiKey;
    } catch (e) {
      print('❌ Error retrieving API key: $e');
      return null;
    }
  }

  /// Configure agent and endpoint for authentication
  Future<void> setAgentConfiguration(String agentId, String endpoint) async {
    print('⚙️ Configuring ElevenLabs agent and endpoint...');
    print('   - Agent ID: $agentId');
    print('   - Endpoint: $endpoint');

    if (agentId.isEmpty || endpoint.isEmpty) {
      throw ArgumentError('Agent ID and endpoint cannot be empty');
    }

    try {
      await Future.wait([
        _secureStorage.write(key: _keyAgentId, value: agentId),
        _secureStorage.write(key: _keyEndpoint, value: endpoint),
      ]);

      _cachedAgentId = agentId;
      _cachedEndpoint = endpoint;

      // Update app state for consistency
      FFAppState().update(() {
        FFAppState().elevenLabsAgentId = agentId;
        FFAppState().endpoint = endpoint;
      });

      print('✅ Agent configuration stored successfully');
    } catch (e) {
      print('❌ Error storing agent configuration: $e');
      rethrow;
    }
  }

  /// Get valid authentication credentials with automatic refresh
  Future<AuthCredentials> getValidCredentials() async {
    print('🔐 Getting valid ElevenLabs credentials...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');

    if (!_isInitialized) {
      await initialize();
    }

    // Check if refresh is needed
    if (_isCredentialRefreshNeeded()) {
      print('🔄 Credentials need refresh, initiating refresh...');
      await refreshCredentials();
    }

    // Validate we have all required credentials
    final agentId =
        _cachedAgentId ?? await _secureStorage.read(key: _keyAgentId);
    final endpoint =
        _cachedEndpoint ?? await _secureStorage.read(key: _keyEndpoint);
    final signedUrl =
        _cachedSignedUrl ?? await _secureStorage.read(key: _keySignedUrl);
    final token = _cachedToken ?? await _secureStorage.read(key: _keyToken);

    if (agentId == null || agentId.isEmpty) {
      throw StateError(
          'Agent ID not configured. Call setAgentConfiguration() first.');
    }

    if (endpoint == null || endpoint.isEmpty) {
      throw StateError(
          'Endpoint not configured. Call setAgentConfiguration() first.');
    }

    if (signedUrl == null ||
        signedUrl.isEmpty ||
        token == null ||
        token.isEmpty) {
      print('⚠️ Missing signed URL or token, requesting new credentials...');
      await refreshCredentials();

      // Re-fetch after refresh
      final refreshedUrl =
          _cachedSignedUrl ?? await _secureStorage.read(key: _keySignedUrl);
      final refreshedToken =
          _cachedToken ?? await _secureStorage.read(key: _keyToken);

      if (refreshedUrl == null || refreshedToken == null) {
        throw StateError('Failed to obtain valid credentials after refresh');
      }

      return AuthCredentials(
        agentId: agentId,
        endpoint: endpoint,
        signedUrl: refreshedUrl,
        token: refreshedToken,
        expiresAt: _cachedExpirationTime,
      );
    }

    print('✅ Valid credentials retrieved');
    print('   - Agent ID: $agentId');
    print('   - Has signed URL: true');
    print('   - Has token: true');
    print(
        '   - Expires: ${_cachedExpirationTime?.toIso8601String() ?? 'Unknown'}');

    return AuthCredentials(
      agentId: agentId,
      endpoint: endpoint,
      signedUrl: signedUrl,
      token: token,
      expiresAt: _cachedExpirationTime,
    );
  }

  /// Set credentials directly from FlutterFlow action result
  Future<void> setCredentialsFromFlutterFlow(
      Map<String, String> credentials) async {
    print('🔄 Setting credentials from FlutterFlow action...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Has signedUrl: ${credentials.containsKey('signedUrl')}');
    print('   - Has token: ${credentials.containsKey('token')}');

    if (!credentials.containsKey('signedUrl') ||
        !credentials.containsKey('token')) {
      throw ArgumentError('Credentials must contain both signedUrl and token');
    }

    try {
      // Convert to the expected format
      final credentialData = {
        'signedUrl': credentials['signedUrl']!,
        'token': credentials['token']!,
      };

      // Store new credentials securely
      await _storeCredentials(credentialData);

      // Update app state
      _updateAppState(credentialData);

      print('✅ Credentials set from FlutterFlow successfully');
      print('   - SignedUrl: ${credentials['signedUrl']}');
      print('   - Token length: ${credentials['token']?.length} characters');
      print('   - New expiration: ${_cachedExpirationTime?.toIso8601String()}');
    } catch (e) {
      print('❌ Error setting credentials from FlutterFlow: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      rethrow;
    }
  }

  /// Refresh authentication credentials
  Future<void> refreshCredentials() async {
    if (_isRefreshing) {
      print('🔄 Credential refresh already in progress, waiting...');
      // Wait for current refresh to complete
      while (_isRefreshing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isRefreshing = true;
    print('🔄 Starting credential refresh...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');

    try {
      final agentId =
          _cachedAgentId ?? await _secureStorage.read(key: _keyAgentId);
      final endpoint =
          _cachedEndpoint ?? await _secureStorage.read(key: _keyEndpoint);

      if (agentId == null || endpoint == null) {
        throw StateError(
            'Agent configuration missing. Cannot refresh credentials.');
      }

      // Request new credentials with retry logic
      final credentials = await _requestCredentialsWithRetry(endpoint, agentId);

      // Store new credentials securely
      await _storeCredentials(credentials);

      // Update app state
      _updateAppState(credentials);

      print('✅ Credentials refreshed successfully');
      print('   - New expiration: ${_cachedExpirationTime?.toIso8601String()}');
    } catch (e) {
      print('❌ Error refreshing credentials: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Request credentials from server with retry logic
  Future<Map<String, dynamic>> _requestCredentialsWithRetry(
      String endpoint, String agentId) async {
    int attemptCount = 0;

    while (attemptCount < _maxRetryAttempts) {
      try {
        attemptCount++;
        print(
            '📡 Requesting credentials (attempt $attemptCount/$_maxRetryAttempts)...');
        print('   - Endpoint: $endpoint');
        print('   - Agent ID: $agentId');

        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'ElevenLabs-Flutter-Client/1.0',
              },
              body: jsonEncode({
                'agentId': agentId,
                'connectionType': 'webrtc',
                'clientType': 'flutter',
                'requestedAt': DateTime.now().toIso8601String(),
              }),
            )
            .timeout(const Duration(seconds: 15));

        print('📡 Response received: ${response.statusCode}');

        if (response.statusCode == 200) {
          print('📥 Raw response body: ${response.body}');
          print('📥 Response body length: ${response.body.length} characters');
          print(
              '📥 Response content type: ${response.headers['content-type']}');

          Map<String, dynamic> data;
          try {
            data = jsonDecode(response.body) as Map<String, dynamic>;
            print('✅ JSON parsing successful');
          } catch (parseError) {
            print('❌ JSON parsing failed: $parseError');
            print('   - Raw body: ${response.body}');
            print('   - Body type: ${response.body.runtimeType}');
            throw FormatException(
                'Failed to parse JSON response: $parseError. Body: ${response.body}');
          }

          print('📋 Parsed response data:');
          print('   - Keys available: ${data.keys.toList()}');
          print('   - signedUrl present: ${data.containsKey('signedUrl')}');
          print('   - token present: ${data.containsKey('token')}');

          if (data.containsKey('signedUrl')) {
            print('   - signedUrl value: ${data['signedUrl']}');
          }
          if (data.containsKey('token')) {
            print(
                '   - token value: ${data['token']?.toString().substring(0, 50)}...');
          }

          // Validate response structure
          if (data['signedUrl'] == null || data['token'] == null) {
            print('❌ Response validation failed:');
            print('   - signedUrl is null: ${data['signedUrl'] == null}');
            print('   - token is null: ${data['token'] == null}');
            print('   - Full response: $data');
            throw FormatException(
                'Invalid response format: missing signedUrl or token. Response: $data');
          }

          print('✅ Credentials received and validated successfully');
          print('   - SignedUrl: ${data['signedUrl']}');
          print(
              '   - Token length: ${data['token'].toString().length} characters');
          return data;
        } else {
          final errorMessage =
              'Server returned ${response.statusCode}: ${response.body}';

          print('❌ HTTP Error Response:');
          print('   - Status Code: ${response.statusCode}');
          print('   - Response Headers: ${response.headers}');
          print('   - Response Body: ${response.body}');
          print('   - Content-Type: ${response.headers['content-type']}');

          if (attemptCount >= _maxRetryAttempts) {
            throw HttpException(errorMessage);
          }

          print(
              '⚠️ Request failed, retrying in ${_retryDelay.inSeconds} seconds...');
          print('   - Error: $errorMessage');
          await Future.delayed(_retryDelay);
        }
      } on TimeoutException {
        if (attemptCount >= _maxRetryAttempts) {
          throw TimeoutException(
              'Request timeout after $_maxRetryAttempts attempts');
        }
        print('⏰ Request timeout, retrying...');
        await Future.delayed(_retryDelay);
      } on SocketException {
        if (attemptCount >= _maxRetryAttempts) {
          throw SocketException(
              'Network error after $_maxRetryAttempts attempts');
        }
        print('🌐 Network error, retrying...');
        await Future.delayed(_retryDelay);
      } catch (e) {
        if (attemptCount >= _maxRetryAttempts) {
          rethrow;
        }
        print('❌ Request error, retrying: $e');
        await Future.delayed(_retryDelay);
      }
    }

    throw Exception(
        'Failed to obtain credentials after $_maxRetryAttempts attempts');
  }

  /// Store credentials securely
  Future<void> _storeCredentials(Map<String, dynamic> data) async {
    print('💾 Storing credentials securely...');

    final signedUrl = data['signedUrl'] as String;
    final token = data['token'] as String;
    final now = DateTime.now();
    final expirationTime = now.add(_defaultTokenDuration);

    try {
      await Future.wait([
        _secureStorage.write(key: _keySignedUrl, value: signedUrl),
        _secureStorage.write(key: _keyToken, value: token),
        _secureStorage.write(
            key: _keyExpirationTime, value: expirationTime.toIso8601String()),
        _secureStorage.write(
            key: _keyLastRefresh, value: now.toIso8601String()),
      ]);

      // Update cache
      _cachedSignedUrl = signedUrl;
      _cachedToken = token;
      _cachedExpirationTime = expirationTime;

      print('✅ Credentials stored successfully');
      print('   - Signed URL length: ${signedUrl.length} characters');
      print('   - Token length: ${token.length} characters');
      print('   - Expires at: ${expirationTime.toIso8601String()}');
    } catch (e) {
      print('❌ Error storing credentials: $e');
      rethrow;
    }
  }

  /// Update app state with new credentials
  void _updateAppState(Map<String, dynamic> credentials) {
    try {
      FFAppState().update(() {
        FFAppState().cachedSignedUrl = credentials['signedUrl'] as String;
        FFAppState().isSignedUrlExpired = false;
        FFAppState().signedUrlExpirationTime = _cachedExpirationTime;
      });
      print('✅ App state updated with new credentials');
    } catch (e) {
      print('⚠️ Error updating app state: $e');
      // Don't throw - this is not critical for authentication
    }
  }

  /// Load cached credentials from secure storage
  Future<void> _loadCachedCredentials() async {
    try {
      final futures = await Future.wait([
        _secureStorage.read(key: _keyApiKey),
        _secureStorage.read(key: _keySignedUrl),
        _secureStorage.read(key: _keyToken),
        _secureStorage.read(key: _keyExpirationTime),
        _secureStorage.read(key: _keyAgentId),
        _secureStorage.read(key: _keyEndpoint),
      ]);

      _cachedApiKey = futures[0];
      _cachedSignedUrl = futures[1];
      _cachedToken = futures[2];

      final expirationString = futures[3];
      if (expirationString != null) {
        _cachedExpirationTime = DateTime.parse(expirationString);
      }

      _cachedAgentId = futures[4];
      _cachedEndpoint = futures[5];

      print('📋 Cached credentials loaded');
      print('   - Has API key: ${_cachedApiKey != null}');
      print('   - Has signed URL: ${_cachedSignedUrl != null}');
      print('   - Has token: ${_cachedToken != null}');
      print(
          '   - Expiration: ${_cachedExpirationTime?.toIso8601String() ?? 'Not set'}');
    } catch (e) {
      print('⚠️ Error loading cached credentials: $e');
      // Continue with empty cache
    }
  }

  /// Check if credentials need refresh
  bool _isCredentialRefreshNeeded() {
    if (_cachedExpirationTime == null) {
      print('🔍 Refresh needed: No expiration time set');
      return true;
    }

    final now = DateTime.now();
    final refreshTime = _cachedExpirationTime!.subtract(_tokenRefreshBuffer);

    if (now.isAfter(refreshTime)) {
      print('🔍 Refresh needed: Token expires soon');
      print('   - Current time: ${now.toIso8601String()}');
      print('   - Refresh time: ${refreshTime.toIso8601String()}');
      print(
          '   - Expiration time: ${_cachedExpirationTime!.toIso8601String()}');
      return true;
    }

    return false;
  }

  /// Check and refresh credentials if needed
  Future<void> _checkAndRefreshIfNeeded() async {
    if (_isCredentialRefreshNeeded()) {
      print('🔄 Automatic credential refresh triggered');
      await refreshCredentials();
    }
  }

  /// Set up automatic refresh timer
  void _setupRefreshTimer() {
    _refreshTimer?.cancel();

    if (_cachedExpirationTime != null) {
      final now = DateTime.now();
      final refreshTime = _cachedExpirationTime!.subtract(_tokenRefreshBuffer);

      if (refreshTime.isAfter(now)) {
        final delay = refreshTime.difference(now);
        print('⏰ Setting up refresh timer for ${delay.inMinutes} minutes');

        _refreshTimer = Timer(delay, () {
          print('⏰ Automatic refresh timer triggered');
          refreshCredentials().catchError((e) {
            print('❌ Automatic refresh failed: $e');
          });
        });
      } else {
        print('⏰ Refresh time already passed, scheduling immediate refresh');
        Timer.run(() => refreshCredentials());
      }
    }
  }

  /// Clear all stored credentials and cache
  Future<void> clearCredentials() async {
    print('🧹 Clearing all ElevenLabs credentials...');

    try {
      _refreshTimer?.cancel();
      _refreshTimer = null;

      await Future.wait([
        _secureStorage.delete(key: _keyApiKey),
        _secureStorage.delete(key: _keySignedUrl),
        _secureStorage.delete(key: _keyToken),
        _secureStorage.delete(key: _keyExpirationTime),
        _secureStorage.delete(key: _keyLastRefresh),
        _secureStorage.delete(key: _keyAgentId),
        _secureStorage.delete(key: _keyEndpoint),
      ]);

      // Clear cache
      _cachedApiKey = null;
      _cachedSignedUrl = null;
      _cachedToken = null;
      _cachedExpirationTime = null;
      _cachedAgentId = null;
      _cachedEndpoint = null;

      // Update app state
      FFAppState().update(() {
        FFAppState().cachedSignedUrl = '';
        FFAppState().isSignedUrlExpired = true;
        FFAppState().signedUrlExpirationTime = null;
      });

      _isInitialized = false;
      print('✅ All credentials cleared successfully');
    } catch (e) {
      print('❌ Error clearing credentials: $e');
      rethrow;
    }
  }

  /// Check if service has valid credentials
  bool get hasValidCredentials {
    if (!_isInitialized) return false;
    if (_cachedSignedUrl == null || _cachedToken == null) return false;
    if (_cachedExpirationTime == null) return false;

    final now = DateTime.now();
    return now.isBefore(_cachedExpirationTime!);
  }

  /// Get credential expiration status
  Duration? get timeUntilExpiration {
    if (_cachedExpirationTime == null) return null;

    final now = DateTime.now();
    if (now.isAfter(_cachedExpirationTime!)) return Duration.zero;

    return _cachedExpirationTime!.difference(now);
  }

  /// Dispose service and clean up resources
  void dispose() {
    print('🧹 Disposing ElevenLabs Auth Service...');
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _isInitialized = false;
    print('✅ ElevenLabs Auth Service disposed');
  }
}

/// Authentication credentials container
class AuthCredentials {
  final String agentId;
  final String endpoint;
  final String signedUrl;
  final String token;
  final DateTime? expiresAt;

  const AuthCredentials({
    required this.agentId,
    required this.endpoint,
    required this.signedUrl,
    required this.token,
    this.expiresAt,
  });

  @override
  String toString() {
    return 'AuthCredentials(agentId: $agentId, hasSignedUrl: ${signedUrl.isNotEmpty}, hasToken: ${token.isNotEmpty}, expiresAt: $expiresAt)';
  }
}
