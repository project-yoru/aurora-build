#!/bin/sh

# rvm

# start goliath
bundle exec ruby ./build_server.rb -p 4000 -e production -d -P ./tmp/pids/goliath.pid -l ./log/goliath.log -S ./tmp/sockets/goliath.sock

# start sidekiq
bundle exec sidekiq -C ./config/sidekiq.yml -v -r ./build_server.rb -g aurora-core-build-server -e production -d
