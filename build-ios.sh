#!/usr/bin/env bash
set -Eeuo pipefail
trap 'status=$?; echo "::error::build-ios.sh failed at line ${LINENO}: ${BASH_COMMAND} (exit ${status})"; exit "$status"' ERR
echo "========================================"
echo "       AirCard Rust XCFramework Build"
echo "========================================"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode_16.4.app/Contents/Developer}"
export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-18.0}"
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
echo "[1/7] Checking project files..."
test -f "$ROOT/rust-core/Cargo.toml"
test -f "$ROOT/rust-core/Cargo.lock"
test -d "$ROOT/rust-core/include"
echo "[2/7] Checking Rust installation..."
command -v cargo
command -v rustc
command -v rustup
rustc --version
cargo --version
echo "[3/7] Checking Xcode..."
test -d "$DEVELOPER_DIR"
xcodebuild -version
echo "[4/7] Installing iOS Rust targets..."
rustup target add \
    aarch64-apple-ios \
    aarch64-apple-ios-sim
cd "$ROOT/rust-core"
echo "[5/7] Building iOS device library..."
cargo build \
    --locked \
    --release \
    --target aarch64-apple-ios
echo "[6/7] Building iOS simulator library..."
cargo build \
    --locked \
    --release \
    --target aarch64-apple-ios-sim
DEVICE_LIB="$ROOT/rust-core/target/aarch64-apple-ios/release/libairlift_ffi.a"
SIMULATOR_LIB="$ROOT/rust-core/target/aarch64-apple-ios-sim/release/libairlift_ffi.a"
echo "Checking generated libraries..."
if [[ ! -f "$DEVICE_LIB" ]]; then
    echo "::error::Device library not found: $DEVICE_LIB"
    exit 1
fi
if [[ ! -f "$SIMULATOR_LIB" ]]; then
    echo "::error::Simulator library not found: $SIMULATOR_LIB"
    exit 1
fi
cd "$ROOT"
echo "[7/7] Creating AirliftFFI.xcframework..."
rm -rf "$ROOT/AirliftFFI.xcframework"
xcodebuild -create-xcframework \
    -library "$DEVICE_LIB" \
    -headers "$ROOT/rust-core/include" \
    -library "$SIMULATOR_LIB" \
    -headers "$ROOT/rust-core/include" \
    -output "$ROOT/AirliftFFI.xcframework"
test -f "$ROOT/AirliftFFI.xcframework/Info.plist"
echo ""
echo "========================================"
echo "       BUILD COMPLETED SUCCESSFULLY"
echo "========================================"
