import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'universal_link_service.dart';
import 'referral_lookup_service.dart';

/// Exception thrown when QR scanning fails
class QRScanException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? context;
  
  const QRScanException(this.message, [this.code = 'QR_SCAN_FAILED', this.context]);
  
  @override
  String toString() => 'QRScanException: $message';
}

/// Service for scanning QR codes and handling referral links
class QRScannerService {
  static QRViewController? _controller;
  static StreamSubscription<Barcode>? _scanSubscription;
  static bool _isScanning = false;
  
  /// Callback functions
  static Function(String)? _onReferralCodeScanned;
  static Function(String)? _onScanError;
  static Function()? _onPermissionDenied;
  
  /// Initialize QR scanner
  static Future<void> initialize({
    Function(String)? onReferralCodeScanned,
    Function(String)? onScanError,
    Function()? onPermissionDenied,
  }) async {
    _onReferralCodeScanned = onReferralCodeScanned;
    _onScanError = onScanError;
    _onPermissionDenied = onPermissionDenied;
  }
  
  /// Set QR controller when scanner widget is ready
  static void setController(QRViewController controller) {
    _controller = controller;
    _startListening();
  }
  
  /// Start listening for QR codes
  static void _startListening() {
    if (_controller == null || _isScanning) return;
    
    _isScanning = true;
    _scanSubscription = _controller!.scannedDataStream.listen(
      _handleScannedData,
      onError: (error) {
        _onScanError?.call('Scanner error: $error');
      },
    );
  }
  
  /// Handle scanned QR code data
  static void _handleScannedData(Barcode scanData) async {
    if (scanData.code == null || scanData.code!.isEmpty) {
      _onScanError?.call('Empty QR code scanned');
      return;
    }
    
    try {
      await _processScannedCode(scanData.code!);
    } catch (e) {
      _onScanError?.call('Failed to process scanned code: $e');
    }
  }
  
  /// Process scanned QR code
  static Future<void> _processScannedCode(String scannedData) async {
    try {
      // Check if it's a TALOWA referral link
      if (UniversalLinkService.isReferralLink(scannedData)) {
        final referralCode = UniversalLinkService.parseReferralCodeFromUrl(scannedData);
        if (referralCode != null) {
          await _validateAndProcessReferralCode(referralCode);
          return;
        }
      }
      
      // Check if it's a direct referral code
      if (ReferralLookupService.isValidCodeFormat(scannedData)) {
        await _validateAndProcessReferralCode(scannedData);
        return;
      }
      
      // Check if it's a URL that might contain a referral code
      if (_isUrl(scannedData)) {
        final referralCode = _extractReferralCodeFromAnyUrl(scannedData);
        if (referralCode != null) {
          await _validateAndProcessReferralCode(referralCode);
          return;
        }
      }
      
      _onScanError?.call('QR code does not contain a valid TALOWA referral code');
    } catch (e) {
      throw QRScanException(
        'Failed to process scanned code: $e',
        'PROCESSING_FAILED',
        {'scannedData': scannedData}
      );
    }
  }
  
  /// Validate and process referral code
  static Future<void> _validateAndProcessReferralCode(String referralCode) async {
    try {
      // Validate referral code
      final isValid = await ReferralLookupService.isValidReferralCode(referralCode);
      if (!isValid) {
        _onScanError?.call('Invalid or inactive referral code: $referralCode');
        return;
      }
      
      // Pause scanning temporarily to prevent multiple scans
      await pauseScanning();
      
      // Notify callback
      _onReferralCodeScanned?.call(referralCode);
      
      // Resume scanning after a delay
      Future.delayed(Duration(seconds: 3), () {
        resumeScanning();
      });
      
    } catch (e) {
      _onScanError?.call('Failed to validate referral code: $e');
    }
  }
  
  /// Pause QR scanning
  static Future<void> pauseScanning() async {
    try {
      await _controller?.pauseCamera();
      _isScanning = false;
    } catch (e) {
      // Handle gracefully
    }
  }
  
  /// Resume QR scanning
  static Future<void> resumeScanning() async {
    try {
      await _controller?.resumeCamera();
      _isScanning = true;
    } catch (e) {
      // Handle gracefully
    }
  }
  
  /// Stop QR scanning
  static Future<void> stopScanning() async {
    try {
      _isScanning = false;
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      await _controller?.pauseCamera();
    } catch (e) {
      // Handle gracefully
    }
  }
  
  /// Dispose QR scanner resources
  static Future<void> dispose() async {
    try {
      await stopScanning();
      await _controller?.dispose();
      _controller = null;
    } catch (e) {
      // Handle gracefully
    }
  }
  
  /// Toggle flashlight
  static Future<void> toggleFlash() async {
    try {
      await _controller?.toggleFlash();
    } catch (e) {
      _onScanError?.call('Failed to toggle flash: $e');
    }
  }
  
  /// Flip camera (front/back)
  static Future<void> flipCamera() async {
    try {
      await _controller?.flipCamera();
    } catch (e) {
      _onScanError?.call('Failed to flip camera: $e');
    }
  }
  
  /// Get camera flash status
  static Future<bool?> getFlashStatus() async {
    try {
      return await _controller?.getFlashStatus();
    } catch (e) {
      return null;
    }
  }
  
  /// Get camera info
  static Future<CameraFacing?> getCameraInfo() async {
    try {
      return await _controller?.getCameraInfo();
    } catch (e) {
      return null;
    }
  }
  
  /// Check if scanning is active
  static bool get isScanning => _isScanning;
  
  /// Check if controller is available
  static bool get hasController => _controller != null;
  
  /// Manually process a code (for testing)
  static Future<void> processCode(String code) async {
    await _processScannedCode(code);
  }
  
  /// Check if string is a URL
  static bool _isUrl(String text) {
    try {
      final uri = Uri.parse(text);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
  
  /// Extract referral code from any URL
  static String? _extractReferralCodeFromAnyUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Check query parameters for common referral parameter names
      final referralParams = ['ref', 'referral', 'code', 'invite', 'r'];
      for (final param in referralParams) {
        final value = uri.queryParameters[param];
        if (value != null && ReferralLookupService.isValidCodeFormat(value)) {
          return value.toUpperCase();
        }
      }
      
      // Check path segments
      for (final segment in uri.pathSegments) {
        if (ReferralLookupService.isValidCodeFormat(segment)) {
          return segment.toUpperCase();
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Get supported QR code formats
  static List<BarcodeFormat> getSupportedFormats() {
    return [
      BarcodeFormat.qrcode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.aztec,
    ];
  }
  
  /// Validate QR scanner permissions
  static Future<bool> checkPermissions() async {
    try {
      // This would check camera permissions
      // For now, return true
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Request QR scanner permissions
  static Future<bool> requestPermissions() async {
    try {
      // This would request camera permissions
      // For now, return true
      return true;
    } catch (e) {
      _onPermissionDenied?.call();
      return false;
    }
  }
  
  /// Get scanner statistics
  static Map<String, dynamic> getStatistics() {
    return {
      'isScanning': _isScanning,
      'hasController': hasController,
      'hasSubscription': _scanSubscription != null,
    };
  }
  
  /// Reset scanner state
  static void reset() {
    _isScanning = false;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _controller = null;
  }
}
