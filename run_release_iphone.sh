#!/bin/bash

# Script to run Flutter app in release mode on Jake's iPhone
echo "Building and running Moon Coaching app in release mode on iPhone..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Navigate to client_app directory
cd "$SCRIPT_DIR/client_app"

# Run flutter with release mode, prod flavor, and specific device ID
flutter run --release --flavor prod -d 00008130-0012492814C0001C

echo "App launched successfully!"
