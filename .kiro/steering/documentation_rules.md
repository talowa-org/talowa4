---
inclusion: always
---

# 📚 DOCUMENTATION ORGANIZATION RULES

## 🎯 Core Principle
**One Feature = One Documentation File**

For each feature or system in the TALOWA app, there should be exactly ONE comprehensive .md file that contains ALL information about that feature. This eliminates scattered documentation and ensures developers can find everything they need in a single location.

---

## 📁 Documentation Structure

### Consolidated Documentation Location
All feature documentation is located in: `/docs/`

### Feature-Specific Files
Each major feature has exactly one comprehensive documentation file:

- **Authentication System** → `docs/AUTHENTICATION_SYSTEM.md`
- **Referral System** → `docs/REFERRAL_SYSTEM.md`
- **Navigation System** → `docs/NAVIGATION_SYSTEM.md`
- **Home Tab System** → `docs/HOME_TAB_SYSTEM.md`
- **Feed System** → `docs/FEED_SYSTEM.md`
- **Network System** → `docs/NETWORK_SYSTEM.md`
- **Messages System** → `docs/MESSAGES_SYSTEM.md`
- **Payment System** → `docs/PAYMENT_SYSTEM.md`
- **Deployment Guide** → `docs/DEPLOYMENT_GUIDE.md`
- **Firebase Configuration** → `docs/FIREBASE_CONFIGURATION.md`
- **AI Assistant System** → `docs/AI_ASSISTANT_SYSTEM.md`
- **Admin System** → `docs/ADMIN_SYSTEM.md`
- **Security System** → `docs/SECURITY_SYSTEM.md`
- **Testing Guide** → `docs/TESTING_GUIDE.md`
- **Troubleshooting Guide** → `docs/TROUBLESHOOTING_GUIDE.md`
- **Architecture Overview** → `docs/ARCHITECTURE_OVERVIEW.md`

---

## 📋 Documentation Standards

### File Naming Convention
- Use `UPPER_CASE_WITH_UNDERSCORES.md`
- Be descriptive and specific
- End with `_SYSTEM.md` for technical systems
- End with `_GUIDE.md` for procedural documentation

### Content Structure Template
Each documentation file must follow this structure:

```markdown
# 🎯 [FEATURE NAME] - Complete Reference

## 📋 Overview
Brief description of the feature/system

## 🏗️ System Architecture
Technical architecture and components

## 🔧 Implementation Details
Code structure, key files, and technical details

## 🎯 Features & Functionality
Detailed feature descriptions

## 🔄 User Flows
Step-by-step user interaction flows

## 🎨 UI/UX Design (if applicable)
Design specifications and guidelines

## 🛡️ Security & Validation (if applicable)
Security measures and data validation

## 🔧 Configuration & Setup
Setup instructions and configuration

## 🐛 Common Issues & Solutions
Troubleshooting and problem resolution

## 📊 Analytics & Monitoring (if applicable)
Metrics, monitoring, and analytics

## 🚀 Recent Improvements
Latest updates and enhancements

## 🔮 Future Enhancements
Planned features and roadmap

## 📞 Support & Troubleshooting
Debug commands and support information

## 📋 Testing Procedures
Testing guidelines and procedures

## 📚 Related Documentation
Cross-references to other documentation

---
**Status**: Current status
**Last Updated**: Date
**Priority**: Priority level
**Maintainer**: Responsible team
```

---

## 🚫 What NOT to Do

### ❌ Avoid These Practices
1. **Multiple files for one feature** - Don't create separate files like:
   - `REFERRAL_SYSTEM_PART1.md`
   - `REFERRAL_SYSTEM_PART2.md`
   - `REFERRAL_SYSTEM_FIXES.md`

2. **Scattered information** - Don't spread feature info across:
   - Implementation files
   - Fix files
   - Summary files
   - Status files

3. **Duplicate content** - Don't repeat the same information in multiple files

4. **Vague file names** - Avoid names like:
   - `FIXES_COMPLETE.md`
   - `IMPLEMENTATION_SUMMARY.md`
   - `SYSTEM_UPDATE.md`

---

## ✅ What TO Do

### ✅ Follow These Practices
1. **Consolidate everything** - Put ALL information about a feature in its single file
2. **Update existing files** - When making changes, update the main feature file
3. **Cross-reference properly** - Link to related documentation files
4. **Keep it current** - Update the "Last Updated" date when making changes
5. **Use consistent structure** - Follow the template structure for all files

---

## 🔄 Migration Process

### When Creating New Documentation
1. **Check if feature file exists** - Look in `/docs/` directory first
2. **Update existing file** - If file exists, add new information to it
3. **Create new file only if needed** - Only create new file for genuinely new features
4. **Follow naming convention** - Use the established naming pattern
5. **Use complete template** - Include all required sections

### When Updating Existing Features
1. **Find the main feature file** - Locate the single comprehensive file
2. **Update relevant sections** - Add new information to appropriate sections
3. **Update metadata** - Change "Last Updated" date and status
4. **Cross-check completeness** - Ensure all aspects of the feature are covered

---

## 📚 Archive Policy

### Old Scattered Files
- Old scattered .md files are archived in `/archive/old_docs/`
- These files are kept for reference but should not be updated
- All new updates go to the consolidated files in `/docs/`

### Archive Index
- `/archive/old_docs/ARCHIVE_INDEX.md` contains migration information
- Shows mapping from old files to new consolidated files
- Provides migration date and rationale

---

## 🎯 Benefits of This System

### For Developers
- **Single Source of Truth** - One place to find all feature information
- **Faster Information Access** - No need to search through multiple files
- **Complete Context** - All related information in one location
- **Easier Maintenance** - Update one file instead of many

### For Project Management
- **Clear Documentation Status** - Easy to see what's documented
- **Consistent Structure** - Predictable information organization
- **Better Cross-referencing** - Clear relationships between features
- **Reduced Duplication** - No conflicting or duplicate information

---

## 🔍 Compliance Checking

### Before Creating New .md Files
Ask yourself:
1. Does this information belong in an existing feature file?
2. Is this a genuinely new feature that needs its own file?
3. Am I following the naming convention?
4. Am I using the complete template structure?

### Regular Audits
Periodically review the `/docs/` directory to ensure:
- No duplicate information across files
- All files follow the standard structure
- Cross-references are accurate and up-to-date
- Archive policy is being followed

---

## 📞 Questions or Exceptions

If you're unsure about where to put documentation or need to create an exception to these rules:

1. **Check existing files first** - Review `/docs/` directory
2. **Consider the feature scope** - Is this part of an existing system?
3. **Follow the principle** - One feature = one file
4. **Document your reasoning** - If creating an exception, document why

Remember: The goal is to make documentation **easy to find, complete, and maintainable**. These rules support that goal.