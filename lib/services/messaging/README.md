# TALOWA File Sharing and Media Handling System

This directory contains the comprehensive file sharing and media handling system for TALOWA's in-app communication platform. The system implements secure file upload, virus scanning, encryption, media compression, and automatic integration with land records.

## Overview

The file sharing system is designed to handle sensitive documents and media files related to land rights activism, with enterprise-grade security and privacy protection.

## Key Features

### 🔒 Security Features
- **Virus Scanning**: Multi-layered security scanning with signature detection, heuristic analysis, and behavioral checks
- **File Encryption**: End-to-end encryption for sensitive documents
- **Access Control**: Role-based access with expiration times
- **Format Validation**: Magic number verification to prevent format spoofing
- **Size Limits**: Configurable file size limits by type

### 📱 Media Processing
- **Image Compression**: Intelligent compression with quality optimization
- **Thumbnail Generation**: Automatic thumbnail creation for images
- **Multiple Variants**: Generate preview, thumbnail, and full-size versions
- **Metadata Extraction**: Extract EXIF data and GPS coordinates from images
- **Audio/Video Support**: Basic support for audio and video files

### 🗺️ Land Record Integration
- **GPS-based Linking**: Automatically link files to nearby land records
- **Content Analysis**: Link files based on keywords and tags
- **Smart Suggestions**: Suggest relevant land records for manual linking
- **Auto-tagging**: Generate tags based on linked land records

### 📊 File Management
- **Comprehensive Metadata**: Track upload time, file size, scan results, GPS location
- **Audit Trail**: Complete logging of file operations
- **Expiration Handling**: Automatic cleanup of expired files
- **Batch Operations**: Support for multiple file uploads

## Architecture

```
File Sharing System
├── FileSharingService (Main orchestrator)
├── VirusScanningService (Security scanning)
├── MediaCompressionService (Image/audio/video processing)
├── LandRecordIntegrationService (Auto-linking to land records)
├── FileModel (Data model)
└── Supporting utilities
```

## Services

### FileSharingService
Main service that orchestrates the entire file upload and management process.

**Key Methods:**
- `uploadFile()` - Complete file upload with security and processing
- `downloadFile()` - Secure file download with access control
- `deleteFile()` - File deletion with cleanup
- `getFilesForMessage()` - Retrieve files for a message

### VirusScanningService
Comprehensive security scanning service with multiple detection methods.

**Scanning Methods:**
- Basic validation (file size, extension, structure)
- Signature-based detection (known malware patterns)
- Heuristic analysis (entropy, suspicious strings)
- Behavioral analysis (metadata, timestamps)

### MediaCompressionService
Handles compression and optimization of media files.

**Compression Levels:**
- Minimal: High quality, larger size
- Balanced: Good quality, moderate size
- Maximum: Lower quality, smallest size

### LandRecordIntegrationService
Automatically links files to relevant land records using multiple strategies.

**Linking Strategies:**
- GPS-based proximity matching
- Content analysis and keyword matching
- User activity patterns

## File Types and Limits

| Type | Extensions | Max Size | Features |
|------|------------|----------|----------|
| Images | jpg, png, gif, webp, bmp, tiff | 25MB | Compression, thumbnails, EXIF |
| Documents | pdf, doc, docx, txt, rtf, xls, xlsx | 25MB | Virus scanning, encryption |
| Audio | mp3, wav, aac, m4a, ogg, flac | 50MB | Compression, metadata |
| Video | mp4, mov, avi, mkv, webm, 3gp | 100MB | Thumbnail extraction |

## Security Model

### Access Levels
- **Public**: Accessible to all users
- **Group**: Accessible to group members only
- **Private**: Accessible to specific authorized users

### Encryption
- Files can be encrypted using AES-256 encryption
- Encryption keys are managed per file
- Encrypted files require decryption for access

### Virus Scanning
- All files are scanned before upload
- Multiple detection methods prevent various attack vectors
- Suspicious files are blocked and logged

## Usage Examples

### Basic File Upload
```dart
final fileSharingService = FileSharingService();

final fileModel = await fileSharingService.uploadFile(
  file: selectedFile,
  messageId: 'msg_123',
  encryptFile: true,
  tags: ['land_document', 'patta'],
  onProgress: (progress) => print('Upload: ${(progress * 100).toInt()}%'),
);
```

### Secure File Download
```dart
final fileData = await fileSharingService.downloadFile('file_id_123');
// File is automatically decrypted if encrypted
```

### Get Land Record Suggestions
```dart
final integrationService = LandRecordIntegrationService();

final suggestions = await integrationService.getSuggestedLandRecords(
  userId: currentUserId,
  gpsLocation: extractedGpsLocation,
  tags: ['survey_123', 'village_name'],
);
```

### Virus Scanning
```dart
final virusScanner = VirusScanningService();
final scanResult = await virusScanner.scanFile(file);

if (!scanResult.isClean) {
  print('Threats detected: ${scanResult.threats.join(', ')}');
}
```

## Data Models

### FileModel
Complete file metadata including security scan results, GPS location, and land record links.

### SecurityScanResult
Results from virus scanning including threat details and scan metadata.

### GpsLocation
GPS coordinates extracted from image EXIF data.

### FileMetadata
Technical metadata including dimensions, duration, and EXIF data.

## Error Handling

The system implements comprehensive error handling:
- Graceful degradation when services are unavailable
- Detailed error messages for debugging
- Automatic retry for transient failures
- Fallback options for critical operations

## Testing

Comprehensive test suite covers:
- File validation and security scanning
- Virus detection with EICAR test files
- Access control and permissions
- Land record integration
- Error handling scenarios

Run tests with:
```bash
flutter test test/services/messaging/file_sharing_service_test.dart
```

## Configuration

### File Size Limits
Adjust limits in `FileSharingService`:
```dart
static const int maxImageSize = 25 * 1024 * 1024; // 25MB
static const int maxDocumentSize = 25 * 1024 * 1024; // 25MB
```

### Compression Settings
Configure compression in `MediaCompressionService`:
```dart
static const int defaultImageQuality = 85;
static const int maxImageDimension = 2048;
```

### Security Settings
Configure scanning sensitivity in `VirusScanningService`:
```dart
static const List<String> suspiciousExtensions = ['exe', 'bat', 'cmd'];
```

## Performance Considerations

- Files are processed asynchronously to avoid blocking UI
- Large files are processed in chunks
- Thumbnails are generated lazily
- Metadata extraction is optimized for common formats
- Caching is used for frequently accessed files

## Privacy and Compliance

- GPS coordinates are only extracted with user consent
- Encrypted files cannot be accessed without proper keys
- Audit logs track all file operations
- Files can be automatically deleted after expiration
- GDPR-compliant data export and deletion

## Future Enhancements

- Integration with professional antivirus services
- Advanced video processing and compression
- OCR for document text extraction
- Machine learning for content classification
- Blockchain-based file integrity verification

## Dependencies

- `firebase_storage`: File storage backend
- `cloud_firestore`: Metadata storage
- `image`: Image processing and compression
- `crypto`: Cryptographic operations
- `path`: File path utilities

## Requirements Fulfilled

This implementation fulfills the following requirements from the in-app communication spec:

- **4.1**: Secure file upload service with virus scanning and encryption ✅
- **4.2**: Media compression and optimization for images and voice messages ✅
- **4.3**: File download system with access control and expiration ✅
- **4.4**: Integration with land records system to automatically link documents ✅
- **4.5**: GPS extraction from photos to link with land record locations ✅

The system provides enterprise-grade file handling capabilities specifically designed for the needs of land rights activism, with strong security, privacy protection, and intelligent integration with the broader TALOWA platform.