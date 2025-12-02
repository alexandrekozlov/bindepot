#!/bin/sh

if [ "$1" == "-y" ] ; then
    mix ecto.reset
    rm -rf ~/.bindepot/data/*
    MIX_ENV=test mix ecto.reset
else
    echo "usage: $0 -y"
    exit 0
fi