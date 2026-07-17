#!/bin/bash
set -e

trap 'echo "=> Restoring Info.plist..."; plutil -replace SUFeedURL -string "https://releases-silk.vercel.app/appcast.xml" Drovio/Info.plist' EXIT

echo "=> Fetching current version..."
VERSION=$(xcodebuild -showBuildSettings | grep -w MARKETING_VERSION | head -n 1 | tr -d ' ' | cut -d'=' -f2)
echo "Building Beta version $VERSION"

echo "=> Modifying Info.plist to point to appcast-beta.xml..."
plutil -replace SUFeedURL -string "https://releases-silk.vercel.app/appcast-beta.xml" Drovio/Info.plist

echo "=> Archiving app..."
xcodebuild -scheme Drovio -archivePath Drovio.xcarchive archive

echo "=> Generating TestDrovio DMG..."
rm -f releases/TestDrovio_${VERSION}.dmg
appdmg appdmg-beta.json releases/TestDrovio_${VERSION}.dmg

echo "=> Signing DMG with Sparkle..."
./Sparkle-Tools/bin/sign_update releases/TestDrovio_${VERSION}.dmg

echo "=> Done! You can now manually update releases/appcast-beta.xml and deploy to Vercel."
