#!/usr/bin/env bash

# update code
# TODO update secrets
git pull
git submodule update --remote

# update deps
bundle

# stop goliath
kill -9 `cat ./tmp/pids/goliath.pid`

# stop sidekiq
sidekiqctl stop ./tmp/pids/sidekiq.pid

# start server
source ./start_server.sh
