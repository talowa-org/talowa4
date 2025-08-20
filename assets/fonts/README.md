# Font Assets

This directory contains font files for supporting multiple languages in the TALOWA app.

## Required Fonts

### Devanagari Script (Hindi, Marathi)
- NotoSansDevanagari-Regular.ttf
- NotoSansDevanagari-Bold.ttf

### Telugu Script
- NotoSansTelugu-Regular.ttf
- NotoSansTelugu-Bold.ttf

### Tamil Script
- NotoSansTamil-Regular.ttf
- NotoSansTamil-Bold.ttf

## Font Sources

All fonts should be downloaded from Google Fonts Noto collection:
- https://fonts.google.com/noto/specimen/Noto+Sans+Devanagari
- https://fonts.google.com/noto/specimen/Noto+Sans+Telugu
- https://fonts.google.com/noto/specimen/Noto+Sans+Tamil

## Installation Instructions

1. Download the required font files from Google Fonts
2. Place them in this directory with the exact names specified above
3. Run `flutter clean && flutter pub get` to refresh assets
4. The fonts will be automatically configured in pubspec.yaml

## Font Usage

The fonts are automatically applied based on the selected language:
- English: Default system font
- Hindi: NotoSansDevanagari
- Telugu: NotoSansTelugu
- Tamil: NotoSansTamil

The LocalizationService handles font switching automatically when the language is changed.