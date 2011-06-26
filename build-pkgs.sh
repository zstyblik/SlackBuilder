#!/bin/bash
# 2010/07- @ Zdenek Styblik
# 
# Desc: build packages out of SlackBuilds and place them into bare repo
# directory
#
# ToDo:
# ---
# * a nice to have would be restart from failed PKG, not from the point #1
#
set -e
set -u

ARCH=${ARCH:-"x86_64"}
CWD=$(pwd)
LIBDIRSUFFIX=${LIBDIRSUFFIX:-"64"}
LOGFILE=/tmp/slack.log
PREFIXDIR=${PREFIXDIR:-"/mnt/slackrepo/slackware.tfn/"}
PROFILESDIR=${PROFILESDIR:-"${PREFIXDIR}/profiles/"}
SBODIR=${SBODIR:-"SlackBuilds"}
SLACKDIR=${SLACKDIR:-"slackware64-13.37"}
SLACKMIRROR='ftp://ftp.sh.cvut.cz/storage/1/slackware/'
SLACKMIRRORLINK="${SLACKMIRROR}/${SLACKDIR}/source/"
SVER=$(basename "${SLACKDIR}")

export PREFIXDIR
export SLACKDIR
export SBODIR
export ARCH
export LIBDIRSUFFIX

#exec 1 > "${LOGFILE}.out"
exec 2>"${LOGFILE}.err"

# build everything
buildall() {
	for CATEGORY in l d k a db ap n tfn; do
		if [ ! -d "${SBODIR}/${CATEGORY}/" ]; then
			continue
		fi
		if [ ! -d "${PREFIXDIR}/repo-bare/${SVER}/${CATEGORY}/" ]; then
			mkdir -p "${PREFIXDIR}/repo-bare/${SVER}/${CATEGORY}/";
		fi
		for SBNAME in $(ls -1 "${SBODIR}/${CATEGORY}"); do
			# move pkg/patch original
			# build pkg in original dst
			# install pkg
			# move pkg to repo cat/pkg
			# next, please.
			buildpkg "${CATEGORY}" "${SBNAME}";
		done
	done
return 0
} # buildall

buildpkg() {
	CATEGORY=${1:-""}
	SBNAME=${2:-""}
	if [ -z "${CATEGORY}" ] || [ -z "${SBNAME}" ]; then
		return 1
	fi

	export SBDIR="${PREFIXDIR}/$SBODIR/$CATEGORY/${SBNAME}"
	export DISTPKG="${PREFIXDIR}/${SLACKDIR}/source/$CATEGORY/${SBNAME}"
	
	if [ ! -x "${SBDIR}/build.sh" ]; then
		echo "[${SBNAME}] skipped: build.sh -x." >> "${LOGFILE}"
		echo "[${SBNAME}] skipped: build.sh -x."
		continue
	fi
	cd "${SBDIR}"
	./build.sh || { echo "[${SBNAME}] build.sh has exited with RC $?"; \
	exit 253; }
	REPODST="${PREFIXDIR}/repo-bare/${SVER}/${CATEGORY}/${SBNAME}/"
	# SOMEVAR=repeatingMegaLongStuff could/SHOULD be utilized here!
	# VERSION could be utilized here
	if [ ! -d "${PREFIXDIR}/repo-bare/${SVER}/${CATEGORY}/${SBNAME}" ]; then
		mkdir -p "${PREFIXDIR}/repo-bare/${SVER}/${CATEGORY}/${SBNAME}"
	fi

	mv /tmp/${SBNAME}*.txt "${REPODST}" || \
		{ echo "[${SBNAME}] no external TXT desc found."; true; }

	mv /tmp/${SBNAME}*.md5 "${REPODST}" || \
		{ echo "[${SBNAME}] no external MD5 file found."; true; }

	mv /tmp/${SBNAME}*.txz "${REPODST}/" || \
		{ echo "[${SBNAME}] no pkg with alike name found in /tmp/."; exit 253; }

	cd $PREFIXDIR
	unset BUILD
	unset PKGNAM
	unset VERSION
} # buildpkg

buildprofile() {
	PROFILE=${1:-''}
	if [ -z "${PROFILE}" ]; then
		echo "buildprofile(): Missing param."
		return 1
	fi
	if [ -e "${PROFILE}" ]; then
		true
	elif [ -e "${PROFILESDIR}/${PROFILE}" ]; then
		PROFILE="${PROFILESDIR}/${PROFILE}"
	elif [ -e "${PROFILESDIR}/${PROFILE}.sh" ]; then
		PROFILE="${PROFILESDIR}/${PROFILE}.sh"
	else
		echo "Profile '${PROFILE}' not found. Error!"
		return 1
	fi
	RC=0
	. "${PROFILE}" || RC=1
	if [ ${RC} -ne 0 ]; then
		echo "Unable to include '${PROFILE}'."
		return 1
	fi
	# HAXX
	for PKG in $PKGLIST; do
		CATEGORY=$(printf "%s" "${PKG}" | cut -d '/' -f 1)
		SBNAME=$(printf "%s" "${PKG}" | cut -d '/' -f 2)
		if [ -z "${CATEGORY}" ] || [ -z "${SBNAME}" ]; then
			# should this be a total fail ?
			echo "Category or SBname not set."
			continue
		fi
		buildpkg "${CATEGORY}" "${SBNAME}"
	done
	return 1
} # buildprofile

# desc: print help for this script
show_help() {
	cat <<HELP
Slackware's REPO builder @ Zdenek Styblik

Custom-made repository builder for GNU/Linux Slackware

 * Parameters:
	* -1 <category>/<package>		build only selected package
	* -a			build everything
	* -d			turn on 'dependency' checking
	* -h			print this help
	* -p <profile>		profile to use

HELP

	return 0;
} # show_help

# desc: sync source
# note: wtf was/is purpose of this one? :)
syncsrc() {
	cd "${PREFIXDIR}"
	if [ ! -d "${SLACKDIR}" ]; then
		mkdir "${SLACKDIR}";
	fi
	cd "${SLACKDIR}"
	RC=0
	/usr/bin/wget -m "${SLACKMIRRORLINK}" -o 'source' || RC=1
	return ${RC}
} # syncsrc

### MAIN ###
ACTION=none
DEPS=false
while getopts "1:adhp:" ARG; do
	case "${ARG}" in
			1)
				CATEGORY=$(printf "${OPTARG}" | cut -d '/' -f1)
				SBNAME=$(printf "${OPTARG}" | cut -d '/' -f2)
				if [ -z "${CATEGORY}" ] || [ -z "${SBNAME}" ]; then
					echo "Unknown package given."
					exit 2
				fi
				ACTION=one
				;;
			a)
				ACTION=all
				;;
			d)
				DEPS=true
				;;
			h)
				help
				exit 0
				;;
			p)
				ACTION=profile
				PROFILE="${OPTARG}"
				;;
			\?)
				echo "Invalid option - '${OPTARG}."
				exit 255
				;;
			:)
				echo "Option '${OPTARG}' requires argument."
				exit 255
				;;
			*)
				echo "I don't know what to do."
				exit 1
				;;
	esac; # case $ARG
done # while getopts

export DEPS # export dependency checking

case "${ACTION}" in
	one)
		if [ -z "${CATEGORY}" ] || [ -z "${SBNAME}" ]; then
			echo "Category or Package is unset."
			exit 2;
		fi
		buildpkg "${CATEGORY}" "${SBNAME}"
		;;
	all)
		buildall
		;;
	profile)
		if [ -z "${PROFILE}" ]; then
			echo "Profile is unset."
			exit 2;
		fi
		buildprofile "${PROFILE}"
		;;
	\?)
		echo "Invalid action - ${ACTION}"
		help
		exit 255
		;;
	*)
		echo "Invalid action - ${ACTION}"
		help
		exit 255
		;;
esac # case $ACTION

echo "Everything done."
rm -rf "${LOGFILE}"

