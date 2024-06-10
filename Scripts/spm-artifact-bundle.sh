#!/bin/sh

set -e

ARTIFACT_BUNDLE=swiftformat.artifactbundle
INFO_TEMPLATE=Scripts/spm-artifact-bundle-info.template
INFO_TEMPLATE_MACOS_ONLY=Scripts/spm-artifact-bundle-info-macOS.template
MAC_BINARY_OUTPUT_DIR=$ARTIFACT_BUNDLE/swiftformat-$VERSION-macos/bin
LINUX_BINARY_OUTPUT_DIR=$ARTIFACT_BUNDLE/swiftformat-$VERSION-linux-gnu/bin

# By default, parses the current version from `Sources/SwiftFormat.swift`.
# Can be overridden by passing in custom version number as argument, e.g.
# `./Scripts/spm-artifact-bundle.sh VERSION_NUMBER`.
VERSION=${1:-$(./Scripts/get-version.sh)}

rm -rf swiftformat.artifactbundle
rm -rf swiftformat.artifactbundle.zip

mkdir $ARTIFACT_BUNDLE

# Copy license into bundle
cp LICENSE.md $ARTIFACT_BUNDLE

# Create bundle info.json from template, replacing version
if [ -e CommandLineTool/swiftformat_linux ]
then
  sed 's/__VERSION__/'"${VERSION}"'/g' $INFO_TEMPLATE > "${ARTIFACT_BUNDLE}/info.json"
else
  sed 's/__VERSION__/'"${VERSION}"'/g' $INFO_TEMPLATE_MACOS_ONLY > "${ARTIFACT_BUNDLE}/info.json"
fi

# Copy macOS SwiftFormat binary into bundle
mkdir -p $MAC_BINARY_OUTPUT_DIR
cp CommandLineTool/swiftformat $MAC_BINARY_OUTPUT_DIR

if [ -e CommandLineTool/swiftformat_linux ]
then
  # Copy Linux SwiftFormat binary into bundle
  mkdir -p $LINUX_BINARY_OUTPUT_DIR
  cp CommandLineTool/swiftformat_linux $LINUX_BINARY_OUTPUT_DIR
fi

# Create ZIP
zip -yr - $ARTIFACT_BUNDLE > "${ARTIFACT_BUNDLE}.zip"

rm -rf $ARTIFACT_BUNDLE
