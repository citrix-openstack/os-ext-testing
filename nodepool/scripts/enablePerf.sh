#!/bin/sh
sudo cp /opt/nodepool-scripts/perf*.conf /etc/init

start perf-top
start perf-iostat

