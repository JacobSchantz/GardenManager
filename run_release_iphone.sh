#!/bin/bash

# Script to run GardenManager app in release mode on Jake's iPhone
echo "Building and running GardenManager app in release mode on iPhone..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_ID="00008130-0012492814C0001C"
DERIVED_DATA="$SCRIPT_DIR/build/DerivedData"

echo "Effective build setting (Release):"
xcodebuild -project "$SCRIPT_DIR/GardenManager.xcodeproj" \
    -scheme GardenManager \
    -configuration Release \
    -showBuildSettings 2>/dev/null | grep -E "\bIPHONEOS_DEPLOYMENT_TARGET\b" | head -1

# Build for device with xcodebuild
xcodebuild -project "$SCRIPT_DIR/GardenManager.xcodeproj" \
    -scheme GardenManager \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -allowProvisioningUpdates \
    IPHONEOS_DEPLOYMENT_TARGET=26.0 \
    build

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo "Build succeeded. Installing to device..."

# Find the built app
APP_PATH="$DERIVED_DATA/Build/Products/Release-iphoneos/GardenManager.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Install the app on device
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

if [ $? -ne 0 ]; then
    echo "Install failed!"
    exit 1
fi

echo "App installed. Launching..."

# Launch the app
xcrun devicectl device process launch --device "$DEVICE_ID" com.gardenmanager.application

echo "App launched successfully!"
