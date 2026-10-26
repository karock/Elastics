#!/bin/bash
#
# Builds a signed Release of Elastics. With a Developer ID Application certificate
# (see scripts/configure-signing.sh), also notarizes it with Apple, staples the
# ticket and writes build/dist/Elastics-<version>.zip, ready to share.
#
# One-time setup for notarization (an app-specific password from appleid.apple.com):
#   xcrun notarytool store-credentials elastics-notary \
#     --apple-id you@example.com --team-id YOURTEAMID --password <app-specific-password>
# Use another profile name with: NOTARY_PROFILE=name scripts/release.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE="${NOTARY_PROFILE:-elastics-notary}"
APP=build/Release/Elastics.app

# clean separately: it removes build/, which would take the build log with it
xcodebuild -project Elastics.xcodeproj -target Elastics -configuration Release \
	SYMROOT="$PWD/build" OBJROOT="$PWD/build/obj" clean > /dev/null 2>&1 || true

mkdir -p build
echo "Building (log: build/xcodebuild.log)..."
if ! xcodebuild -project Elastics.xcodeproj -target Elastics -configuration Release \
		SYMROOT="$PWD/build" OBJROOT="$PWD/build/obj" build > build/xcodebuild.log 2>&1; then
	grep -E 'error:' build/xcodebuild.log | head -20 || tail -30 build/xcodebuild.log
	echo "Build failed." >&2
	exit 1
fi

echo "Checking signature..."
codesign --verify --deep --strict "$APP"
lipo -info "$APP/Contents/MacOS/Elastics"
authority=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -n 1)
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")

case "$authority" in
	"Developer ID Application:"*)
		echo "Signed by $authority" ;;
	"")
		echo "Built $APP with the local (ad-hoc) signature: it runs on this Mac only."
		echo "Run scripts/configure-signing.sh to sign with your certificate."
		exit 0 ;;
	*)
		echo "Built $APP, signed by $authority."
		echo "Only Developer ID certificates can be notarized, so this build is for your own Macs."
		exit 0 ;;
esac

mkdir -p build/dist
zip="build/dist/Elastics-$version.zip"
rm -f "$zip"
ditto -c -k --keepParent "$APP" "$zip"

echo "Submitting to Apple for notarization (usually a few minutes)..."
if ! result=$(xcrun notarytool submit "$zip" --keychain-profile "$PROFILE" --wait 2>&1); then
	echo "$result"
	echo "Could not submit. Did you run the one-time notarytool store-credentials step (see this script's header)?" >&2
	exit 1
fi
echo "$result"
if ! printf '%s\n' "$result" | grep -q 'status: Accepted'; then
	id=$(printf '%s\n' "$result" | sed -n 's/^ *id: //p' | head -n 1)
	echo "Notarization was not accepted. Details: xcrun notarytool log $id --keychain-profile $PROFILE" >&2
	exit 1
fi

echo "Stapling..."
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose=2 "$APP"

# re-zip so the download contains the stapled ticket
rm -f "$zip"
ditto -c -k --keepParent "$APP" "$zip"
echo "Ready to distribute: $zip"
