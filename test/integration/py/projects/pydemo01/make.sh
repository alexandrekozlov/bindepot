#!/bin/bash

set -x -e

if [ -z "$VIRTUAL_ENV" ] ; then
    rm -rf venv
    virtualenv venv
    source venv/bin/activate
fi

export PIP_INDEX_URL=$package_index_url

pip install $pip_options -e .
if [ $? != 0 ] ; then
    echo "pip failed. exit code $?"
    exit 1
fi


if [ -n "$package_upload_url" ] ; then
    upload_cmd="upload -r $package_upload_url"
fi

python setup.py sdist bdist_wheel $upload_cmd
