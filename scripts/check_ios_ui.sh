#!/bin/bash
set -euo pipefail
mkdir -p output/screenshots
runtime=$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; rows=[r for r in json.load(sys.stdin)["runtimes"] if r.get("isAvailable") and "iOS" in r["name"]]; print(sorted(rows,key=lambda r:tuple(int(p) for p in r["version"].split(".")))[-1]["identifier"])')
device=$(xcrun simctl create Spielraum-Readability com.apple.CoreSimulator.SimDeviceType.iPhone-12 "$runtime")
trap 'xcrun simctl shutdown "$device" >/dev/null 2>&1 || true; xcrun simctl delete "$device" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
xcrun simctl status_bar "$device" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
xcodebuild -project MeinSpielraum.xcodeproj -scheme MeinSpielraum -configuration Debug \
    -destination "platform=iOS Simulator,id=$device" -derivedDataPath build-ui \
    -resultBundlePath output/UI-Tests.xcresult CODE_SIGNING_ALLOWED=NO \
    -parallel-testing-enabled NO test
xcrun xcresulttool export attachments --path output/UI-Tests.xcresult --output-path output/screenshots
(cd output/screenshots && /usr/bin/zip -qry ../UI-Screenshots.zip .)
