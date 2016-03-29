#!/usr/bin/env bash

# RUN FROM ./, instead of ./scripts/
# TODO make paths relative to the file instead of the pwd path could solve this issue

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
source ./scripts/start_server.sh
