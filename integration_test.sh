#!/bin/bash

curl -X PUT http://localhost:4000/api/repositories/third-party  -H "Content-Type: application/json" --data '{ "type": "local" }'
curl http://localhost:4000/api/repositories
curl -X DELETE http://localhost:4000/api/repositories/third-party
curl http://localhost:4000/api/trash/repositories

# curl -X DELETE http://localhost:4000/bindepot/api/trash/repositories/$repo_id

curl -X PUT http://localhost:4000/api/repositories/third-party-local -H "Content-Type: application/json" --data '{"type": "local" }'
curl -X PUT http://localhost:4000/api/storage/third-party-local/gron/bin/gron-linux-amd64-0.5.2.tgz -T gron-linux-amd64-0.5.2.tgz 

curl -X PUT http://localhost:4000/api/repositories/pypi-local -H "Content-Type: application/json" --data '{ "type": "local", "package_type": "pypi" }'
curl -X PUT http://localhost:4000/api/repositories/pypi-remote -H "Content-Type: application/json" --data '{ "type": "remote", "package_type": "pypi", "url": "https://pypi.org/" }'
