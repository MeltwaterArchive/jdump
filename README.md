jdump
========
*A tool to take a debug snapshot of a running JVM with one command.*

This script produces an archive containing all the debug information available 
from a running JVM. This archive can then be e-mailed, added to a support 
ticket etc. for later debugging.

Usage
-----

```
$ jdump [options] <app-name> [<output filename>] [<log-directory>]

    app name        Name of the Java application to collect a debug dump from.
    output filename Filename for the target debug archive.
    log directory   Directory containing the applications' logs to include.

Options:
    -f      Generate full heap dump. This will pause the JVM process for some time.
            Only use this option on dead services.
    -q      Suppress information messages, silently create the debug archive.
    -Q      Same as -q, but also suppresses warnings.


```

Examples
--------

```
$ jdump -f heimdall
Unable to determine PID of heimdall. Trying again as root...
heimdall is running as the archive user; switching user...
Generating stack trace...
Generating heap summary...
Generating heap histogram...
Generating heap dump...
Fetching logs from /var/log/heimdall...
Compressing...
Dump to /tmp/heimdall-dump.tgz completed.
```

Packaging
---------

To package using [fpm](https://github.com/jordansissel/fpm), use the convenient
script: `package.sh`:

```
$ . package.sh rpm
```

