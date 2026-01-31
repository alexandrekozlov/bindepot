#!/bin/bash

set -e -x

projdir="$(mktemp -d -t pyproj_.XXXXXX)"

while ! curl --head http://localhost:4000/ ; do
    sleep 3
done

cleanup() { 
    rm -rf "$projdir"; 
}

if [[ "${DEBUG}" == "" ]]; then
    trap cleanup EXIT
fi

cp -R proj/* $projdir

pushd `pwd`
cd $projdir
