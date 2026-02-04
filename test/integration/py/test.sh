#!/bin/bash

if [ -z "$1" ] ; then
    exit 0
fi

basedir=$(dirname $(realpath $0))

pushd $(pwd)
. $basedir/00-setup-test.sh
. $basedir/$1-*.sh
popd
