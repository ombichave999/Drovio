#!/bin/bash
set -e
VERSION=$(xcodebuild -showBuildSettings | grep -w MARKETING_VERSION | head -n 1 | tr -d " " | cut -d"=" -f2)
echo "Building Main version $VERSION"
xcodebuild -scheme Drovio -archivePath Drovio.xcarchive archive
rm -f releases/Drovio_${VERSION}.dmg
appdmg appdmg.json releases/Drovio_${VERSION}.dmg
./Sparkle-Tools/bin/sign_update releases/Drovio_${VERSION}.dmg

