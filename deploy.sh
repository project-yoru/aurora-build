#!/bin/sh

# update code
# TODO update secrets
git pull

# restart goliath


# restart sidekiq
sidekiqctl stop ./tmp/pids/sidekiq.pid
