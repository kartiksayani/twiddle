#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 -Xswiftc -warnings-as-errors
bin_dir=$(swift build -c release --arch arm64 --show-bin-path)
app=.build/Twiddle.app
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/Twiddle" "$app/Contents/MacOS/Twiddle"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Twiddle</string>
  <key>CFBundleIdentifier</key><string>com.kartiksayani.twiddle</string>
  <key>CFBundleName</key><string>Twiddle</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.2.0</string>
  <key>CFBundleVersion</key><string>2</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>com.kartiksayani.twiddle</string>
      <key>CFBundleURLSchemes</key><array><string>twiddle</string></array>
    </dict>
  </array>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$app"
echo "Built $app"
