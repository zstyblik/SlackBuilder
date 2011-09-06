#!/bin/sh
# 2010/07/24 @ Zdenek Styblik
set -e
set -u

DIRECTORY=${1:-'./'}

find $DIRECTORY -exec md5sum {} \; 2>/dev/null

