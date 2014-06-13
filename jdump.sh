#!/usr/bin/env bash
#
# A convenience script to create an archive containing all the debug
# information for a JVM application that might be desired.
#
# Usage: jdump [options] <app-name> [<output filename>] [<log-directory>]

function error() {
    [[ -n "$@" ]] && echo -e "Error: $@" 1>&2
    exit 1
}

function print_usage()
{
    echo -e "Usage: jdump <app name> [<output filename>] [<log directory>]

\tapp name\tName of the Java application to collect a debug dump from.
\toutput filename\tFilename for the target debug archive.
\tlog directory\tDirectory containing the applications' logs to include.

Options:
\t-q\tSuppress information messages, silently create the debug archive.
\t-qq\tSame as -q, but also suppresses warnings.
"
}

# set the appropriate log level
LEVEL=0
case "$1" in
   -q) LEVEL=1; shift;;
  -qq) LEVEL=2; shift;;
esac

function info() {
    [[ $LEVEL -lt 1 ]] && echo -e "$@"
}

function warn() {
    [[ $LEVEL -lt 2 ]] && echo -e "$@" 1>&2
}

APP_NAME="$1"

function generate() {
    PROG="$1"
    ARGS="$2"
    OUT="$3"
    DESC="$4"

    info "Generating $DESC..."
    $PROG $ARGS $PID >$OUT 2>/dev/null

    if [[ "$?" -ne 0 ]]; then
        warn "Unable to generate $DESC. Skipping..."
        rm -f "$OUT" 2>/dev/null
    fi
}

function generate_no_redirect() {
    PROG="$1"
    ARGS="$2"
    OUT="$3"
    DESC="$4"

    info "Generating $DESC..."
    $PROG $ARGS $PID &>/dev/null

    if [[ "$?" -ne 0 ]]; then
        warn "Unable to generate $DESC. Skipping..."
        rm -f "$OUT" 2>/dev/null
    fi
}

DEFAULT_DUMP_FILE="$APP_NAME-dump.tgz"

if [[ ! -w "./" ]]; then
    DEFAULT_DUMP_FILE="/tmp/$DEFAULT_DUMP_FILE"
fi

DUMP_FILE="${2:-$DEFAULT_DUMP_FILE}"
LOG_DIR="${3:-/var/log/$APP_NAME}"
TMP_DIR="/tmp/$APP_NAME-dump.$(date -u +%s)"
TMP_PATH="$TMP_DIR/$APP_NAME"
JMAP="$(which jmap 2>/dev/null)"
JPS="$(which jps 2>/dev/null)"
JSTACK="$(which jstack 2>/dev/null)"
PID=$($JPS 2>/dev/null | grep -i "$APP_NAME" | awk '{print $1}')

[[ -n "$APP_NAME" ]] && {
    print_usage
    exit 1
}

[[ -z "$JMAP" ]] &&
    error "jmap not found. Ensure the JDK is installed and that the 'jmap' program is on the PATH."

[[ -z "$JPS" ]] &&
    error "jps not found. Ensure the JDK is installed and that the 'jps' program is on the PATH."

[[ -z "$JSTACK" ]] &&
    error "jstack not found. Ensure the JDK is installed and that the 'jstack' program is on the PATH."

if [[ -z "$PID" ]]; then
    # try again, as root
    if [[ "$USER" != "root" ]]
    then
        warn "Unable to determine PID of $APP_NAME. Trying again as root..."
        PID=$(sudo $JPS 2>/dev/null | grep -i "$APP_NAME" | awk '{print $1}')

        [[ -z "$PID" ]] &&
            error "Unable to determine PID of $APP_NAME. Ensure it is running."
    fi
fi

EUSER=$(ps -p $PID --no-headers -o euser)

# if the user is wrong, run the dump as the correct user
if [[ "$USER" != "$EUSER" ]]; then
    warn "$APP_NAME is running as the $EUSER user; switching user..."
    sudo -u "$EUSER" $0 $*
    exit $?
fi

if [[ ! -w $(dirname $DUMP_FILE) ]]; then
    error "Unable to dump to $DUMP_FILE.
The target directory does not exist or is not writable by $USER".
fi

mkdir -p "$TMP_PATH" 2>/dev/null

generate $JSTACK "-l" "$TMP_PATH/stack-trace.txt" "stack trace"

generate $JMAP "-heap" "$TMP_PATH/heap-summary.txt" "heap summary"

generate $JMAP "-histo:live" "$TMP_PATH/live.histo" "heap histogram (live)"

generate $JMAP "-histo" "$TMP_PATH/full.histo" "heap histogram (full)"

generate_no_redirect $JMAP "-dump:live,format=b,file=$TMP_PATH/live.hprof"\
    "$TMP_PATH/live.hprof"\
    "heap dump (live)"

generate_no_redirect $JMAP "-dump:format=b,file=$TMP_PATH/full.hprof"\
    "$TMP_PATH/full.hprof"\
    "heap dump (full)"

if [[ -e "$LOG_DIR" -a -d "$LOG_DIR" ]]; then
    info "Fetching logs from $LOG_DIR..."
    mkdir "$TMP_PATH/logs"
    cp $LOG_DIR/* "$TMP_PATH/logs"
fi

# optionally archive and compress
case "$DUMP_FILE" in
    *.tar*)
        info "Archiving..."
        tar -C "$TMP_DIR" acf "$DUMP_FILE" "$APP_NAME" &>/dev/null
        ;;
    *)
        info "Copying..."
        cp "$TMP_PATH" "$DUMP_FILE"
        ;;
esac

# remove temporary directory
rm -rf "$TMP_DIR"

info "Dump to $DUMP_FILE completed."

