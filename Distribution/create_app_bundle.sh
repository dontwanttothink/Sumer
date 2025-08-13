#!/bin/zsh

set -eu

# You can run this script through `just distribute`.

BINARY=$(swift build -c release --show-bin-path)/Sumer

WORKDIR=${0:a:h}
BASEDIR="$WORKDIR/Outputs/$(date +"%Y-%m-%d")"

SUFFIX=""
if [[ -d "$BASEDIR" ]]; then
    counter=1
    while [[ -d "$BASEDIR-$counter" ]]; do
        ((counter++))
    done
    SUFFIX="-$counter"
fi

OUTDIR=$WORKDIR/Outputs/$(date +"%Y-%m-%d")$SUFFIX

mkdir -p "$OUTDIR/Sumer.app/Contents/MacOS/"
cp "$BINARY" "$OUTDIR/Sumer.app/Contents/MacOS/Sumer"
cp "$WORKDIR/Info.plist" "$OUTDIR/Sumer.app/Contents/"

rm -rf "$WORKDIR/Outputs/Sumer.app"
cp -al "$OUTDIR/Sumer.app" "$WORKDIR/Outputs/Sumer.app"
