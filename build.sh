#!/bin/sh
# Xcode 없이 CLT의 swiftc만으로 Universal .app 생성. 결과: build/UsagiPet.app
set -e
cd "$(dirname "$0")"
APP=build/UsagiPet.app
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
SRC=$(find Sources -name '*.swift')
for arch in arm64 x86_64; do
  swiftc -O -target $arch-apple-macos13.0 $SRC -o build/UsagiPet-$arch
done
lipo -create build/UsagiPet-* -output "$APP/Contents/MacOS/UsagiPet"
rm build/UsagiPet-*
cp Resources/Info.plist "$APP/Contents/"
cp Resources/bridge.js Resources/fonts/*.ttf "$APP/Contents/Resources/"
cp Resources/me.png "$APP/Contents/Resources/" 2>/dev/null || true   # 선택: 내 말풍선 아바타
cp Resources/usagi.png Resources/usagi.gif "$APP/Contents/Resources/" 2>/dev/null || true
ls Resources/usagi.* >/dev/null 2>&1 || echo "usagi.png 없음 -> 임시 도형으로 표시됨"
codesign --force --sign - "$APP"  # ad-hoc 서명
echo "완료: $APP"
