#!/bin/sh
# 2010/07- @ Zdenek Styblik
#
# Desc: build packages out of SlackBuilds and place them into bare repo
# directory
#
set -e
set -u

PREFIX=$(dirname "${0}")
if [ ${PREFIX} = '.' ]; then
	PREFIX=$(pwd)
fi

. "${PREFIX}/include/slackbuilder-conf.sh"

export PREFIX
export SBO_DIR
export ARCH
export LIBDIRSUFFIX
export TMP_PREFIX
export SLACKVER
export SOURCES

KEEP_TMP=${KEEP_TMP:-0}

# build everything
buildall() {
	for CATEGORY in l d k a db ap n tfn; do
		if [ ! -d "${SBO_DIR}/${CATEGORY}/" ]; then
			continue
		fi
		if [ ! -d "${REPO_STAGE_DIR}/${SLACKVER}/${CATEGORY}/" ]; then
			mkdir -p "${REPO_STAGE_DIR}/${SLACKVER}/${CATEGORY}/"
		fi
		for SBNAME in $(ls -1 "${SBO_DIR}/${CATEGORY}"); do
			# move pkg/patch original
			# build pkg in original dst
			# install pkg
			# move pkg to repo cat/pkg
			# next, please.
			buildpkg "${CATEGORY}" "${SBNAME}"
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

	export SBDIR="$SBO_DIR/$CATEGORY/${SBNAME}"
	export DISTPKG="${SLACK_MIRROR}/source/${CATEGORY}/${SBNAME}"

	if [ ! -x "${SBDIR}/build.sh" ]; then
		printf "[%s] skipped: build.sh -x.\n" "${SBNAME}"
		continue
	fi
	TMP=$(mktemp -q -p "${TMP_PREFIX}" -d || true)
	if [ -z "${TMP}" ]; then
		printf "Failed to create temporary directory.\n"
		return 1
	fi
	export TMP
	cd "${SBDIR}"
	RC=0
	./build.sh || RC=$?
	if [ $RC -ne 0 ]; then
		printf "[%s] build.sh has exited with RC %i.\n" "${SBNAME}" $RC
		if [ $KEEP_TMP!="1" ]; then
			rm -rf "${TMP}"
		else
			printf "[%s] Kept TMP dir '%s'.\n" "${SBNAME}" "${TMP}"
		fi
		exit 253
	fi
	REPODEST="${REPO_STAGE_DIR}/${SLACKVER}/${CATEGORY}/${SBNAME}/"
	# VERSION could be utilized here
	if [ ! -d "${REPODEST}" ]; then
		mkdir -p "${REPODEST}"
	fi

	if ! mv ${TMP}/${SBNAME}*.t?z "${REPODEST}/" ; then
		printf "[%s] no pkg with alike name found in '%s'.\n" "${SBNAME}" "${TMP}"
		exit 253
	fi

	if ! mv ${TMP}/${SBNAME}*.txt "${REPODEST}" ; then
		printf "[%s] no external TXT desc found.\n" "${SBNAME}"
	fi

	if ! mv ${TMP}/${SBNAME}*.pkgdesc "${REPODEST}" ; then
		printf "[%s] no PKGDESC file found!\n" "${SBNAME}"
	fi

	if ! mv ${TMP}/${SBNAME}*.md5 "${REPODEST}" ; then
		printf "[%s] no external MD5 file found.\n" "${SBNAME}"
	fi

	cd ${PREFIX}
	rm -rf "${TMP}"
	unset BUILD
	unset PKGNAM
	unset VERSION
	unset TMP
	return 0
} # buildpkg

buildprofile() {
	PROFILE=${1:-''}
	if [ -z "${PROFILE}" ]; then
		echo "buildprofile(): Missing param."
		return 1
	fi

	if [ ! -d "${PROFILE}" ]; then
		printf "Supplied profile '%s' is not a directory.\n" "${PROFILE}"
		return 1
	fi

	for PFILE in $PROFILE/*; do
		if [ ! -x "${PFILE}" ]; then
			printf "Skipping '%s', no +x flag set.\n" "${PFILE}"
			continue
		fi
		RC=0
		. "${PFILE}" || RC=$?
		if [ ${RC} -eq 1 ]; then
			printf "Error while including '%s' profile, RC=%i.\n" "${PFILE}" $RC
			continue
		fi # if [ ${RC} -eq 1 ]
		PKG=${PKG:-''}
		if [ -z "${PKG}" ]; then
			printf "Package name not set in profile '%s'.\n" "${PFILE}"
			continue
		fi
		CATEGORY=$(printf "%s" "${PKG}" | awk -F',' '{ print $1 }' | \
			awk -F'/' '{ print $1 }')
		SBNAME=$(printf "%s" "${PKG}" | awk -F'/' '{ print $2 }' | \
			awk -F',' '{ print $1 }')
		if [ -z "${CATEGORY}" ] || [ -z "${SBNAME}" ]; then
			# should this be a total fail ?
			echo "Category or SBname not set."
			continue
		fi
		buildpkg "${CATEGORY}" "${SBNAME}"
	done # for PKG in PKGLIST
	return 0
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

	return 0
} # show_help

### MAIN ###
ACTION=none
DEPS=false
while getopts "1:adhp:" ARG; do
	case "${ARG}" in
			1)
				CATEGORY=$(printf "${OPTARG}" | awk -F'/' '{ print $1 }')
				SBNAME=$(printf "${OPTARG}" | awk -F'/' '{ print $2 }')
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
				show_help
				exit 0
				;;
			p)
				ACTION=profile
				PROFILE="${OPTARG}"
				;;
			\?)
				echo "Invalid option - '${OPTARG}'."
				show_help
				exit 255
				;;
			:)
				echo "Option '${OPTARG}' requires argument."
				show_help
				exit 255
				;;
			*)
				echo "I don't know what to do."
				show_help
				exit 1
				;;
	esac; # case $ARG
done # while getopts

export DEPS # export dependency checking

case "${ACTION}" in
	all)
		buildall
		;;
	help)
		show_help
		exit 0
		;;
	one)
		if [ -z "${CATEGORY}" ] || [ -z "${SBNAME}" ]; then
			echo "Category or Package is unset."
			exit 2
		fi
		buildpkg "${CATEGORY}" "${SBNAME}"
		;;
	profile)
		if [ -z "${PROFILE}" ]; then
			echo "Profile is unset."
			exit 2
		fi
		buildprofile "${PROFILE}"
		;;
	\?)
		echo "Invalid action - '${ACTION}'"
		show_help
		exit 255
		;;
	*)
		echo "Invalid action - '${ACTION}'"
		show_help
		exit 255
		;;
esac # case $ACTION

echo "Everything done."
# EOF
