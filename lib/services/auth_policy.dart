// lib/auth_policy.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Keep this identical across registration AND login.
/// If you ever change the version/scheme, bump HASH_VERSION
/// and migrate old users (don't just change the string).
const String kHybridEmailDomain = 'talowa.app'; // <— keep this CONSISTENT
const String HASH_VERSION = 'v1';

/// Minimal E.164 normalizer for India-first.
/// If your app needs true worldwide parsing, integrate libphonenumber.
/// This preserves leading zeros in PINs because we treat them as strings.
String normalizePhoneE164(String raw, {String defaultCountryCode = '+91'}) {
  var p = raw.trim().replaceAll(' ', '');
  // Remove common formatting
  p = p.replaceAll(RegExp(r'[^0-9\+]'), '');
  // Already E.164
  if (p.startsWith('+')) return p;
  // 10 digits → assume Indian mobile
  if (RegExp(r'^[0-9]{10}$').hasMatch(p)) return '$defaultCountryCode$p';
  // 12 digits starting with 91 → add '+'
  if (RegExp(r'^91[0-9]{10}$').hasMatch(p)) return '+$p';
  // Fallback: prefix default code
  if (!p.startsWith('+')) return '$defaultCountryCode$p';
  return p;
}

/// Our pseudo-email for Firebase Email/Password auth.
String phoneToAliasEmail(String e164) => '$e164@$kHybridEmailDomain';

/// Deterministic hash of PIN as lowercase hex.
/// DO NOT parse the PIN as int (leading zeros would be lost).
String hashPin(String pin) {
  final clean = pin.trim();
  final bytes = utf8.encode('$HASH_VERSION:$clean');
  return sha256.convert(bytes).toString(); // lowercase hex
}

// Legacy function names for backward compatibility
String normalizeE164(String input, {String defaultCountry = '+91'}) => 
    normalizePhoneE164(input, defaultCountryCode: defaultCountry);

String aliasEmailForPhone(String e164) => phoneToAliasEmail(e164);

String passwordFromPin(String pin) => hashPin(pin);

bool isValidPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);