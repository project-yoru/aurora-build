#!/usr/bin/env bash

# stop goliath
kill -9 `cat ./tmp/pids/goliath.pid`

# stop sidekiq
sidekiqctl stop ./tmp/pids/sidekiq.pid
