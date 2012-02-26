#!/bin/sh
# Configuration file for SlackBuilder

# Temporary dir prefix for % mktemp; - extract sources and build pkgs
TMP_PREFIX=${TMP_PREFIX:-"/tmp/"}
# Slackware version we are building for
SLACKVER=${SLACKVER:-"slackware64-13.37"}
# /usr/lib directory suffix, None -> 32bit, 64 -> 64bit
LIBDIRSUFFIX=${LIBDIRSUFFIX:-""}
# Architecture - i386, i686, x86_64, ...
ARCH=${ARCH:-""}
# General SlackBuilder log
LOG_DIR="${TMP_PREFIX}"
# Where to get sources - file:, http:, nfs:, ftp:,
SLACK_MIRROR=${SLACK_MIRROR:-'file:/mnt/cdrom'}
# Directory of Repository - stage
REPO_STAGE_DIR=${REPO_STAGE_DIR:-"${PREFIX}/repo-stage/"}
# Directory of Repository - live
REPO_DIR=${REPO_DIR:-"${PREFIX}/repo/"}
# Directory where building profiles can be found
PROFILES_DIR=${PROFILES_DIR:-"${PREFIX}/profiles/"}
# Directory with SlackBuilds
SBO_DIR=${SBO_DIR:-"${PREFIX}/SlackBuilds/"}
# Directory with sources for SlackBuilds or keep empty for SlackBuild default
SOURCES=${SOURCES:-"/usr/src/SlackBuildSources/"}


### BLOAT ###
if [ -z "${LIBDIRSUFFIX}" ]; then
	printf "%s" "${SLACKVER}" | grep -q -e 'slackware64' && LIBDIRSUFFIX=64
fi
if [ -z "${ARCH}" ]; then
	ARCH="i686"
	if [ "${LIBDIRSUFFIX}" = '64' ]; then
		ARCH="x86_64"
	fi
fi
### EOF ###
