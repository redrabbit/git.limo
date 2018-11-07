#!/bin/sh

release_ctl eval --mfa "GitGud.ReleaseTasks.migrate/1" --argv -- "$@"
