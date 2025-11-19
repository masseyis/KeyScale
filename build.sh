#!/bin/bash

# Build script for KeyScale Renoise Tool
# Creates com.penchi.KeyScale.xrnx package

# Remove old package if it exists
if [ -f "com.penchi.KeyScale.xrnx" ]; then
    echo "Removing old com.penchi.KeyScale.xrnx..."
    rm com.penchi.KeyScale.xrnx
fi

# Create the .xrnx package (which is just a zip file)
echo "Building com.penchi.KeyScale.xrnx..."
zip -q com.penchi.KeyScale.xrnx \
    main.lua \
    manifest.xml \
    cover.png \
    thumbnail.png \
    README.md

# Check if the build was successful
if [ $? -eq 0 ]; then
    echo "✓ Successfully built com.penchi.KeyScale.xrnx"
    echo "  Package size: $(du -h com.penchi.KeyScale.xrnx | cut -f1)"
    echo ""
    echo "Files included:"
    unzip -l com.penchi.KeyScale.xrnx
else
    echo "✗ Build failed"
    exit 1
fi
