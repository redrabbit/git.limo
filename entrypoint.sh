#!/bin/sh

# Run SQL migrations
/app/bin/git_limo eval "GitGud.ReleaseTasks.migrate"

exec $@
