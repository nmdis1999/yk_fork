#! /bin/sh

set -e

export CARGO_HOME="`pwd`/.cargo"
export RUSTUP_HOME="`pwd`/.rustup"

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > rustup.sh
sh rustup.sh --default-host x86_64-unknown-linux-gnu --default-toolchain nightly -y --no-modify-path

export PATH=`pwd`/.cargo/bin/:$PATH

# FIXME in a later PR.
#cargo fmt --all -- --check

cargo test
cargo test --release

which cargo-deny | cargo install cargo-deny
cargo-deny check license
