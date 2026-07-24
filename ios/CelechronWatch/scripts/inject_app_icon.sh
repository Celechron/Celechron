#!/bin/bash
# When actool cannot compile AppIcon (SDK/runtime mismatch), copy PNGs into the
# product and ensure Info.plist declares CFBundleIconName / CFBundleIcons.
set -euo pipefail

APP="${TARGET_BUILD_DIR:-}/${FULL_PRODUCT_NAME:-}"
if [[ -z "${APP}" || ! -d "${APP}" ]]; then
  APP="${TARGET_BUILD_DIR:-}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}"
fi
if [[ -z "${APP}" || ! -d "${APP}" ]]; then
  echo "inject_app_icon: app bundle not found (TARGET_BUILD_DIR=${TARGET_BUILD_DIR:-} FULL_PRODUCT_NAME=${FULL_PRODUCT_NAME:-})"
  exit 0
fi

ICONSET="${SRCROOT}/CelechronWatch/Assets.xcassets/AppIcon.appiconset"
if [[ ! -d "${ICONSET}" ]]; then
  echo "inject_app_icon: iconset missing at ${ICONSET}"
  exit 0
fi

# Primary marketing / fallback
if [[ -f "${ICONSET}/AppIcon.png" ]]; then
  cp -f "${ICONSET}/AppIcon.png" "${APP}/AppIcon.png"
  cp -f "${ICONSET}/AppIcon.png" "${APP}/AppIcon@2x.png"
fi

# Classic watchOS icon filenames (points@2x)
# role/size mapping → pixel file we generated
copy_icon() {
  local src="$1"
  local dest="$2"
  if [[ -f "${ICONSET}/${src}" ]]; then
    cp -f "${ICONSET}/${src}" "${APP}/${dest}"
  fi
}

copy_icon "AppIcon-48.png" "AppIcon24x24@2x.png"
copy_icon "AppIcon-55.png" "AppIcon27.5x27.5@2x.png"
copy_icon "AppIcon-58.png" "AppIcon29x29@2x.png"
copy_icon "AppIcon-87.png" "AppIcon29x29@3x.png"
copy_icon "AppIcon-80.png" "AppIcon40x40@2x.png"
copy_icon "AppIcon-88.png" "AppIcon44x44@2x.png"
copy_icon "AppIcon-92.png" "AppIcon46x46@2x.png"
copy_icon "AppIcon-100.png" "AppIcon50x50@2x.png"
copy_icon "AppIcon-102.png" "AppIcon51x51@2x.png"
copy_icon "AppIcon-108.png" "AppIcon54x54@2x.png"
copy_icon "AppIcon-172.png" "AppIcon86x86@2x.png"
copy_icon "AppIcon-196.png" "AppIcon98x98@2x.png"
copy_icon "AppIcon-216.png" "AppIcon108x108@2x.png"
copy_icon "AppIcon-234.png" "AppIcon117x117@2x.png"
copy_icon "AppIcon-258.png" "AppIcon129x129@2x.png"
copy_icon "AppIcon-1024.png" "AppIcon1024x1024.png"

# Also keep numeric copies
for f in "${ICONSET}"/AppIcon-*.png; do
  [[ -f "$f" ]] || continue
  cp -f "$f" "${APP}/$(basename "$f")"
done

PLIST="${APP}/Info.plist"
if [[ -f "${PLIST}" ]]; then
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "${PLIST}" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "${PLIST}" 2>/dev/null || true

  /usr/libexec/PlistBuddy -c "Delete :CFBundleIcons" "${PLIST}" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIcons dict" "${PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon dict" "${PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName string AppIcon" "${PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles array" "${PLIST}"
  i=0
  for name in AppIcon AppIcon40x40 AppIcon44x44 AppIcon46x46 AppIcon50x50 AppIcon54x54 AppIcon86x86 AppIcon98x98 AppIcon108x108; do
    /usr/libexec/PlistBuddy -c "Add :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:${i} string ${name}" "${PLIST}" 2>/dev/null || true
    i=$((i + 1))
  done
fi

echo "inject_app_icon: injected into ${APP}"
ls -1 "${APP}"/AppIcon*.png 2>/dev/null | wc -l | xargs echo "icon files:"
