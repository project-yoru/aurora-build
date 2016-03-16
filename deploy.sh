#!/bin/sh

# update code
# TODO update secrets
git pull

# update deps
bundle

# restart goliath
# TODO try god
# TODO

# stop sidekiq
sidekiqctl stop ./tmp/pids/sidekiq.pid

# start sidekiq
bundle exec sidekiq -C ./config/sidekiq.yml -v -r ./build_server.rb -g aurora-core-build-server -e production -d
