#!/bin/bash

curl -X PUT http://localhost:4000/api/repositories/third-party --data '{ "type": "local" }'
curl http://localhost:4000/api/repositories
curl -X DELETE http://localhost:4000/api/repositories/third-party
curl http://localhost:4000/api/trash/repositories

# curl -X DELETE http://localhost:4000/bindepot/api/trash/repositories/$repo_id

curl -X PUT http://localhost:4000/api/repositories/third-party-local --data '{"type": "local" }'
curl -X PUT http://localhost:4000/api/storage/third-party-local/gron/bin/gron-linux-amd64-0.5.2.tgz -T gron-linux-amd64-0.5.2.tgz 


