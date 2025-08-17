// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../conversational_ai_service.dart';
import 'dart:async';

class SimpleRecordingButton extends StatefulWidget {
  const SimpleRecordingButton({
    Key? key,
    this.width,
    this.height,
    this.size = 60.0,
    this.iconSize = 24.0,
    this.elevation = 8.0,
    this.recordingColor,
    this.idleColor,
    this.iconColor,
    this.pulseAnimation = true,
  }) : super(key: key);

  final double? width;
  final double? height;
  final double size;
  final double iconSize;
  final double elevation;
  final Color? recordingColor;
  final Color? idleColor;
  final Color? iconColor;
  final bool pulseAnimation;

  @override
  _SimpleRecordingButtonState createState() => _SimpleRecordingButtonState();
}

class _SimpleRecordingButtonState extends State<SimpleRecordingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final ConversationalAIService _service = ConversationalAIService();
  StreamSubscription<bool>? _recordingSubscription;
  StreamSubscription<ConversationState>? _stateSubscription;

  bool _isRecording = false;
  ConversationState _currentState = ConversationState.idle;

  @override
  void initState() {
    super.initState();
    print('🚀 SimpleRecordingButton initializing...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Widget configuration:');
    print('     - Size: ${widget.size}');
    print('     - Icon size: ${widget.iconSize}');
    print('     - Pulse animation: ${widget.pulseAnimation}');
    print('     - Elevation: ${widget.elevation}');

    // Setup pulse animation
    print('🎬 Setting up pulse animation...');
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.stop();
    print('✅ Animation controller configured and stopped');

    // Check service instance before setting up listeners
    print('🔍 Checking ConversationalAIService instance...');
    try {
      print('   - Service type: ${_service.runtimeType}');
      print('   - Service hashCode: ${_service.hashCode}');
      print('   - Service connection state: ${_service.connectionState}');
      print('   - Service WebRTC usage: ${_service.isUsingWebRTC}');

      // Defer listener setup to ensure service is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print(
              '📡 Post-frame callback executing, setting up service listeners...');
          _setupServiceListeners();
        } else {
          print('⚠️ Widget not mounted during post-frame callback');
        }
      });
    } catch (e) {
      print('❌ Error checking service during initialization: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Will attempt to setup listeners anyway...');
      _setupServiceListeners();
    }

    print('✅ SimpleRecordingButton initialization completed');
  }

  void _setupServiceListeners() {
    print('🔌 Setting up ConversationalAIService listeners...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Widget mounted: $mounted');
    print('   - Service instance: ${_service.runtimeType}');
    print('   - Pulse animation enabled: ${widget.pulseAnimation}');

    try {
      // Verify service availability before setting up listeners
      print('🔍 Checking service readiness...');
      print('   - Service connection state: ${_service.connectionState}');
      print('   - Service is using WebRTC: ${_service.isUsingWebRTC}');

      // Listen to recording state with enhanced error handling
      print('📻 Setting up recording stream listener...');
      _recordingSubscription = _service.recordingStream.listen(
        (isRecording) {
          final timestamp = DateTime.now().toIso8601String();
          print('🔄 [RECORDING] State update received at $timestamp');
          print('   - Previous recording state: $_isRecording');
          print('   - New recording state: $isRecording');
          print('   - Widget mounted: $mounted');
          print(
              '   - State transition: ${_isRecording ? 'recording' : 'idle'} → ${isRecording ? 'recording' : 'idle'}');

          if (mounted) {
            setState(() {
              _isRecording = isRecording;
            });
            print('✅ Recording state updated in UI: $_isRecording');

            // Control animation based on recording state with proper checks
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final shouldStartAnimation =
                    isRecording && widget.pulseAnimation;
                final isCurrentlyAnimating = _animationController.isAnimating;

                print('🎬 Animation control check:');
                print('   - Should start animation: $shouldStartAnimation');
                print('   - Currently animating: $isCurrentlyAnimating');
                print(
                    '   - Animation controller status: ${_animationController.status}');

                if (shouldStartAnimation && !isCurrentlyAnimating) {
                  print('🎬 Starting recording animation');
                  _animationController.repeat(reverse: true);
                } else if (!shouldStartAnimation && isCurrentlyAnimating) {
                  print('🛑 Stopping recording animation');
                  _animationController.stop();
                  _animationController.reset();
                }
              } else {
                print('⚠️ Widget not mounted, skipping animation update');
              }
            });
          } else {
            print('⚠️ Widget not mounted, skipping recording state update');
          }
        },
        onError: (error) {
          print('❌ Error in recording stream: $error');
          print('   - Error type: ${error.runtimeType}');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
          if (mounted) {
            _showSnackBar('Recording stream error: $error');
          }
        },
        onDone: () {
          print('🔚 Recording stream closed');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
        },
      );
      print('✅ Recording stream listener set up successfully');

      // Listen to overall conversation state with enhanced error handling
      print('📻 Setting up conversation state stream listener...');
      _stateSubscription = _service.stateStream.listen(
        (state) {
          final timestamp = DateTime.now().toIso8601String();
          print('🔄 [CONVERSATION] State update received at $timestamp');
          print('   - Previous conversation state: $_currentState');
          print('   - New conversation state: $state');
          print('   - Widget mounted: $mounted');
          print('   - State transition: $_currentState → $state');

          if (mounted) {
            setState(() {
              _currentState = state;
            });
            print('✅ Conversation state updated in UI: $_currentState');

            // Ensure animation state is consistent with conversation state
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final shouldBeAnimating =
                    state == ConversationState.recording &&
                        widget.pulseAnimation;
                final isAnimating = _animationController.isAnimating;

                print('🎭 Animation sync check:');
                print('   - Should be animating: $shouldBeAnimating');
                print('   - Currently animating: $isAnimating');
                print('   - Conversation state: $state');
                print('   - Recording state: $_isRecording');

                if (shouldBeAnimating && !isAnimating) {
                  print('🎬 Starting animation based on conversation state');
                  _animationController.repeat(reverse: true);
                } else if (!shouldBeAnimating && isAnimating) {
                  print('🛑 Stopping animation based on conversation state');
                  _animationController.stop();
                  _animationController.reset();
                }
              } else {
                print('⚠️ Widget not mounted, skipping animation sync');
              }
            });
          } else {
            print('⚠️ Widget not mounted, skipping conversation state update');
          }
        },
        onError: (error) {
          print('❌ Error in conversation state stream: $error');
          print('   - Error type: ${error.runtimeType}');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
          if (mounted) {
            _showSnackBar('State stream error: $error');
          }
        },
        onDone: () {
          print('🔚 Conversation state stream closed');
          print('   - Timestamp: ${DateTime.now().toIso8601String()}');
        },
      );
      print('✅ Conversation state stream listener set up successfully');

      print('🎉 All service listeners configured successfully');
      print(
          '   - Recording subscription active: ${_recordingSubscription != null}');
      print('   - State subscription active: ${_stateSubscription != null}');
    } catch (e) {
      print('❌ Error setting up service listeners: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Timestamp: ${DateTime.now().toIso8601String()}');
      if (mounted) {
        _showSnackBar('Failed to setup service listeners: $e');
      }
    }
  }

  /// Debug method to verify service stream connectivity
  void debugServiceStreams() {
    print('🔧 [DEBUG] Manual service stream verification');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Widget mounted: $mounted');
    print('   - Service instance: ${_service.hashCode}');

    try {
      print('📊 Service status check:');
      print('   - Connection state: ${_service.connectionState}');
      print('   - Using WebRTC: ${_service.isUsingWebRTC}');
      print('   - Current recording state: $_isRecording');
      print('   - Current conversation state: $_currentState');

      print('📡 Stream subscription status:');
      print(
          '   - Recording subscription active: ${_recordingSubscription != null}');
      print('   - State subscription active: ${_stateSubscription != null}');

      if (_recordingSubscription != null) {
        print(
            '   - Recording subscription hashCode: ${_recordingSubscription.hashCode}');
        print(
            '   - Recording subscription isPaused: ${_recordingSubscription!.isPaused}');
      }

      if (_stateSubscription != null) {
        print(
            '   - State subscription hashCode: ${_stateSubscription.hashCode}');
        print(
            '   - State subscription isPaused: ${_stateSubscription!.isPaused}');
      }

      print('🎬 Animation status:');
      print('   - Controller status: ${_animationController.status}');
      print('   - Is animating: ${_animationController.isAnimating}');
      print('   - Animation value: ${_animationController.value}');
    } catch (e) {
      print('❌ Error during service stream debug: $e');
    }
  }

  @override
  void dispose() {
    print('🧹 SimpleRecordingButton disposing...');
    print('   - Timestamp: ${DateTime.now().toIso8601String()}');
    print('   - Current recording state: $_isRecording');
    print('   - Current conversation state: $_currentState');
    print('   - Animation controller status: ${_animationController.status}');
    print(
        '   - Animation controller animating: ${_animationController.isAnimating}');

    // Cancel stream subscriptions
    print('📡 Canceling stream subscriptions...');
    if (_recordingSubscription != null) {
      _recordingSubscription!.cancel();
      print('   - Recording subscription canceled');
    } else {
      print('   - No recording subscription to cancel');
    }

    if (_stateSubscription != null) {
      _stateSubscription!.cancel();
      print('   - State subscription canceled');
    } else {
      print('   - No state subscription to cancel');
    }

    // Ensure animation controller is properly stopped before disposal
    print('🎬 Disposing animation controller...');
    if (_animationController.isAnimating) {
      print('   - Stopping active animation...');
      _animationController.stop();
    }
    _animationController.dispose();
    print('   - Animation controller disposed');

    print('✅ SimpleRecordingButton disposal completed');
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (!mounted) {
      print('⚠️ Button tap ignored - widget not mounted');
      return;
    }

    final tapTimestamp = DateTime.now().toIso8601String();
    print('👆 Button tap detected at $tapTimestamp');
    print('   - Current conversation state: $_currentState');
    print('   - Current recording state: $_isRecording');
    print('   - Widget mounted: $mounted');
    print('   - Animation controller status: ${_animationController.status}');

    try {
      // Check service availability first
      print('🔍 Checking service availability before processing tap...');
      print('   - Service connection state: ${_service.connectionState}');
      print('   - Service WebRTC status: ${_service.isUsingWebRTC}');

      // Allow interruption if agent is speaking - tap to interrupt
      if (_currentState == ConversationState.playing) {
        print('🔊 User tapped to interrupt agent speaking');
        print('   - Triggering interruption...');
        final result = await _service.triggerInterruption();
        print('📋 Interruption result: $result');

        if (mounted) {
          if (result.startsWith('Error')) {
            print('❌ Interruption failed: $result');
            _showSnackBar('Failed to interrupt agent: $result');
          } else {
            print('✅ Interruption successful');
            _showSnackBar('Agent interrupted');
          }
        }
        return;
      }

      // Prevent interaction if not connected
      if (_currentState == ConversationState.idle ||
          _currentState == ConversationState.error) {
        print('⚠️ Preventing interaction - service not connected');
        print('   - Current state: $_currentState');
        _showSnackBar('Not connected to conversation service');
        return;
      }

      // Check if service is in a connecting state
      if (_currentState == ConversationState.connecting) {
        print('⚠️ Service is connecting - please wait');
        _showSnackBar('Connecting to service, please wait...');
        return;
      }

      // Toggle recording using the consolidated service
      print('🔄 Toggling recording state...');
      print('   - Previous recording state: $_isRecording');
      print('   - Service method: toggleRecording()');

      final result = await _service.toggleRecording();
      print('📋 Toggle recording result: $result');
      print('   - Result timestamp: ${DateTime.now().toIso8601String()}');

      if (mounted) {
        if (result.startsWith('Error')) {
          print('❌ Recording toggle failed: $result');
          _showSnackBar('Recording error: $result');
        } else {
          print('✅ Recording toggle successful: $result');
          _showSnackBar(result);
        }
      } else {
        print('⚠️ Widget unmounted after toggle recording, skipping UI update');
      }
    } catch (e) {
      print('❌ Error in button tap handler: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Error timestamp: ${DateTime.now().toIso8601String()}');
      print('   - Current state: $_currentState');
      print('   - Recording state: $_isRecording');

      if (mounted) {
        _showSnackBar('Error: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: FlutterFlowTheme.of(context).primaryText,
          ),
        ),
        duration: Duration(milliseconds: 2000),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  }

  Color _getButtonColor() {
    switch (_currentState) {
      case ConversationState.recording:
        return widget.recordingColor ?? FlutterFlowTheme.of(context).error;
      case ConversationState.playing:
        return FlutterFlowTheme.of(context)
            .secondary; // Changed to secondary for better tap-to-interrupt visibility
      case ConversationState.connected:
        return widget.idleColor ?? FlutterFlowTheme.of(context).primary;
      case ConversationState.connecting:
        return FlutterFlowTheme.of(context).alternate;
      case ConversationState.error:
        return FlutterFlowTheme.of(context).error;
      default:
        return FlutterFlowTheme.of(context).secondaryText;
    }
  }

  IconData _getButtonIcon() {
    switch (_currentState) {
      case ConversationState.recording:
        return Icons.stop;
      case ConversationState.playing:
        return Icons
            .pause; // Changed from volume_up to pause to indicate tap-to-interrupt
      case ConversationState.connecting:
        return Icons.sync;
      case ConversationState.error:
        return Icons.error;
      default:
        return Icons.mic;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if animation should be active based on both recording state and conversation state
    final shouldAnimate =
        (_isRecording || _currentState == ConversationState.recording) &&
            widget.pulseAnimation;

    // Ensure animation state is consistent with current state
    if (mounted) {
      if (shouldAnimate && !_animationController.isAnimating) {
        print('🎬 Starting animation in build method');
        _animationController.repeat(reverse: true);
      } else if (!shouldAnimate && _animationController.isAnimating) {
        print('🛑 Stopping animation in build method');
        _animationController.stop();
        _animationController.reset();
      }
    }

    final buttonContent = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _getButtonColor(),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: widget.elevation,
            offset: Offset(0, widget.elevation / 2),
          ),
        ],
      ),
      child: Icon(
        _getButtonIcon(),
        color: widget.iconColor ??
            FlutterFlowTheme.of(context).secondaryBackground,
        size: widget.iconSize,
      ),
    );

    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: widget.width ?? widget.size,
        height: widget.height ?? widget.size,
        child: Center(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              // Apply scale animation when recording state indicates active recording
              return Transform.scale(
                scale: shouldAnimate ? _scaleAnimation.value : 1.0,
                child: buttonContent,
              );
            },
          ),
        ),
      ),
    );
  }
}
