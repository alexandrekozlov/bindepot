#!/bin/bash

. $(dirname $0)/00-setup.sh

pip_options="--force-reinstall --no-cache-dir"

package_index_url=https://pypi.org/simple/

. ./make.sh
popd
