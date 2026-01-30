#!/bin/bash

if [ -z "$1" ] ; then
    exit 0
fi

basedir=$(dirname $(realpath $0))

. $basedir/00-setup.sh

. $basedir/$1-*.sh

popd
