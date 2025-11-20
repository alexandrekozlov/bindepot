#!/bin/bash

index_url=http://localhost:4000/repositories/pypi-remote/simple/
upload_url=http://localhost:4000/repositories/pypi-local/legacy/

if [ -n "$1" ] ; then
    index_url=$1
fi

if [ -z "$VIRTUAL_ENV" ] ; then
    rm -rf venv
    virtualenv venv
    source venv/bin/activate
fi

export PIP_INDEX_URL=$index_url
pip install --force-reinstall --no-cache-dir -e . && python setup.py sdist bdist_wheel upload -r "$upload_url"
