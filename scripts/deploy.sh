#!/usr/bin/env bash

# RUN FROM ./, instead of ./scripts/

# update code
# TODO update secrets
git pull
git submodule update --remote

# update deps
bundle
cd ./vendor/aurora-core-structure && bundle && npm install && bower install && cd ../../

# stop goliath
kill -9 `cat ./tmp/pids/goliath.pid`

# stop sidekiq
sidekiqctl stop ./tmp/pids/sidekiq.pid

# start server
source ./scripts/start_server.sh
