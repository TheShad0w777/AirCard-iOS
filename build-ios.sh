
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

if [[ ! -f "$ROOT/rust-core/Cargo.toml" ]]; then
    echo "::error::rust-core/Cargo.toml not found"
    exit 1
fi

if [[ ! -f "$ROOT/rust-core/Cargo.lock" ]]; then
    echo "::error::rust-core/Cargo.lock not found"
    exit 1
fi

if [[ ! -d "$ROOT/rust-core/include" ]]; then
    echo "::error::rust-core/include directory not found"
    exit 1
fi

echo "[2/7] Checking Rust installation..."

command -v cargo
command -v rustc
command -v rustup

rustc --version
cargo --version

echo "[3/7] Checking Xcode..."

if [[ ! -d "$DEVELOPER_DIR" ]]; then
    echo "::error::Xcode Developer directory not found: $DEVELOPER_DIR"
    exit 1
fi

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

DEVICE_LIB="target/aarch64-apple-ios/release/libairlift_ffi.a"
SIMULATOR_LIB="target/aarch64-apple-ios-sim/release/libairlift_ffi.a"

if [[ ! -f "$DEVICE_LIB" ]]; then
    echo "::error::Device static library was not generated"
    exit 1
fi

if [[ ! -f "$SIMULATOR_LIB" ]]; then
    echo "::error::Simulator static library was not generated"
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

if [[ ! -f "$ROOT/AirliftFFI.xcframework/Info.plist" ]]; then
    echo "::error::XCFramework creation failed"
    exit 1
fi

echo ""
echo "========================================"
echo "       BUILD COMPLETED SUCCESSFULLY"
echo "========================================"
