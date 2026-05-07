# MousePhone

MousePhone turns an iPhone into a companion touchpad for a Mac. The iPhone app sends pointer, click, scroll, and volume commands to the Mac app over nearby peer networking. The Mac app performs the actual cursor and volume changes locally.

## Workspace Layout

- `Sources/MousePhoneShared`: shared protocol and transport interfaces.
- `Apps/MousePhoneMac`: macOS SwiftUI receiver app source.
- `Apps/MousePhoneiOS`: iOS SwiftUI controller app source.
- `Tests/MousePhoneSharedTests`: protocol round-trip tests.

## Current Implementation

Open `MousePhone.xcodeproj` in Xcode. It contains two native app schemes:

- `MousePhoneMac`: macOS receiver/menu-bar app.
- `MousePhoneiOS`: iPhone controller app.

The app targets compile the shared source files directly for a simple v1 setup. `Package.swift` also exposes `MousePhoneShared` as a standalone Swift package with tests.

Before installing on your iPhone, select your Apple development team for the iOS target and let Xcode update signing. Both app targets already include local network Bonjour declarations for `_mousephone._tcp` and `_mousephone._udp`.

## Run

1. Build and run `MousePhoneMac` on the Mac.
2. Click the permission button and grant Accessibility access in System Settings.
3. Build and run `MousePhoneiOS` on a real iPhone.
4. Keep the iPhone app open while using it as a touchpad.

## Verify From Terminal

```sh
swift test
xcodebuild -project MousePhone.xcodeproj -scheme MousePhoneMac -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MousePhone.xcodeproj -scheme MousePhoneiOS -configuration Debug -destination generic/platform=iOS -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build
```
# iOS (build, install, launch)
set -euo pipefail
DERIVED_DATA="/tmp/MousePhoneDerived"
UDID="00008020-000845E90E06002E"
SCHEME="MousePhoneiOS"
PROJECT="MousePhone.xcodeproj"
rm -rf "$DERIVED_DATA"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "id=$UDID" -configuration Debug -derivedDataPath "$DERIVED_DATA" -allowProvisioningUpdates build
APP_PATH=$(find "$DERIVED_DATA" -type d -name "${SCHEME}.app" | head -n 1)
if [[ -z "$APP_PATH" ]]; then
  echo "Could not find built app bundle in $DERIVED_DATA" >&2
  exit 1
fi
xcrun devicectl device install app --device "$UDID" "$APP_PATH"
xcrun devicectl device process launch --device "$UDID" com.seif.mousephone.ios


# macOS (build, launch)
set -euo pipefail
DERIVED_DATA="/tmp/MousePhoneDerivedMac"
SCHEME="MousePhoneMac"
PROJECT="MousePhone.xcodeproj"
rm -rf "$DERIVED_DATA"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -derivedDataPath "$DERIVED_DATA" build
APP_PATH=$(find "$DERIVED_DATA" -type d -name "${SCHEME}.app" | head -n 1)
if [[ -z "$APP_PATH" ]]; then
  echo "Could not find built app bundle in $DERIVED_DATA" >&2
  exit 1
fi
open "$APP_PATH"