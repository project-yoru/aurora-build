#!/usr/bin/env bash

# RUN FROM ./, instead of ./scripts/

# update code
# TODO update secrets
git pull
git submodule update --remote

# update deps
bundle
cd ./vendor/aurora-core-structure && bundle && npm install && bower install && cd ../../

# stop server
source ./scripts/stop_server.sh

# start server
source ./scripts/start_server.sh
