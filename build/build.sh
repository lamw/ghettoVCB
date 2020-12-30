#!/bin/bash

docker rmi -f ghettovcb
rm -rf artifacts
docker build -t ghettovcb .
docker run -i -v ${PWD}/artifacts:/artifacts ghettovcb sh << COMMANDS
cp vghetto-ghettoVCB* /artifacts
COMMANDS
