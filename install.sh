#!/usr/bin/env bash
#
# A utility to install jdump and configure its environment
#

PREFIX=${PREFIX:-/usr/local}
JAVA_BIN=${JAVA_HOME:-"$(dirname $(readlink -e $(which java)))"}

# locate and symlink dependencies, if required

function find_and_link() {
    PROG="$1"
    if [ -z "$(which $PROG 2>/dev/null)" ]
    then
        if [ ! -e "$JAVA_BIN/$PROG" ]
        then
            echo "ERROR: Unable to find $PROG (in $JAVA_BIN).
Ensure you have the full JDK installed."
            exit 1
        fi

        ln -s "$JAVA_BIN/$PROG" "$PREFIX/bin/$PROG" 2>/dev/null

        if [ $? -eq 0 ]
        then
            echo "Linked $JAVA_BIN/$PROG to $PREFIX/bin/$PROG"
        else
            echo "ERROR: Failed to link $JAVA_BIN/$PROG to $PREFIX/bin/$PROG"
            exit 1
        fi
    fi
}

find_and_link "jstack"
find_and_link "jmap"
find_and_link "jps"

# install jdump
cp ./jdump.sh $PREFIX/bin/jdump && chmod +x $PREFIX/bin/jdump

if [ $? -eq 0 ]
then
    echo "Installed jdump to $PREFIX/bin/jdump"
else
    echo "ERROR: Failed to install jdump to $PREFIX/bin/jdump"
fi

