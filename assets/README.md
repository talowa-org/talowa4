# Assets

This directory contains static assets for the Talowa application.

## Logo

Currently using a placeholder icon (landscape icon) in the landing screen.

**To add your logo:**
1. Add your logo file as `assets/logo.png`
2. Update `lib/screens/auth/landing_screen.dart` to use:
   ```dart
   Image.asset(
     'assets/logo.png',
     height: 120,
   ),
   ```
3. Remove the placeholder Container with the landscape icon

## Recommended Logo Specifications
- **Format**: PNG with transparent background
- **Size**: 512x512px or higher (square aspect ratio)
- **Style**: Simple, clean design that works on white backgrounds
- **Colors**: Should complement the green theme (#4CAF50)
