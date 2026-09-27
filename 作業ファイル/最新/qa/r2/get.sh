#!/bin/bash
# get.sh ref path -> saves to ref-short/path
ref=$1; p=$2; d=$ref/$(dirname $p); mkdir -p $d
curl -sfL "https://raw.githubusercontent.com/naruto-aii/AYG/$ref/$p" -o "$ref/$p" && echo "ok $ref $p" || echo "FAIL $ref $p"
