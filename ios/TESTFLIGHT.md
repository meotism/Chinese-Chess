# iOS TestFlight Deployment Guide

This guide provides step-by-step instructions for deploying the Chinese Chess (Xiangqi) iOS application to TestFlight for beta testing.

## Prerequisites

### Developer Account
- Apple Developer Program membership ($99/year)
- Access to [App Store Connect](https://appstoreconnect.apple.com)

### Development Environment
- macOS with Xcode 15 or later
- Valid Apple Developer signing certificates
- Provisioning profiles for the app

### Required Tools
```bash
# Install Xcode command line tools
xcode-select --install

# Install xcodegen for project generation
brew install xcodegen

# Install fastlane (optional, for automation)
brew install fastlane
```

## Step 1: App Store Connect Setup

### 1.1 Create App Record

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps" > "+" > "New App"
3. Fill in the required information:
   - **Platform**: iOS
   - **Name**: Chinese Chess - Xiangqi
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: com.yourcompany.chinesechess
   - **SKU**: XIANGQI-IOS-001
   - **User Access**: Full Access

### 1.2 App Information

In the App Information section:
- **Subtitle**: Real-time Online Multiplayer
- **Category**: Games > Board
- **Content Rights**: Does not contain third-party content
- **Age Rating**: 4+ (No objectionable content)

### 1.3 Privacy Policy

Prepare a privacy policy URL. Required disclosures:
- Device identifier collection (for matchmaking)
- Game history storage
- No personal data collection (anonymous play)

## Step 2: Xcode Project Configuration

### 2.1 Generate Xcode Project

```bash
cd ios/ChineseChess
xcodegen generate
open ChineseChess.xcodeproj
```

### 2.2 Configure Signing

1. Open the project in Xcode
2. Select the ChineseChess target
3. Go to "Signing & Capabilities" tab
4. Enable "Automatically manage signing"
5. Select your development team
6. Verify Bundle Identifier matches App Store Connect

### 2.3 Set Version and Build Number

In project settings:
- **Version**: 1.0.0 (Marketing version)
- **Build**: 1 (Increment for each upload)

Or via command line:
```bash
# Update version
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0.0" ChineseChess/Info.plist

# Update build number
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 1" ChineseChess/Info.plist
```

### 2.4 Configure App Icons

Ensure all required app icon sizes are provided:
- 20pt (2x, 3x)
- 29pt (2x, 3x)
- 40pt (2x, 3x)
- 60pt (2x, 3x)
- 1024pt (App Store)

### 2.5 Add Required Capabilities

In Signing & Capabilities, ensure these are enabled:
- Push Notifications (if using)
- Background Modes (if needed for background network)

## Step 3: Create Archive

### 3.1 Select Device

1. In Xcode, select "Any iOS Device (arm64)" as the build target
2. This is required for creating an archive

### 3.2 Build Archive

Via Xcode:
1. Product > Archive
2. Wait for the build to complete
3. Organizer window will open automatically

Via command line:
```bash
# Clean build folder
xcodebuild clean -scheme ChineseChess -configuration Release

# Build archive
xcodebuild archive \
  -scheme ChineseChess \
  -configuration Release \
  -archivePath ./build/ChineseChess.xcarchive \
  -destination "generic/platform=iOS"
```

### 3.3 Validate Archive

In the Organizer:
1. Select the archive
2. Click "Validate App"
3. Choose "App Store Connect" distribution
4. Select signing options
5. Review and validate
6. Fix any validation errors before proceeding

## Step 4: Upload to App Store Connect

### 4.1 Via Xcode Organizer

1. Select the validated archive
2. Click "Distribute App"
3. Select "App Store Connect"
4. Choose "Upload"
5. Select distribution options:
   - Include symbols: Yes
   - Upload app symbols: Yes
6. Wait for upload to complete

### 4.2 Via Command Line

```bash
# Export IPA
xcodebuild -exportArchive \
  -archivePath ./build/ChineseChess.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath ./build

# Upload using altool
xcrun altool --upload-app \
  -f ./build/ChineseChess.ipa \
  -t ios \
  -u "your-apple-id@email.com" \
  -p "@keychain:AC_PASSWORD"
```

ExportOptions.plist:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <true/>
</dict>
</plist>
```

## Step 5: Configure TestFlight

### 5.1 Wait for Processing

After upload, the build will be processed:
- Processing takes 10-30 minutes
- You'll receive an email when complete
- Build will appear in TestFlight section

### 5.2 Add Test Information

1. Go to App Store Connect > TestFlight
2. Select the uploaded build
3. Add test information:
   - **What to Test**: Focus areas for testers
   - **Test Account**: Not required (anonymous play)
   - **Feedback Email**: Your support email

### 5.3 Export Compliance

Answer export compliance questions:
- "Does your app use encryption?": Yes (HTTPS/TLS)
- "Does your app qualify for exemption?": Yes (standard protocols)

### 5.4 Configure Test Groups

**Internal Testing** (Up to 100 testers):
1. Create group: "Internal Testers"
2. Add Apple IDs of internal testers
3. Assign build to group
4. Testers receive invitation email

**External Testing** (Up to 10,000 testers):
1. Create group: "Beta Testers"
2. Submit for Beta App Review
3. Wait for approval (usually 24-48 hours)
4. Add testers via:
   - Individual email invites
   - Public link (optional)

## Step 6: Beta App Review

For external testing, Apple reviews the build:

### 6.1 Required Information
- App description
- Contact information
- Test instructions
- Demo video (optional but recommended)

### 6.2 Review Guidelines
The app must comply with:
- No crashes or critical bugs
- No placeholder content
- Functional core features
- Appropriate content rating

### 6.3 Review Timeline
- First review: 24-48 hours
- Subsequent builds: Usually faster

## Step 7: Manage Testing

### 7.1 Invite Testers

Via email:
```
Subject: Invitation to Test Chinese Chess

You're invited to test Chinese Chess (Xiangqi) on TestFlight!

1. Download TestFlight from the App Store
2. Open this link on your iOS device: [TestFlight Link]
3. Tap "Accept" to join the beta
4. Start playing and provide feedback!

What to Test:
- Matchmaking and game creation
- Piece movement and rules
- Timer functionality
- Connection stability

Report issues via TestFlight or email: support@example.com
```

### 7.2 Collect Feedback

Testers can provide feedback via:
- TestFlight app feedback form
- Screenshots with annotations
- Crash reports (automatic)

### 7.3 Monitor Metrics

In App Store Connect:
- Installations per day
- Crashes and issues
- Tester engagement
- Device distribution

## Step 8: Iterate and Update

### 8.1 Submit New Builds

For each update:
1. Increment build number
2. Archive and upload
3. Add to test groups
4. Internal builds: Immediately available
5. External builds: Re-review if significant changes

### 8.2 Manage Builds

- Expire old builds after sufficient testing
- Keep track of changes between builds
- Maintain release notes

## Troubleshooting

### Common Issues

**Upload Failed**
- Check signing certificates are valid
- Verify provisioning profile includes App Store distribution
- Ensure bundle ID matches

**Build Processing Failed**
- Check for missing required icons
- Verify Info.plist is complete
- Check for invalid binary architectures

**Beta Review Rejected**
- Fix reported issues
- Resubmit with explanation
- Contact App Review if unclear

### Getting Help

- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [Apple Developer Forums](https://developer.apple.com/forums/)

## Automation with Fastlane (Optional)

### Setup Fastlane

```bash
cd ios/ChineseChess
fastlane init
```

### Fastfile Example

```ruby
default_platform(:ios)

platform :ios do
  desc "Push a new beta build to TestFlight"
  lane :beta do
    # Increment build number
    increment_build_number

    # Build the app
    build_app(
      scheme: "ChineseChess",
      export_method: "app-store"
    )

    # Upload to TestFlight
    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )

    # Clean up
    clean_build_artifacts
  end
end
```

### Run Deployment

```bash
fastlane beta
```

## Checklist

Before each TestFlight submission:

- [ ] All tests pass (`xcodebuild test`)
- [ ] No compiler warnings
- [ ] Version number updated
- [ ] Build number incremented
- [ ] App icons complete
- [ ] Privacy policy URL set
- [ ] Backend server deployed and accessible
- [ ] Test on physical devices
- [ ] Test on multiple iOS versions
- [ ] Archive validated successfully
- [ ] Release notes prepared
