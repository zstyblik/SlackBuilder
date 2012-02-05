#!/bin/sh
# 2011/Jan/28 @ Zdenek Styblik
# Desc: Script to manipulate repository
#
# ---
# Command composition:
# $0 [OPTS] <action>
# $0 add $PATH_TO_PKG $WHERE_TO_PUT_IT_IN_REPO
# $0 add repo-stage/k/kernel-huge-x.y.z-x86_64-1.txz k/
# $0 delete kernel-huge-x.y.z-x86_64-1.txz k/
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

get_pkg_suffix() {
	ARG1=${1:-''}
	if [ -z "${ARG1}" ]; then
		printf ''
		return 1
	fi
	# No, % basename; won't allow '.t?z' as a suffix
	PKG_SUFFIX='.txz'
	if printf "%s" "${ARG1}" | grep -e '.tgz$' ; then
		PKG_SUFFIX='.tgz'
	fi
	printf "%s" "${PKG_SUFFIX}"
	return 0
} # get_pkg_suffix()

print_help() {
	printf "HELP, write me!\n"
	return 0
} # print_help

# Desc: add package into repository
# check whether package is already int SQLite DB; if it is
#  * delete old pkg from db, move it to /TMP as $(mktemp)
#  * if instructed, try to clean previous versions as well
#  * insert new pkg, move new pkg into repo
#  * clean-up - delete old packages
repo_add() {
	PKG_TO_ADD=${1:-''} # Path to package to be added
	REPO_PATH=${2:-''} # Category+series
	if [ -z "${PKG_TO_ADD}" ] || [ -z "${REPO_PATH}" ]; then
		printf "repo_add(): Either PACKAGE or REPO_PATH is empty.\n" 1>&2
		return 1
	fi
	if [ ! -e "${PKG_TO_ADD}" ]; then
		printf "repo_add(): File '%s' doesn't exist.\n" "${PKG_TO_ADD}" 1>&2
		return 1
	fi
	if ! sqlite_exists ; then
		if ! sqlite_init ; then
			printf "repo_add(): Failed to init SQLite DB '%s'.\n" "${SQL_DB}" 1>&2
			return 1
		else
			printf "repo_add(): Initialized SQLite DB '%s'.\n" "${SQL_DB}"
		fi
	fi
	#
	PKG_SUFFIX=$(get_pkg_suffix "${PKG_TO_ADD}")
	PKG_BASE=$(basename "${PKG_TO_ADD}" "${PKG_SUFFIX}")
	PKG_BASEDIR=$(dirname "${PKG_TO_ADD}")
	#
	TARGET_DIR="${REPO_DIR}/${SLACKVER}/${REPO_PATH}/"
	if printf "%s" "${REPO_PATH}" | grep -q -e '^/' ; then
		# Full-path given ?
		TARGET_DIR=$REPO_PATH
	fi # if printf "%s" "${REPO_PATH}" ,,,
	if [ ! -d "${TARGET_DIR}" ]; then
		if ! mkdir -p "${TARGET_DIR}"; then
			printf "repo_add(): Unable to create directory '%s'.\n" \
				"${TARGET_DIR}" 1>&2
			exit 1
		fi
	fi # if [ ! -d "${TARGET_DIR}" ]; then
	APPL=''
	VERSION=''
	MD5SUM=''
	if [ -e "${PKG_BASEDIR}/${PKG_BASE}.pkgdesc" ]; then
		APPL=$(grep -e '^APPL ' "${PKG_BASEDIR}/${PKG_BASE}.pkgdesc" | \
			awk -F ' ' '{ print $2 }')
		VERSION=$(grep -e '^VERSION ' "${PKG_BASEDIR}/${PKG_BASE}.pkgdesc" | \
			awk -F ' ' '{ print $2 }')
		MD5SUM=$(grep -e '^MD5SUM ' "${PKG_BASEDIR}/${PKG_BASE}.pkgdesc" | \
			awk -F ' ' '{ print $2 }')
	else
		# TODO: unless instructed to create .pkgdesc, do "nothing" and assume it is
		# a regular file
		APPL='unknown'
		VERSION='unknown'
		MD5SUM=$(md5sum "${PKG_TO_ADD}" | cut -d ' ' -f 1)
	fi # if [ -e "${PKG_BASE}.pkgdesc" ]; then
	# This should be either 0 or 1
	CONFL_COUNT=$(sqlite3 "${SQL_DB}" "SELECT COUNT(appl) FROM repo WHERE \
		appl = '${APPL}' AND version = '${VERSION}' AND repo_path =	'${REPO_PATH}';")
	if [ "${CONFL_COUNT}" != "0" ] || \
		[ -e "${TARGET_DIR}/${PKG_BASE}.${PKG_SUFFIX}" ]; then
		# TODO - remove previous versions of package and so on
		printf "Not Implemented\n"
	fi
	sqlite3 "${SQL_DB}" "INSERT INTO repo (appl, version, name, repo_path, checksum) \
	VALUES ('${APPL}', '${VERSION}', '${PKG_BASE}', \
	'${REPO_PATH}/${PKG_BASE}${PKG_SUFFIX}', 'MD5#${MD5SUM}');"
	if [ ! -d "${TARGET_DIR}" ]; then
		mkdir -p "${TARGET_DIR}"
	fi
	cp "${PKG_TO_ADD}" "${TARGET_DIR}/"
	# TODO - remove "original" we've just added into repository
	if [ ${RM_ORG_PKG} -eq 1 ]; then
		rm -f "${PKG_TO_ADD}"
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
	PKG_BASE=$(basename "${REPO_PATH}" "${PKG_SUFFIX}")
	PKG_BASEDIR=$(dirname "${REPO_PATH}")
	#
	TARGET_DIR="${REPO_DIR}/${SLACKVER}/${PKG_BASEDIR}/${PKG_BASE}"
	if printf "%s" "${REPO_PATH}" | grep -q -e '^/' ; then
		# Full-path given ?
		TARGET_DIR="${PKG_BASEDIR}/${PKG_BASE}"
		pushd "${REPO_DIR}/${SLACKVER}/" >/dev/null
		REPO_DIR_EXT=$(pwd)
		popd >/dev/null
		REPO_PATH=$(awk -f "${PREFIX}/include/ComparePaths.awk" "${PKG_BASEDIR}/" \
			"${REPO_DIR_EXT}/")
		if [ -z "${REPO_PATH}" ]; then
			REPO_PATH="/"
		fi # if [ ! -z "${REPO_PATH_NEW}" ]; then
	fi # if printf "%s" "${REPO_PATH}" | grep -q -e '^/'
	if [ -e "${TARGET_DIR}.${PKG_SUFFIX}" ]; then
		printf "repo_delete(): File '%s' doesn't not exist.\n" \
			"${TARGET_DIR}.${PKG_SUFFIX}" 1>&2
		return 1
	fi
	TMP=$(mktemp -q -p "${TMP_PREFIX}" -d || true)
	if [ -z "${TMP}" ]; then
		printf "Failed to create temporary directory.\n" 1>&2
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
	sqlite3 "${SQL_DB}" "DELETE FROM repo WHERE name = '${PKG_BASE}' AND \
		repo_path = '${REPO_PATH}/${PKG_BASE}${PKG_SUFFIX}';"
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
sqlite_init() {
	RC=1
	SQL_DIR=$(dirname "${SQL_DB}")
	if [ ! -d "${SQL_DIR}" ]; then
		if ! mkdir -p "${SQL_DIR}" ; then
			printf "sqlite_init(): Unable to create directory '%s'.\n" \
				"${SQL_DIR}" 1>&2
			exit 1
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

# check whether SQLite DB exists; if not, create it

### MAIN
ACTION=${1:-''}
# Remove original of package we are adding
RM_ORG_PKG='0'


case "${ACTION}" in
	'add')
		ARG2=${2:-''}
		ARG3=${3:-''}
		if [ -z "${ARG2}" ] || [ -z "${ARG3}" ]; then
			printf "Missing an argument.\n" 1>&2
			# TODO - show ADD specific help
			exit 1
		fi
		if [ "${ARG2}" = 'help' ]; then
			# TODO
			exit 0
		fi
		repo_add "${ARG2}" "${ARG3}"
		;;
	'delete')
		ARG2=${2:-''}
		ARG3=${3:-''}
		if [ -z "${ARG2}" ]; then
			printf "Missing an argument.\n" 1>&2
			# TODO - show DELETE specific help
			exit 1
		fi
		if [ ! -z "${ARG3}" ]; then
			# TODO
			exit 0
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
