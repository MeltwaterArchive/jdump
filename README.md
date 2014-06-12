JVM DUMP
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
    -q      Suppress information messages, silently create the debug archive.
    -qq     Same as -q, but also suppresses warnings.


```

Examples
--------

```
$ sudo jdump heimdall
heimdall is running as the archive user; switching user...
Generating stack trace...
Generating heap summary...
Generating heap histogram (live)...
Generating heap histogram (full)...
Generating heap dump (live)...
Generating heap dump (full)...
Fetching logs from /var/log/heimdall...
Compressing...
Dump to heimdall-dump.tgz completed.
```

