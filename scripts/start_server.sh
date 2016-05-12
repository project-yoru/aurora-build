#!/usr/bin/env bash

# rvm

# start server
nohup ruby ./server.rb -e production &> /dev/null &
