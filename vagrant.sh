#!/bin/sh

set -e

_script_basedir=$(readlink -f "$(dirname "$0")")

if [ -f "$_script_basedir/.defaults.env" ]
then
    # shellcheck disable=SC1091
    . "$_script_basedir/.defaults.env"
fi

VAGRANT_EXPERIMENTAL=disks
export VAGRANT_EXPERIMENTAL

exec vagrant "$@"
