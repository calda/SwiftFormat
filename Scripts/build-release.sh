#!/bin/sh

set -e

# By default, parses the current version from `Sources/SwiftFormat.swift`.
# Can be overridden by passing in custom version number as argument, e.g.
# `./Scripts/spm-artifact-bundle.sh VERSION_NUMBER`.
VERSION=${1:-$(./Scripts/get-version.sh)}

swift build -c release --arch arm64 --arch x86

./Scripts/spm-artifact-bundle.sh VERSION
