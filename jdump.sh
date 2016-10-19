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
    echo -e "Usage: jdump [options] <app name> [<output filename>] [<log dir>]

\tapp name       \tName of the Java application to collect a debug dump from.
\toutput filename\tFilename for the target debug archive.
\tlog dir        \tDirectory containing the applications' logs to include.

Options:
\t-f\tGenerate full heap dump. This will pause the JVM process for some time.
\t  \tOnly use this option on dead services.
\t-q\tSuppress information messages, silently create the debug archive.
\t-Q\tSame as -q, but also suppresses warnings.
"
}

OPTS=()
LEVEL=0
FULL=false

while getopts ":fqQ" opt
do
    case "$opt" in
        f) FULL=true; OPTS+=('-f'); shift;;
        q) LEVEL=1; OPTS+=('-q'); shift;;
        Q) LEVEL=2; OPTS+=('-Q'); shift;;
        \?) error "Invalid argument: -$OPTARG";;
    esac
done

function info() {
    [[ $LEVEL -lt 1 ]] && echo -e "$@"
}

function warn() {
    [[ $LEVEL -lt 2 ]] && echo -e "$@" 1>&2
}

APP_NAME="$1"

function generate() {
    PROG="$1"
    DESC="$2"
    OUT="$3"

    shift 3;

    info "Generating $DESC..."
    $PROG "$@" >"$OUT" 2>/dev/null

    if [[ "$?" -ne 0 ]]; then
        warn "Unable to generate $DESC. Skipping..."
        rm -f "$OUT" 2>/dev/null
    fi
}

function generate_no_redirect() {
    PROG="$1"
    DESC="$2"
    OUT="$3"

    shift 3;

    info "Generating $DESC..."
    $PROG "$@" &>/dev/null

    if [[ "$?" -ne 0 ]]; then
        warn "Unable to generate $DESC. Skipping..."
        rm -f "$OUT" 2>/dev/null
    fi
}

function not_found() {
    error "$1 not found. Ensure it is installed and that '$1' is on the PATH."
}

TMPDIR="${TMPDIR:-/tmp}"
DEFAULT_DUMP_FILE="$APP_NAME-dump.tgz"

if [[ ! -w "./" ]]; then
    DEFAULT_DUMP_FILE="$TMPDIR/$DEFAULT_DUMP_FILE"
fi

DUMP_FILE="${2:-$DEFAULT_DUMP_FILE}"
LOG_DIR="${3:-/var/log/$APP_NAME}"
JMAP="$(which jmap 2>/dev/null)"
JPS="$(which jps 2>/dev/null)"
JSTACK="$(which jstack 2>/dev/null)"

[[ -z "$APP_NAME" ]] && print_usage && exit 1

[[ -z "$JMAP" ]] && not_found "jmap"

[[ -z "$JPS" ]] && not_found "jps"

[[ -z "$JSTACK" ]] && not_found "jstack"

PID=$($JPS 2>/dev/null | grep -i "$APP_NAME" 2>/dev/null | head -n1 | awk '{print $1}')
if (( $? > 1 )); then
    error "Failed to get PID for: $APP_NAME"
fi

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
    sudo -u "$EUSER" $0 $OPTS $*
    exit $?
fi

if [[ ! -w $(dirname $DUMP_FILE) ]]; then
    error "Unable to dump to $DUMP_FILE.
The target directory does not exist or is not writable by $USER".
fi

TMP_PATH="$(mktemp -d $TMPDIR/$APP_NAME-dump.$(date -u +%s).XXXXX)"

generate $JSTACK "stack trace" "$TMP_PATH/stack-trace.txt" "-l" "$PID"

generate $JMAP "heap summary" "$TMP_PATH/heap-summary.txt" "-heap" "$PID"

generate $JMAP "heap histogram (live)" "$TMP_PATH/live.histo" "-histo:live" "$PID"

generate $JMAP "heap histogram (full)" "$TMP_PATH/full.histo" "-histo" "$PID"

generate_no_redirect $JMAP "heap dump (live)" "$TMP_PATH/live.hprof" \
    "-dump:live,format=b,file=$TMP_PATH/live.hprof" "$PID"

generate_no_redirect $JMAP "heap dump (full)" "$TMP_PATH/full.hprof" \
    "-dump:format=b,file=$TMP_PATH/full.hprof" "$PID"

if [[ -e "$LOG_DIR" && -d "$LOG_DIR" && -r "$LOG_DIR" ]]; then
    info "Fetching logs from $LOG_DIR..."
    cp -r "$LOG_DIR" "$TMP_PATH/logs" 2>/dev/null
fi

# optionally archive and compress
case "$DUMP_FILE" in
    *.tar*|*.tgz)
        info "Archiving..."
        tar -C "$(dirname $TMP_PATH)" -acf "$DUMP_FILE" "$(basename $TMP_PATH)"
        ;;
    *)
        info "Copying..."
        cp -r "$TMP_PATH" "$DUMP_FILE" 2>/dev/null
        ;;
esac

# remove temporary directory
rm -rf "$TMP_PATH" 2>/dev/null

info "Dump to $DUMP_FILE completed."

