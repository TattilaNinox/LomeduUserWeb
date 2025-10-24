#!/bin/bash
# Automatikus deployment script Linux/Mac-re
# Használat: ./deploy.sh

set -e  # Exit on error

echo ""
echo "========================================"
echo "  Lomedu Web App - Deployment Script"
echo "========================================"
echo ""

# Verzió frissítés
echo "[1/4] Updating version.json..."
dart tools/update_version.dart
echo "✅ Version updated successfully"
echo ""

# Build
echo "[2/4] Building web app..."
flutter build web --release
echo "✅ Build completed successfully"
echo ""

# Version.json ellenőrzés
echo "[3/4] Verifying version.json in build..."
if [ -f "build/web/version.json" ]; then
    echo "✅ version.json found in build/web"
else
    echo "⚠️  Warning: version.json not found, copying..."
    cp web/version.json build/web/version.json
fi
echo ""

# Firebase deploy
echo "[4/4] Deploying to Firebase Hosting..."
firebase deploy --only hosting
echo ""

echo "========================================"
echo "  ✅ Deployment completed successfully!"
echo "========================================"
echo ""

