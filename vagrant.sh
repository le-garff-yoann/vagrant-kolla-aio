#!sh

SCRIPT_BASEDIR=$(readlink -f "$(dirname "$0")")

[[ -f "$SCRIPT_BASEDIR/.defaults.env" ]] && . "$SCRIPT_BASEDIR/.defaults.env"
export VAGRANT_EXPERIMENTAL=disks

exec vagrant "$@"
