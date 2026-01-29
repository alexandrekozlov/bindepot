#!/bin/bash

. $(dirname $0)/00-setup.sh

curl -X PUT http://localhost:4000/api/repositories/pypi-local -H "Content-Type: application/json" --data '{ "type": "local", "package_type": "pypi" }'
curl -X PUT http://localhost:4000/api/repositories/pypi-remote -H "Content-Type: application/json" --data '{ "type": "remote", "package_type": "pypi", "url": "https://pypi.org/" }'

pip_options="--force-reinstall --no-cache-dir"

package_index_url=http://localhost:4000/repositories/pypi-remote/simple/
package_upload_url=http://localhost:4000/repositories/pypi-local/legacy/

. ./make.sh
popd
