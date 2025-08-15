import '/components/transcription_bubbles_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/permissions_util.dart';
import 'conversational_demo_widget.dart' show ConversationalDemoWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ConversationalDemoModel
    extends FlutterFlowModel<ConversationalDemoWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - getCredentials] action in ConversationalDemo widget.
  String? getCredentials;
  // Stores action output result for [Custom Action - initializeConversationService] action in ConversationalDemo widget.
  String? initElevenlabs;
  // State field(s) for ListView widget.
  ScrollController? listViewController;
  // Models for TranscriptionBubbles dynamic component.
  late FlutterFlowDynamicModels<TranscriptionBubblesModel>
      transcriptionBubblesModels;

  @override
  void initState(BuildContext context) {
    listViewController = ScrollController();
    transcriptionBubblesModels =
        FlutterFlowDynamicModels(() => TranscriptionBubblesModel());
  }

  @override
  void dispose() {
    listViewController?.dispose();
    transcriptionBubblesModels.dispose();
  }
}
