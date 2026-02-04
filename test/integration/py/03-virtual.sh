#!/bin/bash

curl -X PUT http://localhost:4000/api/repositories/pypi-local -H "Content-Type: application/json" --data '{ "type": "local", "package_type": "pypi" }'
curl -X PUT http://localhost:4000/api/repositories/pypi-remote -H "Content-Type: application/json" --data '{ "type": "remote", "package_type": "pypi", "url": "https://pypi.org/" }'
curl -X PUT http://localhost:4000/api/repositories/pypi-virtual -H "Content-Type: application/json" --data '{ "type": "virtual", "package_type": "pypi", "repositories": [ "pypi-remote", "pypi-local" ] }'

pip_options="--force-reinstall --no-cache-dir"
package_upload_url=http://localhost:4000/repositories/pypi-local/legacy/

package_index_url=http://localhost:4000/repositories/pypi-remote/simple/
build_project pydemo02

package_index_url=http://localhost:4000/repositories/pypi-virtual/simple/
build_project pydemo03
