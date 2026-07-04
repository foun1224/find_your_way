#!/bin/bash
# 組出 FindYourWay.app bundle（照 06_PHASE1_SPEC.md §3 build_app.sh，
# Phase 5 擴充：icon 佔位 / codesign（SIGN_MODE）/ Info.plist 版本與圖示欄位，見 `10_PHASE5_SPEC.md` §5–6）。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="FindYourWay"
BUNDLE_ID="com.findyourway.app"
BUILD_CONFIG="release"
APP_VERSION="0.5.0"     # Phase 5（`10` §5.2：版本語意對齊 Phase）
BUILD_NUMBER="5"        # 遞增 build 號

# 簽章模式（`10` §6.3）：adhoc（預設，個人自用不公證）| devid（Developer ID，預留分發用）。
SIGN_MODE="${SIGN_MODE:-adhoc}"

echo "==> swift build -c ${BUILD_CONFIG}"
swift build -c "${BUILD_CONFIG}"

BIN_PATH="$(swift build -c "${BUILD_CONFIG}" --show-bin-path)"
EXECUTABLE_PATH="${BIN_PATH}/${APP_NAME}"

if [ ! -f "${EXECUTABLE_PATH}" ]; then
    echo "error: executable not found at ${EXECUTABLE_PATH}" >&2
    exit 1
fi

APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> assembling ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_NAME}"

# ---- icon（佔位，`10` §5.3；正式美術留 Phase 4）----
ICON_FILE="AppIcon.icns"
ICON_PATH="${ROOT_DIR}/Resources/${ICON_FILE}"

if [ ! -f "${ICON_PATH}" ]; then
    echo "==> no placeholder icon found, generating one (陶紅 #C56A4E 方塊)"
    mkdir -p "${ROOT_DIR}/Resources"
    ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"
    BASE_PNG="$(mktemp -t appicon).png"
    python3 "${ROOT_DIR}/scripts/make_placeholder_icon.py" "${BASE_PNG}" 1024

    for sz in 16 32 128 256 512; do
        sips -z "${sz}" "${sz}" "${BASE_PNG}" --out "${ICONSET_DIR}/icon_${sz}x${sz}.png" >/dev/null
        sz2=$((sz * 2))
        sips -z "${sz2}" "${sz2}" "${BASE_PNG}" --out "${ICONSET_DIR}/icon_${sz}x${sz}@2x.png" >/dev/null
    done
    cp "${BASE_PNG}" "${ICONSET_DIR}/icon_512x512@2x.png"

    iconutil -c icns "${ICONSET_DIR}" -o "${ICON_PATH}"
    rm -rf "$(dirname "${ICONSET_DIR}")" "${BASE_PNG}"
fi

cp "${ICON_PATH}" "${RESOURCES_DIR}/${ICON_FILE}"

# ---- 像素美術（Phase 4a，`12` §1/§2；由 scripts/slice_assets.py 重生，非版控）----
ART_DIR="${ROOT_DIR}/Resources/art"
if [ -d "${ART_DIR}" ]; then
    echo "==> copying art (${ART_DIR}) into bundle"
    cp -R "${ART_DIR}" "${RESOURCES_DIR}/art"
else
    echo "==> warning: ${ART_DIR} not found — run 'python3 scripts/slice_assets.py' first (app will fall back to placeholder art)" >&2
fi

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>${ICON_FILE}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# ---- 簽章（`10` §6）----
case "${SIGN_MODE}" in
    adhoc)
        echo "==> codesign (ad-hoc, 不公證 —— ADR-008 更新：個人自用)"
        codesign --force -s - --deep "${APP_BUNDLE}"
        ;;
    devid)
        # [待 Phase 5 驗證] 預留分支：使用者有 Apple Developer 帳號時，
        # 改用本地 Developer ID Application 憑證簽章（仍不公證，自用）。
        # 用法：DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" SIGN_MODE=devid bash scripts/build_app.sh
        if [ -z "${DEVELOPER_ID:-}" ]; then
            echo "error: SIGN_MODE=devid 需設定 DEVELOPER_ID 環境變數（憑證名稱）" >&2
            exit 1
        fi
        echo "==> codesign (Developer ID: ${DEVELOPER_ID})"
        codesign --force -s "${DEVELOPER_ID}" --options runtime --deep "${APP_BUNDLE}"
        echo "TODO: notarize + staple（分發時才需要，Phase5 spec §6.1 路線 (b)）"
        ;;
    *)
        echo "error: unknown SIGN_MODE=${SIGN_MODE} (expected adhoc|devid)" >&2
        exit 1
        ;;
esac

echo "==> done: ${APP_BUNDLE}"
echo "==> 提示：請將 ${APP_NAME}.app 移至 /Applications 後再啟用開機自啟（SMAppService 對安裝位置敏感，Phase5 spec §2.3/§5.4）"
