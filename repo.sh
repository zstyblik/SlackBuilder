#!/bin/sh
# 2011/Jan/28 @ Zdenek Styblik
# Desc: Script to manipulate repository
#
# ---
# Command composition:
# $0 [OPTS] <action>
# $0 add $PATH_TO_PKG $WHERE_TO_PUT_IT_IN_REPO
# $0 add repo-stage/k/kernel-huge-x.y.z-x86_64-1.txz slackware64/k/
#
# $0 delete $PATH_TO_PKG_TO_DELETE
# $0 delete /usr/src/repo/slackware64/k/kernel-huge-x.y.z-x86_64-1.txz
#
# ---
# Package name dissected: 
# wine      - 1.3.37  - x86_64 - 1alien
# appl name - version - arch   - build+author
#
# Conclusion based on dissection:
#   It should be safe to strip the last two chunks of '-' from package name.
# Result should be appl_name-version. However, since there are no naming
# conventions eg. '1.3.37-p1' and 'wine-server' are possible, it is impossible
# to tell 'appl_name' and 'version' apart. And this, ultimately, leads to
# creation of external description file. Call it '.pkgdesc' or whatever you
# like.
#
# ---
# .pkgdesc format is KEY_whitespace_VALUE:
# ~~~
# APPL wine
# VERSION 1.3.37
# CHECKSUM MD5#5483e192e6fbdc95c8eaf9ed46d61e70
# ~~~
# These keys are used so far, because the rest can be obtained from command
# line.
#
# ---
# On package signing:
# 
# http://allanmcrae.com/2011/12/pacman-package-signing-4-arch-linux/
#
# Packages should be signed when added to repo. They can be signed by their
# author resp. person whom built the package. However only for purpose of
# authentification, not for adding into repository.
# Package added into repository should be signed by person whom adds package
# into repository.
#
# My $0.02 USD
#
# ---
#
set -e
set -u

PREFIX=$(dirname "${0}")
if [ ${PREFIX} = '.' ]; then
	PREFIX=$(pwd)
fi

. "${PREFIX}/include/slackbuilder-conf.sh"

SQL_DB=$(printf "%s/%s/%s.sq3" "${REPO_DIR}" "${SLACKVER}" "${SLACKVER}")
SQL_REPO_TMPL="${PREFIX}/include/repo.sql"

# Desc: determine file's suffix resp. pkg's suffix.
# @ARG1: file to examine
# $returns: .tgz, .txz or an empty string
get_pkg_suffix() {
	ARG1=${1:-''}
	if [ -z "${ARG1}" ]; then
		printf ''
		return 1
	fi
	# No, % basename; won't allow '.t?z' as a suffix
	PKG_SUFFIX=''
	if printf "%s" "${ARG1}" | grep -q -e '.tgz$' ; then
		PKG_SUFFIX='.tgz'
	fi
	if printf "%s" "${ARG1}" | grep -q -e '.txz$' ; then
		PKG_SUFFIX='.txz'
	fi
	printf "%s" "${PKG_SUFFIX}"
	return 0
} # get_pkg_suffix()
# Desc: print help text.
print_help() {
	cat << HELP

	$0 - Slackware repository maintenance

	Usage:
	% $0 add <PATH_TO_PKG> <IN_REPOSITORY_PATH> ;
	% $0 delete <PATH_TO_FILE_TO_REMOVE> ;

	Examples:
	% $0 add repo-stage/k/kernel-huge-x.y.z-x86_64-1.txz slackware64/k/ ;
	% $0 delete /usr/src/repo/slackware64/k/kernel-huge-x.y.z-x86_64-1.txz ;

HELP

	return 0
} # print_help

# Desc: add FILE into repository
# check whether FILE is already in SQLite DB; if it is
#  * delete old FILE from db, move it to /TMP as $(mktemp)
#  * if instructed, try to clean previous versions as well
#  * insert new FILE into DB, move new FILE into repo
#  * clean-up - delete old FILES in /TMP
# @FILE_TO_ADD: path to FILE to be added
# @INREPO_PATH: where to put FILE in repo structure eg. 'slackware64/xap/'
repo_add() {
	FILE_TO_ADD=${1:-''}
	INREPO_PATH=${2:-''}
	if [ -z "${FILE_TO_ADD}" ] || [ -z "${INREPO_PATH}" ]; then
		printf "repo_add(): Either PACKAGE or INREPO_PATH is empty.\n" 1>&2
		return 1
	fi
	if [ ! -e "${FILE_TO_ADD}" ]; then
		printf "repo_add(): File '%s' doesn't exist.\n" "${FILE_TO_ADD}" 1>&2
		return 1
	fi
	#
	PKG_SUFFIX=$(get_pkg_suffix "${FILE_TO_ADD}")
	PKG_BASENAME=$(basename "${FILE_TO_ADD}" "${PKG_SUFFIX}")
	PKG_BASEDIR=$(dirname "${FILE_TO_ADD}")
	#
	TARGET_DIR="${REPO_DIR}/${SLACKVER}/${INREPO_PATH}/"
	if printf "%s" "${INREPO_PATH}" | grep -q -e '^/' ; then
		# Full-path given? Whatever you say, captain.
		TARGET_DIR=$INREPO_PATH
		#
		pushd "${REPO_DIR}/${SLACKVER}/" >/dev/null
		REPO_DIR_EXT=$(pwd)
		popd >/dev/null
		#
		INREPO_PATH=$(awk -f "${PREFIX}/include/ComparePaths.awk" "${PKG_BASEDIR}/" \
			"${REPO_DIR_EXT}/")
		if [ -z "${INREPO_PATH}" ]; then
			INREPO_PATH="/"
		fi # if [ ! -z "${INREPO_PATH}" ]; then
	fi # if printf "%s" "${INREPO_PATH}" ,,,
	if [ ! -d "${TARGET_DIR}" ]; then
		if ! mkdir -p "${TARGET_DIR}"; then
			printf "repo_add(): Unable to create directory '%s'.\n" \
				"${TARGET_DIR}" 1>&2
			return 1
		fi
	fi # if [ ! -d "${TARGET_DIR}" ]; then
	#
	APPL=''
	VERSION=''
	CHECKSUM=''
	if [ -e "${PKG_BASEDIR}/${PKG_BASENAME}.pkgdesc" ]; then
		APPL=$(grep -e '^APPL ' "${PKG_BASEDIR}/${PKG_BASENAME}.pkgdesc" | \
			awk -F ' ' '{ print $2 }')
		VERSION=$(grep -e '^VERSION ' "${PKG_BASEDIR}/${PKG_BASENAME}.pkgdesc" | \
			awk -F ' ' '{ print $2 }')
		CHECKSUM=$(grep -e '^CHECKSUM ' "${PKG_BASEDIR}/${PKG_BASENAME}.pkgdesc" | \
			awk -F ' ' '{ print $2 }')
		#
		if grep -e '^CHECKSUM ' "${PKG_BASEDIR}/${PKG_BASENAME}.pkgdesc" | \
			grep -q -e 'MD5#' ; then
			#
			MD5SUM_EXT=$(md5sum "${FILE_TO_ADD}" | cut -d ' ' -f 1)
			MD5SUM_EXT="MD5#${MD5SUM_EXT}"
			if [ "${CHECKSUM}" != "${CHECKSUM_EXT}" ]; then
				printf "ERRO: MD5 sums do not match.\n" 1>&2
				return 1
			fi # if [ "${CHECKSUM}" != "${MD5SUM_EXT}" ]; then
		fi # if grep -q -e '^CHECKSUM' ...
		if [ -z "${APPL}" ]; then
			printf "ERRO: APPL is empty! Unable to continue.\n"
			return 1
		fi
		if [ -z "${VERSION}" ]; then
			VERSION='unknown'
			printf "WARN: VERSION is empty! Will be set to '%s'!\n" "${VERSION}"
		fi
	else
		# Note: perhaps we want to add eg. README file or such
		printf "WARN: File '%s' doesn't exist.\n" \
			"${PKG_BASEDIR}/${PKG_BASENAME}.pkgdesc" 1>&2
		APPL=$PKG_BASENAME
		VERSION='unknown'
		CHECKSUM=$(md5sum "${FILE_TO_ADD}" | cut -d ' ' -f 1)
		CHECKSUM="MD5#${CHECKSUM}"
	fi # if [ -e "${PKG_BASENAME}.pkgdesc" ]; then

	if [ -z "${CHECKSUM}" ]; then
		printf "ERRO: CHECKSUM is empty! Unable to continue.\n"
		return 1
	fi

	SQL_REPO_PATH=$(printf "%s/%s%s" "${INREPO_PATH}" "${PKG_BASENAME}" \
		"${PKG_SUFFIX}" | sed -r -e 's@/+@/@g')
	# This should be either 0 or 1
	CONFL_COUNT=$(sqlite3 "${SQL_DB}" "SELECT COUNT(appl) FROM repo WHERE \
		appl = '${APPL}' AND repo_path =	'${SQL_REPO_PATH}';")
	if [ "${CONFL_COUNT}" != "0" ] || \
		[ -e "${TARGET_DIR}/${PKG_BASENAME}.${PKG_SUFFIX}" ]; then
		# TODO - remove previous versions of package and so on
		printf "Not Implemented\n"
		return 1
	fi
	sqlite3 "${SQL_DB}" "INSERT INTO repo (appl, version, name, suffix, \
		repo_path, checksum) \
	VALUES ('${APPL}', '${VERSION}', '${PKG_BASENAME}', '${PKG_SUFFIX}', \
	'${SQL_REPO_PATH}', '${CHECKSUM}');"
	if [ ! -d "${TARGET_DIR}" ]; then
		mkdir -p "${TARGET_DIR}"
	fi
	cp "${FILE_TO_ADD}" "${TARGET_DIR}/"
	# Note: remove "original" we've just added into repository
	if [ ${RM_ORG_PKG} -eq 1 ]; then
		printf "INFO: removing '%s'.\n" "${FILE_TO_ADD}"
		rm -f "${FILE_TO_ADD}"
	fi # if [ ${RM_ORG_PKG} -eq 1 ]
	#
	return 0
} # repo_add()

# Desc: health/integrity check of repository
repo_scan() {
	# More like % find ./ ; or % find ./ -name '*.t?z'; and check SQLite for infos
	return 0
} # repo_scan()

# Desc: remove package from repository
# REPO_PATH=/mnt/repo/slackware64-13.37/slackware64/xap/wine-1.3.37-x86_64-1alien.txz
repo_delete() {
	REPO_PATH=${1:-''}
	if [ -z "${REPO_PATH}" ]; then
		printf "repo_delete(): PKG_PATH '%s' is empty.\n" "${REPO_PATH}" 1>&2
		return 1
	fi # if [ -z "${REPO_PATH}" ]
	#
	PKG_SUFFIX=$(get_pkg_suffix "${REPO_PATH}")
	PKG_BASENAME=$(basename "${REPO_PATH}" "${PKG_SUFFIX}")
	PKG_BASEDIR=$(dirname "${REPO_PATH}")
	#
	TARGET_DIR="${REPO_DIR}/${SLACKVER}/${PKG_BASEDIR}/${PKG_BASENAME}"
	if printf "%s" "${REPO_PATH}" | grep -q -e '^/' ; then
		# Full-path given
		TARGET_DIR="${PKG_BASEDIR}/${PKG_BASENAME}"
		pushd "${REPO_DIR}/${SLACKVER}/" >/dev/null
		REPO_DIR_EXT=$(pwd)
		popd >/dev/null
		REPO_PATH=$(awk -f "${PREFIX}/include/ComparePaths.awk" "${PKG_BASEDIR}/" \
			"${REPO_DIR_EXT}/")
		if [ -z "${REPO_PATH}" ]; then
			REPO_PATH="/"
		fi # if [ ! -z "${REPO_PATH}" ]; then
	fi # if printf "%s" "${REPO_PATH}" | grep -q -e '^/'
	if [ -e "${TARGET_DIR}.${PKG_SUFFIX}" ]; then
		printf "repo_delete(): File '%s' doesn't not exist.\n" \
			"${TARGET_DIR}.${PKG_SUFFIX}" 1>&2
		return 1
	fi
	SQL_REPO_PATH=$(printf "%s/%s%s" "${REPO_PATH}" "${PKG_BASENAME}" \
		"${PKG_SUFFIX}" | sed -r -e 's@/+@/@g')
	PKGFOUND_COUNT=$(sqlite3 "${SQL_DB}" "SELECT COUNT(appl) FROM repo WHERE \
		repo_path = '${SQL_REPO_PATH}';")
	if [ "${PKGFOUND_COUNT}" != "1" ] && [ $FORCE -eq 0 ]; then
		if [ "${PKGFOUND_COUNT}" == "0" ]; then
			printf "repo_delete(): Package not found in DB.\n" 1>&2
		fi
		printf "repo_delete(): PKGs found %s, expected 1.\n" \
			"${PKGFOUND_COUNT}" 1>&2
		printf "repo_delete(): Perhaps you want to use force.\n" 1>&2
		return 1
	fi
	TMP=$(mktemp -q -p "${TMP_PREFIX}" -d || true)
	if [ -z "${TMP}" ]; then
		printf "repo_delete(): Failed to create temporary directory.\n" 1>&2
		return 1
	fi
	# move PACKAGE and all associated files to TMP directory
	for SUFFIX in tgz txz txt asc md5; do
		if [ ! -e "${TARGET_DIR}.${SUFFIX}" ]; then
			continue
		fi
		printf "INFO: move '%s' to '%s'.\n" "${TARGET_DIR}.${SUFFIX}" "${TMP}"
		mv "${TARGET_DIR}.${SUFFIX}" "${TMP}/"
	done
	# delete PACKAGE from database
	printf "INFO: delete package from SQLite DB.\n"
	sqlite3 "${SQL_DB}" "DELETE FROM repo WHERE name = '${PKG_BASENAME}' AND \
		repo_path = '${SQL_REPO_PATH}';"
	# remote TMP directory
	printf "INFO: clean-up.\n"
	rm -rf "${TMP}"
	return 0
} # repo_delete()

# Desc: check whether SQLite DB file exists
# @returns: True(0) if exists, otherwise False(1)
sqlite_exists() {
	if [ ! -e "${SQL_DB}" ]; then
		return 1
	fi
	return 0
} # sqlite_exists()
# Desc: initialize SQLite DB for Slackware Repository
# $returns: 0 on success, otherwise 1
sqlite_init() {
	RC=1
	SQL_DIR=$(dirname "${SQL_DB}")
	if [ ! -d "${SQL_DIR}" ]; then
		if ! mkdir -p "${SQL_DIR}" ; then
			printf "sqlite_init(): Unable to create directory '%s'.\n" \
				"${SQL_DIR}" 1>&2
			return 1
		fi
	fi # if [ ! -d "${SQL_DIR}" ]; then
	if sqlite3 -init "${SQL_REPO_TMPL}" "${SQL_DB}" '.q' 2>&1 | \
		grep -q -e 'Error' ; then
		RC=1
	else
		RC=0
	fi
	return ${RC}
} # sqlite_init()

### MAIN
ACTION=${1:-''}
FORCE=0
# Remove original of package we are adding
RM_ORG_PKG=0
# Note: check whether SQLite DB exists; if not, create it
if ! sqlite_exists ; then
	if ! sqlite_init ; then
		printf "WARN: Failed to init SQLite DB '%s'.\n" "${SQL_DB}" 1>&2
		return 1
	else
		printf "INFO: Initialized SQLite DB '%s'.\n" "${SQL_DB}"
	fi
fi
#
case "${ACTION}" in
	'add')
		ARG2=${2:-''}
		ARG3=${3:-''}
		if [ $# -gt 3 ]; then
			printf "Too many arguments given.\n" 1>&2
			show_help
			exit 1
		fi
		if [ -z "${ARG2}" ] || [ -z "${ARG3}" ]; then
			printf "Missing an argument.\n" 1>&2
			show_help
			exit 1
		fi
		repo_add "${ARG2}" "${ARG3}"
		;;
	'delete')
		ARG2=${2:-''}
		ARG3=${3:-''}
		if [ $# -gt 2 ]; then
			printf "Too many arguments given.\n" 1>&2
			show_help
			exit 1
		fi
		if [ -z "${ARG2}" ]; then
			printf "Missing an argument.\n" 1>&2
			show_help
			exit 1
		fi
		repo_delete "${ARG2}"
		;;
	'scan')
		repo_scan
		;;
	\?)
		printf "Invalid option - '%s'.\n" "${ACTION}"
		show_help
		exit 255
		;;
	:)
		printf "Option '%s' requires argument.\n" "${ACTION}"
		show_help
		exit 255
		;;
	*)
		print_help
		exit 1
		;;
esac
