#!/bin/bash

if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <STOCK_DEVICE> <USE_UI_8_TETHERING_APEX> <TARGET_DEVICE> <OUTPUT_FILESYSTEM>"
    exit 1
fi

VERSION="1"

# Device info
export STOCK_DEVICE="$1"
export USE_UI_8_TETHERING_APEX="$2"
export TARGET_DEVICE="$3"
export OUTPUT_FILESYSTEM="$4"

# Directories
export FIRM_DIR="$(pwd)/FW"
export OUT_DIR="$(pwd)/OUT"
export WORK_DIR="$(pwd)/WORK"
export APKTOOL="$(pwd)/bin/java/apktool.jar"
export DEVICES_DIR="$(pwd)/QuantumROM/Devices"
export VNDKS_COLLECTION="$(pwd)/QuantumROM/vndks"
export BUILD_PARTITIONS="product,system_ext,system"

if [ "$STOCK_DEVICE" != "None" ]; then
    if curl -fsSL \
        "https://api.github.com/repos/SN-Abdullah-Al-Noman/QuantumROM/releases/tags/QuantumROM_Devices" |
        jq -e --arg dev "${STOCK_DEVICE}.zip" '.assets[].name == $dev' |
        grep -q true; then
        echo "$STOCK_DEVICE is supported"
    else
        echo "❌ $STOCK_DEVICE is not supported by this tool."
    fi
fi

if [ -f "${DEVICES_DIR}/${STOCK_DEVICE}.zip" ]; then
    rm -rf "${DEVICES_DIR}/${STOCK_DEVICE}"
    mkdir "${DEVICES_DIR}/${STOCK_DEVICE}"
    unzip -oq "${DEVICES_DIR}/${STOCK_DEVICE}.zip" -d "${DEVICES_DIR}/${STOCK_DEVICE}"
fi

# Source
source "$(pwd)/scripts/debloat.sh"
source "$(pwd)/scripts/QuantumRom.sh"

# Auto-detect CSC from extracted firmware
TARGET_DEVICE_CSC=""
if [ -d "$FIRM_DIR/$TARGET_DEVICE" ]; then
    # Try to find CSC from OMC folder
    if [ -d "$FIRM_DIR/$TARGET_DEVICE/omc" ]; then
        TARGET_DEVICE_CSC=$(ls "$FIRM_DIR/$TARGET_DEVICE/omc" | grep -E '^[A-Z]{3}$' | head -n 1)
    elif [ -d "$FIRM_DIR/$TARGET_DEVICE/system/omc" ]; then
        TARGET_DEVICE_CSC=$(ls "$FIRM_DIR/$TARGET_DEVICE/system/omc" | grep -E '^[A-Z]{3}$' | head -n 1)
    elif [ -f "$FIRM_DIR/$TARGET_DEVICE/system/build.prop" ]; then
        TARGET_DEVICE_CSC=$(grep 'ro.csc.country_code=' "$FIRM_DIR/$TARGET_DEVICE/system/build.prop" | cut -d= -f2 | tr -d '\r')
    fi
fi

if [ -z "$TARGET_DEVICE_CSC" ]; then
    echo "⚠️  Warning: Could not auto-detect CSC, using default 'BKD'"
    TARGET_DEVICE_CSC="BKD"
fi

echo "📱 Target Device: $TARGET_DEVICE"
echo "🌍 Detected CSC: $TARGET_DEVICE_CSC"
echo "📦 Output Filesystem: $OUTPUT_FILESYSTEM"

EXTRACT_FIRMWARE "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all"

DECODE_OMC "$FIRM_DIR/$TARGET_DEVICE" "$WORK_DIR"
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"

APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"
PATCH_SELINUX "$FIRM_DIR/$TARGET_DEVICE"
DISABLE_SECURITY "$FIRM_DIR/$TARGET_DEVICE"
ADD_SAMSUNG_FLAGSHIP_APPS "$FIRM_DIR/$TARGET_DEVICE"
APPLY_CUSTOM_FEATURES "$FIRM_DIR/$TARGET_DEVICE"

INSTALL_FRAMEWORK "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/framework-res.apk"

DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/ssrm.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/services.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/samsungkeystoreutils.jar" "$WORK_DIR"

PATCH_SSRM "$WORK_DIR/ssrm"
PATCH_FLAG_SECURE "$WORK_DIR/services"
PATCH_SECURE_FOLDER "$WORK_DIR/services"
PATCH_PRIVATE_SHARE "$WORK_DIR/samsungkeystoreutils"

RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/ssrm" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/services" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/samsungkeystoreutils" "$WORK_DIR"
mv -f "$WORK_DIR"/*.jar "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/"

PATCH_BT_LIB "$FIRM_DIR/$TARGET_DEVICE" "$WORK_DIR"

B_ID="$(grep -m1 '^ro.system.build.id=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"
B_V="$(grep -m1 '^ro.system.build.version.incremental=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "${B_ID} ${B_V} V-${VERSION}: Built with Errormodz"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.build.display.id" "${B_ID} ${B_V} V-${VERSION}: Built with Errormodz"

BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
