#!/bin/bash

# World Cup 2026 Menubar - Build and Notarize Script
# Builds a release version of the app, creates a DMG, and optionally notarizes it.

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_PROJECT="${PROJECT_DIR}/WorldCup2026Menubar.xcodeproj"
SCHEME="WorldCup2026Menubar"
CONFIGURATION="Release"
ARCHIVE_PATH="${PROJECT_DIR}/build/WorldCup2026Menubar.xcarchive"
EXPORT_PATH="${PROJECT_DIR}/build/export"
APP_NAME="WorldCup2026Menubar.app"
DISPLAY_NAME="World Cup 2026 Menubar"
BUNDLE_ID="org.dev7studios.WorldCup2026Menubar"
TEAM_ID="${TEAM_ID:-KM46CDPN8K}"
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool-profile}"

# Apple ID for notarization (set via environment or edit below)
APPLE_ID="${APPLE_ID:-drummermanny@gmail.com}"

# Auto-detect Developer ID certificate when not provided
if [ -z "${DEVELOPER_ID:-}" ]; then
    DEVELOPER_ID=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep "Developer ID Application.*(${TEAM_ID})" \
        | head -1 \
        | sed -n 's/.*"\([^"]*\)".*/\1/p')
fi

if [ -z "${DEVELOPER_ID:-}" ]; then
    echo -e "${RED}Error:${NC} No Developer ID Application certificate found for team ${TEAM_ID}."
    echo "Install the certificate in Keychain Access, or set DEVELOPER_ID explicitly:"
    echo '  export DEVELOPER_ID="Developer ID Application: Your Name (KM46CDPN8K)"'
    exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   World Cup 2026 Menubar - Release Build   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Team ID:       ${TEAM_ID}"
echo -e "Bundle ID:     ${BUNDLE_ID}"
echo -e "Signing with:  ${DEVELOPER_ID}"
echo ""

# Step 1: Clean previous builds
echo -e "${YELLOW}[1/6]${NC} Cleaning previous builds..."
rm -rf "${PROJECT_DIR}/build"
mkdir -p "${PROJECT_DIR}/build"
mkdir -p "${EXPORT_PATH}"

# Step 2: Build Archive
echo -e "${YELLOW}[2/6]${NC} Building archive..."

ARCHIVE_ARGS=(
    -project "${XCODE_PROJECT}"
    -scheme "${SCHEME}"
    -configuration "${CONFIGURATION}"
    -archivePath "${ARCHIVE_PATH}"
    -destination "platform=macOS,arch=arm64"
    CODE_SIGN_IDENTITY="${DEVELOPER_ID}"
    CODE_SIGN_STYLE=Manual
    DEVELOPMENT_TEAM="${TEAM_ID}"
    PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}"
)

if command -v xcpretty &> /dev/null; then
    xcodebuild archive "${ARCHIVE_ARGS[@]}" | xcpretty
else
    xcodebuild archive "${ARCHIVE_ARGS[@]}"
fi

echo -e "${GREEN}✓${NC} Archive created successfully"

# Step 3: Export Archive
echo -e "${YELLOW}[3/6]${NC} Exporting archive..."

cat > "${PROJECT_DIR}/build/exportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${PROJECT_DIR}/build/exportOptions.plist"

echo -e "${GREEN}✓${NC} Export completed successfully"

# Get version from the built app
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "${EXPORT_PATH}/${APP_NAME}/Contents/Info.plist" 2>/dev/null || echo "1.0")

echo -e "${GREEN}✓${NC} Detected version: ${VERSION}"

# Step 4: Create DMG with Applications symlink
echo -e "${YELLOW}[4/6]${NC} Creating DMG..."

DMG_TEMP="${PROJECT_DIR}/build/dmg_temp"
mkdir -p "${DMG_TEMP}"

cp -R "${EXPORT_PATH}/${APP_NAME}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

DMG_NAME="${DISPLAY_NAME} ${VERSION}.dmg"
DMG_PATH="${PROJECT_DIR}/build/${DMG_NAME}"

rm -f "${DMG_PATH}"

hdiutil create -volname "${DISPLAY_NAME} ${VERSION}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDZO \
    "${DMG_PATH}"

rm -rf "${DMG_TEMP}"

echo -e "${GREEN}✓${NC} DMG created: ${DMG_PATH}"

# Step 5: Notarize
echo -e "${YELLOW}[5/6]${NC} Submitting for notarization..."
echo -e "${YELLOW}Note:${NC} Store notarization credentials in the keychain first:"
echo -e "${YELLOW}      xcrun notarytool store-credentials \"${NOTARY_PROFILE}\" --apple-id ${APPLE_ID} --team-id ${TEAM_ID}${NC}"
echo ""

read -p "Do you want to submit for notarization now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    NOTARIZE_RESPONSE=$(xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${NOTARY_PROFILE}" \
        --wait)

    echo "$NOTARIZE_RESPONSE"

    if echo "$NOTARIZE_RESPONSE" | grep -q "status: Accepted"; then
        echo -e "${GREEN}✓${NC} Notarization successful!"

        # Step 6: Staple
        echo -e "${YELLOW}[6/6]${NC} Stapling notarization ticket..."
        xcrun stapler staple "${DMG_PATH}"
        echo -e "${GREEN}✓${NC} Notarization ticket stapled!"
    else
        echo -e "${RED}✗${NC} Notarization failed. Check the output above for details."
        exit 1
    fi
else
    echo -e "${YELLOW}⚠${NC}  Skipping notarization. You can notarize later with:"
    echo -e "    xcrun notarytool submit \"${DMG_PATH}\" --keychain-profile \"${NOTARY_PROFILE}\" --wait"
    echo -e "    xcrun stapler staple \"${DMG_PATH}\""
fi

# Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Build Complete!                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Version:       ${VERSION}"
echo -e "App Location:  ${EXPORT_PATH}/${APP_NAME}"
echo -e "DMG Location:  ${DMG_PATH}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo -e "1. Test the app: open \"${EXPORT_PATH}/${APP_NAME}\""
echo -e "2. If notarization was skipped, run the notarization commands above"
echo -e "3. Upload DMG to GitHub Releases"
echo ""
