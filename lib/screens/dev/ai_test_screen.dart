import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_theme.dart';
import '../../config/app_config.dart';

class AITestScreen extends StatefulWidget {
  const AITestScreen({super.key});

  @override
  State<AITestScreen> createState() => _AITestScreenState();
}

class _AITestScreenState extends State<AITestScreen> {
  final _controller = TextEditingController(text: 'Hello');
  bool _loading = false;
  String? _result;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        setState(() {
          _error = 'You must be signed in to call the AI backend (no ID token)';
          _loading = false;
        });
        return;
      }

      final uri = Uri.parse('${AppConfig.aiBackendBaseUrl}/aiRespond');
      final body = jsonEncode({
        'query': _controller.text.trim().isEmpty ? 'Hello' : _controller.text.trim(),
        'lang': 'en',
        'isVoice': false,
      });

      final resp = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      final pretty = (String s) {
        try {
          final o = jsonDecode(s);
          return const JsonEncoder.withIndent('  ').convert(o);
        } catch (_) {
          return s;
        }
      };

      setState(() {
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          _result = 'HTTP ${resp.statusCode}\n\n' + pretty(resp.body);
        } else {
          _error = 'HTTP ${resp.statusCode}\n\n' + pretty(resp.body);
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Request failed: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Assistant Test',
          style: TextStyle(
            fontFamily: 'NotoSansTelugu',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.talowaGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Ask something',
                hintText: 'e.g., How to apply for patta?'
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            ElevatedButton.icon(
              onPressed: _loading ? null : _send,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_loading ? 'Sending...' : 'Send to AI'),
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _error ?? _result ?? 'Response will appear here...',
                    style: TextStyle(
                      color: _error != null ? Colors.red[700] : Colors.black87,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

