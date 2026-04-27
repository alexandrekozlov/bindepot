#!/bin/bash

build_project() {
    proj=$1

    pushd `pwd`
    mkdir -p $projdir/$proj
    cp -R projects/$proj/* $projdir/$proj/
    cp projects/$proj/.tool-versions $projdir/$proj/
    cd $projdir/$proj
    . ./make.sh
    popd
}
