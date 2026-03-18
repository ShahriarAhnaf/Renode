#!/bin/sh

#get the bundle's MacOS directory full path
DIR=$(cd "$(dirname "$0")" && pwd)

PROCESS_NAME=appname
APPNAME="Renode"

# On macOS, GUI frameworks require the process to be launched through
# the .app bundle to get a proper connection to the WindowServer.
# When invoked directly from terminal (not through macos_run.sh/bundle),
# re-launch via 'open' with the bundle to acquire GUI context.
if [ "${__RENODE_MACOS_BUNDLE_LAUNCHED:-0}" != "1" ]; then
    BUNDLE_DIR=$(cd "$DIR/../.." && pwd)
    case "$BUNDLE_DIR" in
        *.app)
            exec open -n -a "$BUNDLE_DIR" --args "$@"
            ;;
    esac
fi

exec -a "$PROCESS_NAME" "$DIR/renode" "$@"
