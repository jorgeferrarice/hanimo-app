#!/bin/bash

# Hanimo iOS Build and Submit Script
# This script builds the Flutter app, exports the IPA, and submits to App Store Connect

set -e  # Exit on any error

echo "🚀 Starting Hanimo iOS build and submission process..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Clean and prepare
echo -e "${BLUE}📱 Step 1: Cleaning Flutter project...${NC}"
flutter clean
flutter pub get

# Step 2: Build iOS archive
echo -e "${BLUE}🔨 Step 2: Building iOS archive...${NC}"
flutter build ios --release

# Step 3: Archive with Xcode
echo -e "${BLUE}📦 Step 3: Creating Xcode archive...${NC}"
cd ios
xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -archivePath ../build/ios/archive/Runner.xcarchive \
    -allowProvisioningUpdates \
    archive
cd ..

# Step 4: Export IPA
echo -e "${BLUE}📤 Step 4: Exporting IPA with provisioning profile...${NC}"
xcodebuild -exportArchive \
    -archivePath build/ios/archive/Runner.xcarchive \
    -exportOptionsPlist ios/ExportOptions.plist \
    -exportPath build/ios/ipa \
    -allowProvisioningUpdates

# Find the IPA file
IPA_PATH=$(find build/ios/ipa -name "*.ipa" | head -1)

if [ ! -f "$IPA_PATH" ]; then
    echo -e "${RED}❌ Error: IPA file not found in build/ios/ipa/${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IPA file successfully created!${NC}"
echo -e "${YELLOW}📋 IPA Location: $IPA_PATH${NC}"
echo ""

# Step 5: Interactive prompt for next action
echo -e "${BLUE}🤔 What would you like to do next?${NC}"
echo "1. Open IPA file location"
echo "2. Submit to App Store Connect"
echo ""
read -p "Please select an option (1 or 2): " choice

case $choice in
    1)
        echo -e "${GREEN}📂 Opening IPA file location...${NC}"
        open "$(dirname "$IPA_PATH")"
        echo -e "${GREEN}✅ Build process completed! IPA file location opened.${NC}"
        ;;
    2)
        echo -e "${BLUE}☁️  Preparing to submit to App Store Connect...${NC}"
        echo ""
        
        # Default credentials
        DEFAULT_APPLE_ID="jorgeferrarice@gmail.com"
        DEFAULT_APP_PASSWORD="lqko-kqtu-ylsx-surl"
        
        echo -e "${YELLOW}🔐 Apple ID Configuration${NC}"
        echo "1. Use default Apple ID ($DEFAULT_APPLE_ID)"
        echo "2. Enter custom Apple ID and app password"
        echo ""
        read -p "Please select an option (1 or 2): " cred_choice
        
        case $cred_choice in
            1)
                APPLE_ID="$DEFAULT_APPLE_ID"
                APP_PASSWORD="$DEFAULT_APP_PASSWORD"
                echo -e "${GREEN}✅ Using default Apple ID: $APPLE_ID${NC}"
                ;;
            2)
                echo ""
                read -p "Enter your Apple ID email: " APPLE_ID
                echo ""
                read -s -p "Enter your app-specific password: " APP_PASSWORD
                echo ""
                echo -e "${GREEN}✅ Custom credentials configured${NC}"
                ;;
            *)
                echo -e "${RED}❌ Invalid option selected. Using default credentials.${NC}"
                APPLE_ID="$DEFAULT_APPLE_ID"
                APP_PASSWORD="$DEFAULT_APP_PASSWORD"
                ;;
        esac
        
        echo ""
        echo -e "${BLUE}📤 Submitting to App Store Connect...${NC}"
        echo -e "${YELLOW}Using Apple ID: $APPLE_ID${NC}"
        
        # Submit using xcrun altool
        xcrun altool --upload-app \
            --type ios \
            --file "$IPA_PATH" \
            --username "$APPLE_ID" \
            --password "$APP_PASSWORD" \
            --verbose
        
        echo ""
        echo -e "${GREEN}✅ Build and submission process completed!${NC}"
        echo -e "${GREEN}🎉 Hanimo has been submitted to App Store Connect!${NC}"
        echo ""
        echo -e "${BLUE}📝 Next steps:${NC}"
        echo "1. Check App Store Connect for processing status"
        echo "2. Once processed, you can submit for review"
        echo "3. Monitor the review process in App Store Connect"
        ;;
    *)
        echo -e "${RED}❌ Invalid option selected. Opening IPA file location by default.${NC}"
        open "$(dirname "$IPA_PATH")"
        echo -e "${GREEN}✅ Build process completed! IPA file location opened.${NC}"
        ;;
esac

echo ""
echo -e "${GREEN}🎯 Process completed successfully!${NC}" 