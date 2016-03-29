#!/usr/bin/env bash

# rvm

# start goliath
bundle exec ruby ./build_server.rb -v -e production -P ./tmp/pids/goliath.pid -l ./log/goliath.log -S ./tmp/sockets/goliath.sock -d

# start sidekiq
bundle exec sidekiq -C ./config/sidekiq.yml -v -r ./build_server.rb -g aurora-core-build-server -e production -d
