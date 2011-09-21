#!/bin/sh
# 2010/07- @ Zdenek Styblik
# 
# Desc: build packages out of SlackBuilds and place them into bare repo
# directory
#
set -e
set -u

PREFIX=$(dirname ${0})

. "${PREFIX}/include/slackbuilder-conf.sh"

export PREFIX
export SLACKDIR
export SBODIR
export ARCH
export LIBDIRSUFFIX
export TMP

#exec 1 > "${LOGFILE}.out"
exec 2>"${LOGFILE}.err"

# build everything
buildall() {
	for CATEGORY in l d k a db ap n tfn; do
		if [ ! -d "${SBODIR}/${CATEGORY}/" ]; then
			continue
		fi
		if [ ! -d "${REPOBAREDIR}/${SLACKVER}/${CATEGORY}/" ]; then
			mkdir -p "${REPOBAREDIR}/${SLACKVER}/${CATEGORY}/"
		fi
		for SBNAME in $(ls -1 "${SBODIR}/${CATEGORY}"); do
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

	export SBDIR="$SBODIR/$CATEGORY/${SBNAME}"
	export DISTPKG="${SLACK_CD_DIR}/source/${CATEGORY}/${SBNAME}"
	
	if [ ! -x "${SBDIR}/build.sh" ]; then
		echo "[${SBNAME}] skipped: build.sh -x." >> "${LOGFILE}"
		echo "[${SBNAME}] skipped: build.sh -x."
		continue
	fi
	cd "${SBDIR}"
	if ! ./build.sh ; then
		echo "[${SBNAME}] build.sh has exited with RC $?"
		exit 253
	fi
	REPODEST="${REPOBAREDIR}/${SLACKVER}/${CATEGORY}/${SBNAME}/"
	# VERSION could be utilized here
	if [ ! -d "${REPODEST}" ]; then
		mkdir -p "${REPODEST}"
	fi

	if ! mv /tmp/${SBNAME}*.txt "${REPODEST}" ; then
		printf "[%s] no external TXT desc found.\n" ${SBNAME}
	fi

	if ! mv /tmp/${SBNAME}*.md5 "${REPODEST}" ; then
		printf "[%s] no external MD5 file found.\n" ${SBNAME}
	fi

	if ! mv /tmp/${SBNAME}*.txz "${REPODEST}/" ; then
		printf "[%s] no pkg with alike name found in /tmp/.\n" ${SBNAME}
		exit 253
	fi

	cd ${PREFIX}
	unset BUILD
	unset PKGNAM
	unset VERSION
	return 0
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
		printf "Profile '%s' not found. Error!\n" ${PROFILE}
		return 1
	fi
	RC=0
	. "${PROFILE}" || RC=1
	if [ ${RC} -ne 0 ]; then
		printf "Unable to include '%s'.\n" ${PROFILE}
		return 1
	fi
	PKGLIST=${PKGLIST:-''}
	DEFAULTVER=${DEFAULTVER:-''}
	if [ -z "${PKGLIST}" ]; then
		echo "To build what? PKGLIST empty."
		return 1
	fi
	# HAXX
	for PKG in $PKGLIST; do
		CATEGORY=$(printf "%s" "${PKG}" | awk -F',' '{ print $1 }' | \
			awk -F'/' '{ print $1 }')
		SBNAME=$(printf "%s" "${PKG}" | awk -F'/' '{ print $2 }' | \
			awk -F',' '{ print $1 }')
		export VERSION=$(printf "%s" "${PKG}" | awk -F',' '{ print $2 }')
		if [ -z "${VERSION}" ]; then
			if [ ! -z "${DEFAULTVER}" ]; then
				export VERSION=${DEFAULTVER}
			else
				unset VERSION
			fi # if ! -z DEFAULTVER
		fi # if -z VERSION
		if [ -z "${CATEGORY}" ] || [ -z "${SBNAME}" ]; then
			# should this be a total fail ?
			echo "Category or SBname not set."
			continue
		fi
		buildpkg "${CATEGORY}" "${SBNAME}"
	done # for PKG in PKGLIST
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

	return 0
} # show_help

# desc: sync source
# note: wtf was/is purpose of this one? :)
syncsrc() {
	XXX=""
	cd "${PREFIX}"
	if [ ! -d "${XXX}" ]; then
		mkdir "${XXX}"
	fi
	cd "${XXX}"
	RC=0
	SLACKMIRRORLINK="${SLACKMIRROR}/${SLACKDIR}/source/"
	/usr/bin/wget -m "${SLACKMIRRORLINK}" -o 'source' || RC=1
	return ${RC}
} # syncsrc

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
				echo "Invalid option - '${OPTARG}."
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
	one)
		if [ -z "${CATEGORY}" ] || [ -z "${SBNAME}" ]; then
			echo "Category or Package is unset."
			exit 2
		fi
		buildpkg "${CATEGORY}" "${SBNAME}"
		;;
	all)
		buildall
		;;
	profile)
		if [ -z "${PROFILE}" ]; then
			echo "Profile is unset."
			exit 2
		fi
		buildprofile "${PROFILE}"
		;;
	\?)
		echo "Invalid action - ${ACTION}"
		show_help
		exit 255
		;;
	*)
		echo "Invalid action - ${ACTION}"
		show_help
		exit 255
		;;
esac # case $ACTION

echo "Everything done."
rm -rf "${LOGFILE}"

