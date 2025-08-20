import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:talowa/main.dart' as app;
import 'package:talowa/services/auth_service.dart';
import 'package:talowa/services/messaging/messaging_service.dart';
import 'package:talowa/services/land_records_service.dart';
import 'package:talowa/services/referral_service.dart';
import '../test_utils/test_data_factory.dart';
import '../test_utils/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End