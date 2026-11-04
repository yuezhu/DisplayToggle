#!/bin/zsh
# The Command Line Tools keep the Swift Testing macro plugin in a subdirectory that
# incremental builds don't search, so pass it explicitly.
exec swift test -Xswiftc -plugin-path \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing "$@"
