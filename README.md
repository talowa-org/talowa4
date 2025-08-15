# TALOWA - Land Rights Activism Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.32.7-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Deployed-orange.svg)](https://firebase.google.com/)
[![Live Demo](https://img.shields.io/badge/Live%20Demo-talowa.web.app-green.svg)](https://talowa.web.app)

**Empowering land rights activism through technology**

TALOWA is a comprehensive Flutter-based platform designed to help land rights activists organize, communicate, and fight for their rights through technology. Built for 5+ million users with messaging, social feed, network management, legal case tracking, and privacy protection.

## 🚀 **Live Application**

- **Web App**: [https://talowa.web.app](https://talowa.web.app)
- **AI Assistant**: [https://asia-south1-talowa.cloudfunctions.net/aiRespond](https://asia-south1-talowa.cloudfunctions.net/aiRespond)
- **Firebase Console**: [https://console.firebase.google.com/project/talowa](https://console.firebase.google.com/project/talowa)

## ✨ **Key Features**

### 🏠 **Core Platform**
- **5-Tab Navigation**: Home, Feed, Messages, Network, More
- **Multi-Language Support**: Telugu, Hindi, English
- **PWA Support**: Mobile-like experience on web
- **Responsive Design**: Works on all screen sizes
- **Offline Support**: Core functionality works offline

### 🤖 **AI Assistant**
- **Voice & Text Input**: Natural language processing
- **Context-Aware Responses**: Based on user profile and location
- **Emergency Detection**: Automatic routing for urgent issues
- **Navigation Help**: Smart suggestions and guidance
- **Multi-Language**: Supports Telugu, Hindi, and English

### 🔐 **Privacy & Security**
- **Role-Based Access**: Village, Mandal, District, State coordinators
- **Contact Privacy**: Protected visibility based on referral relationships
- **Secure Messaging**: End-to-end encryption for sensitive communications
- **Anonymous Reporting**: Protected identity for whistleblowers
- **Data Protection**: GDPR-compliant data handling

### 📱 **Social Features**
- **Social Feed**: Instagram-like posts and engagement
- **Stories**: 24-hour temporary content sharing
- **Network Management**: Referral system and team building
- **Emergency Broadcasting**: Priority notifications for urgent issues
- **Campaign Coordination**: Movement organization tools

### ⚖️ **Legal Support**
- **Land Records**: GPS-tagged property documentation
- **Legal Case Tracking**: Court dates, documents, progress
- **Lawyer Directory**: Verified legal professionals
- **Document Storage**: Secure cloud storage for legal papers
- **Issue Reporting**: Evidence collection and case building

## 🛠️ **Technology Stack**

### **Frontend**
- **Flutter 3.32.7**: Cross-platform mobile and web development
- **Material Design 3**: Modern, accessible UI components
- **Provider**: State management
- **Cached Network Image**: Optimized image loading
- **FL Chart**: Data visualization

### **Backend & Services**
- **Firebase Authentication**: Phone number + PIN system
- **Cloud Firestore**: NoSQL database with real-time sync
- **Firebase Storage**: Secure file storage
- **Cloud Functions**: Serverless backend (Node.js 20)
- **Firebase Hosting**: PWA-enabled web hosting

### **AI & Integration**
- **OpenRouter API**: AI model access (Llama 3.1 8B)
- **Speech Recognition**: Voice input processing
- **Text-to-Speech**: Voice output
- **Geolocation**: GPS and location services

## 🚀 **Getting Started**

### **Prerequisites**
- Flutter 3.32.7 or higher
- Firebase CLI 14.12.0 or higher
- Node.js 20+ (for Cloud Functions)
- Android Studio / VS Code

### **Installation**

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/talowa.git
   cd talowa
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Install Functions dependencies**
   ```bash
   cd functions
   npm install
   cd ..
   ```

4. **Configure Firebase**
   ```bash
   firebase use talowa
   ```

5. **Build and run**
   ```bash
   # For web
   flutter build web
   flutter run -d chrome
   
   # For mobile
   flutter run
   ```

### **Deployment**

1. **Build the web app**
   ```bash
   flutter build web
   ```

2. **Deploy to Firebase**
   ```bash
   firebase deploy
   ```

## 📊 **Project Structure**

```
talowa/
├── lib/                    # Flutter source code
│   ├── core/              # Core utilities and themes
│   ├── models/            # Data models
│   ├── screens/           # UI screens
│   ├── services/          # Business logic
│   └── widgets/           # Reusable components
├── functions/             # Cloud Functions
│   ├── src/               # TypeScript source
│   └── lib/               # Compiled JavaScript
├── web/                   # Web-specific files
├── test/                  # Test files
├── docs/                  # Documentation
├── firebase.json          # Firebase configuration
├── firestore.rules        # Database security rules
└── pubspec.yaml          # Flutter dependencies
```

## 🔧 **Configuration**

### **Firebase Setup**
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Authentication, Firestore, Storage, Functions, and Hosting
3. Configure security rules using the provided `firestore.rules` and `storage.rules`
4. Set up environment variables for Cloud Functions

### **Environment Variables**
Create `functions/.env.talowa`:
```env
OPENROUTER_MODEL=meta-llama/llama-3.1-8b-instruct
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENROUTER_FALLBACK_MODEL=qwen/qwen2.5-7b-instruct
```

## 🧪 **Testing**

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/ai_assistant_service_test.dart

# Run with coverage
flutter test --coverage
```

## 📈 **Performance**

- **Web Build Time**: ~88 seconds
- **Font Optimization**: 98.7% reduction through tree-shaking
- **Target Load Time**: <3 seconds on 2G networks
- **Scalability**: Designed for 5+ million concurrent users

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **Flutter Team**: For the amazing cross-platform framework
- **Firebase Team**: For the comprehensive backend services
- **OpenRouter**: For AI model access and integration
- **Land Rights Activists**: For inspiration and requirements
- **Open Source Community**: For the incredible tools and libraries

## 📞 **Support**

- **Documentation**: [docs/README.md](docs/README.md)
- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/talowa/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/talowa/discussions)

---

**Built with ❤️ for land rights activists across India 🇮🇳**

*Empowering communities through technology*