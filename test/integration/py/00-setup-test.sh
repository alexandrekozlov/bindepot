#!/bin/bash

set -e -x

export BINDEPOT_CACHE_DIR="$(mktemp -d -t bindepot_cache.XXXXXX)"
export BINDEPOT_DATA_DIR="$(mktemp -d -t bindepot_data.XXXXXX)"
projdir="$(mktemp -d -t pyproj_.XXXXXX)"

pushd ../../..
# Setup bindepot
mix ecto.reset
mix phx.server > /dev/null 2>&1 &
export PHX_SERVER_PROCESS=$!
popd

while ! curl --head http://localhost:4000/ ; do
    sleep 3
done

cleanup() { 
    kill -s SIGQUIT $PHX_SERVER_PROCESS
    rm -rf "$projdir"; 
    rm -rf "$BINDEPOT_CACHE_DIR"; 
    rm -rf "$BINDEPOT_DATA_DIR"; 
}

if [[ "${DEBUG}" == "" ]]; then
    trap cleanup EXIT
fi

. $(dirname $(realpath $0))/00-setup-common.sh
