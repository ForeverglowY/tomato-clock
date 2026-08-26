#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/dist/TomatoClock.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
swift build -c release

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$project_dir/.build/release/TomatoClock" "$contents_dir/MacOS/TomatoClock"
cp "$project_dir/App/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Assets/AppIcon.icns" "$contents_dir/Resources/AppIcon.icns"
chmod 755 "$contents_dir/MacOS/TomatoClock"

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
