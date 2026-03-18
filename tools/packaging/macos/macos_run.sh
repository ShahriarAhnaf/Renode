#!/bin/sh

DIR=$(cd "$(dirname "$0")" && pwd)

export __RENODE_MACOS_BUNDLE_LAUNCHED=1
exec "$DIR/macos_run.command" "$@"
