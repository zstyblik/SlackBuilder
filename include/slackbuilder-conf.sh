#!/bin/sh
# Configuration file for SlackBuilder

# Slackware version to build for
SLACKVER=${SLACKVER:-"slackware64-13.37"}
# /usr/lib directory suffix, None -> 32bit, 64 -> 64bit
LIBDIRSUFFIX=${LIBDIRSUFFIX:-""}
# Architecture
ARCH=${ARCH:-""}
# Where to log errors during build 
LOGFILE=/tmp/slackbuilder.log
# Path to "mounted" Slackware CD/DVD
SLACK_CD_DIR=${SLACK_CD_DIR:-'/mnt/cdrom'}
# Directory of Repository - bare
REPOBAREDIR=${REPOBAREDIR:-"${PREFIX}/repo-bare/"}
# Directory of Repository - live
REPODIR=${REPODIR:-"${PREFIX}/repo/"}
# Temporary dir - extract sources and build pkgs
TMP=${TMPDIR:-"/tmp/"}
# Directory where building profiles can be found
PROFILESDIR=${PROFILESDIR:-"${PREFIX}/profiles/"}
# Directory with SlackBuilds
SBODIR=${SBODIR:-"${PREFIX}/SlackBuilds/"}
# Where to download Slackware sources - not used anywhere, I'd say
SLACKMIRROR='ftp://ftp.sh.cvut.cz/storage/1/slackware/'


### BLOAT ###
if [ -z $LIBDIRSUFFIX ]; then
	printf "%s" ${SLACKVER} | grep -q -e 'slackware64' && LIBDIRSUFFIX=64
fi
if [ -z $ARCH ]; then
	ARCH="i686"
	if [ $LIBDIRSUFFIX == '64' ]; then
		ARCH="x86_64"
	fi
fi
### EOF ###
