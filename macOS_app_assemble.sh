#!/bin/bash
set -e

cd /Users/ahnaf.shahriar/dev/Renode

rm -rf Renode.app

mkdir -p Renode.app/Contents/{MacOS,Resources}

cp tools/packaging/macos/Info.plist Renode.app/Contents/
cp tools/packaging/macos/macos_run.sh Renode.app/Contents/MacOS/
cp tools/packaging/macos/macos_run_dotnet_portable.command Renode.app/Contents/MacOS/macos_run.command
cp tools/packaging/macos/renode.icns Renode.app/Contents/Resources/
chmod +x Renode.app/Contents/MacOS/macos_run.sh
chmod +x Renode.app/Contents/MacOS/macos_run.command

cp -r output/bin/Release/* Renode.app/Contents/MacOS/
cp -r scripts platforms .renode-root Renode.app/Contents/MacOS/

echo "Bundle assembled. Launching..."
open Renode.app