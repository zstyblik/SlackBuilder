#!/bin/bash
# 2010/07/28 @ Zdenek Styblik

# ToDo:
# * speed up re-generation, especially MD5-sums
#	* ISO is going to carry tag files along
# * an ISO is missing dist pkgs !!!
#
set -e
set -u

PREFIXDIR="/mnt/slackrepo/slackware.tfn/"
REPOBAREDIR="${PREFIXDIR}/repo-bare/"
REPODIR="${PREFIXDIR}/repo/"
SLACKDISTDIR="/mnt/cdrom/"
SLACKVER="slackware64-13.1"
TMPDIR=${TMPDIR:-"/mnt/tmp/slackrepo/"}
SCRIPTNAME="${0}"
PREFIX="$(dirname "${SCRIPTNAME}")"

SLACKSUFFIX=""
printf "${SLACKVER}" | grep -q -e 'slackware64' && SLACKSUFFIX=64

# Helpers
CPPARAMS=''
DOMD5=0
DOFILELIST=0
DOISO=0
DOPURGE=0

. "${PREFIX}/include/repo.sh"

# desc: creates bootable ISO.
make_iso() {
	if [ ! -d isolinux ]; then
		return 1
	fi
	if [ ! -e isolinux/iso.sort ]; then
		return 1
	fi
	if [ ! -e isolinux/isolinux.bin ]; then
		return 1
	fi
	echo "Creating an ISO image ..."
	mkisofs -o "../${SLACKVER}-tfn-mod.iso" \
		-R -J -A "${SLACKVER} TFN" \
		-hide-rr-moved \
		-v -d -N \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-sort isolinux/iso.sort \
		-b isolinux/isolinux.bin \
		-c isolinux/isolinux.boot \
		-V "Slackware" .

	cd ../
	md5sum "${SLACKVER}-tfn-mod.iso" > "${SLACKVER}-tfn-mod.iso.md5"
	return 0
} # make_iso
# desc: prints help
show_help() {
	cat << HELP
Whatever this is :: 2010 :: Zdenek Styblik

Parameters:
	-5	generate CHECKSUMS.md5 files
	-d	diff; copy-over only pkgs that got changed
	-f	generate FILELIST files
	-h	print this help
	-i	make ISO out of repo
	-p	purge; delete repo and start from scratch
	-t	use tag files
HELP
	return 0
} # function help

### MAIN ###
while getopts "5dfhip" ARG; do
	case "${ARG}" in
		5)
			DOMD5=1
			;;
		d)
			CPPARAMS=-u
			;;
		f)
			DOFILELIST=1
			;;
		h)
			show_help
			exit 1
			;;
		i)
			DOISO=1
			;;
		p)
			DOPURGE=1
			;;
		\?)
			echo "Invalid option - $OPTARG."
			show_help
			exit 255
			;;
		:)
			echo "Option $OPTARG requires argument."
			show_help
			exit 255
			;;
	esac
done

if [ ${DOPURGE} -eq 0 ] && [ -z ${CPPARAMS} ]; then
	echo "I don't know what to do."
	help
	exit 1
fi

DESTDIR="${REPODIR}/${SLACKVER}"

if [ ${DOPURGE} -eq 1 ]; then
	echo "Wiping out an old repo..."
	rm -rf "${DESTDIR}";
fi

if [ ! -d "${DESTDIR}" ]; then
	mkdir -p "${DESTDIR}";
fi

echo "Copying /slackware${SLACKSUFFIX}"
cp ${CPPARAMS} -r "${SLACKDISTDIR}/slackware${SLACKSUFFIX}" \
	"${DESTDIR}/"
# FUCK EXTRA, it's a broken dir! I'm going to deal with you later ... with hammer
#echo "Copying /extra"
#cp ${CPPARAMS} -r $SLACKDISTDIR/extra $REPODIR/$SLACKVER/
if [ ! -d "${DESTDIR}/extra" ]; then
	echo "Creating directory /extra"
	mkdir "${DESTDIR}/extra" || true
fi

echo "Copying /isolinux"
cp ${CPPARAMS} -fur "${SLACKDISTDIR}/isolinux" "${DESTDIR}"
echo "Copying /kernels"
cp ${CPPARAMS} -fur "${SLACKDISTDIR}/kernels" "${DESTDIR}"
echo "Copying /patches"
cp ${CPPARAMS} -fur "${SLACKDISTDIR}/patches" "${DESTDIR}"

for CATEGORY in $(ls -1 "${REPOBAREDIR}/${SLACKVER}/"); do
	if [ ! -d "${DESTDIR}/slackware${SLACKSUFFIX}/$CATEGORY/" ]; then
		echo "Will create category $CATEGORY..."
		mkdir -p "${DESTDIR}/slackware${SLACKSUFFIX}/$CATEGORY/";
	fi
	for PKG in $(ls "${REPOBAREDIR}/${SLACKVER}/${CATEGORY}"); do
		# TODO: remove other resp. dist version of pkg!!!
		echo "Copying $CATEGORY/$PKG..."
		cp ${CPPARAMS} ${REPOBAREDIR}/${SLACKVER}/${CATEGORY}/${PKG}/* \
			"${DESTDIR}/slackware${SLACKSUFFIX}/${CATEGORY}/";
	done
done

# Modification of 'maketag'
# * menu ~ number of line '2> $TMP' and append new pkgs
# * pkg-list
#   * 1 ~ number of line 'for pkg in \' replace '\$'
#   * 2 ~ number of line 'for PACKAGE in \' replace '\$'
#   with new packages and end list with '\'
# Modification of 'setpkg'
# * find number of line '2> $TMP/SeTSERIES' and append own or new serie there

pushd "${DESTDIR}"
date > ChangeLog.txt
popd

if [ ! -d "${TMPDIR}" ]; then
	mkdir "${TMPDIR}"
fi

# mktemp && etc.
if [ ${DOFILELIST} -eq 1 ]; then
	echo "Generating FILELISTs..."
	printf "Generating FILELIST.TXT for './'..."
	if $(format_filelist './'); then
		printf "[ OK ]\n"
	else 
		printf "[ FAIL ]\n"
	fi

	pushd "slackware${SLACKSUFFIX}"
	printf "Generating FILELIST.TXT for 'slackware%s'..." "${SLACKSUFFIX}"
	if $(format_filelist './'); then
		printf "[ OK ]\n"
	else 
		printf "[ FAIL ]\n"
	fi
	popd
fi
# CHECKSUMS.md5
if [ ${DOMD5} -eq 1 ]; then
	pushd "${DESTDIR}"
	echo "Generating CHECKSUMS..."
	bash "/${PREFIXDIR}/scripts/generate-checksums.sh" ./ > \
		"${TMPDIR}./${SLACKVER}-CHECKSUMS.md5"

	mv "${TMPDIR}./${SLACKVER}-CHECKSUMS.md5" CHECKSUMS.md5
	cd "slackware${SLACKSUFFIX}"
	bash "/${PREFIXDIR}/scripts/generate-checksums.sh" ./ > \
		"${TMPDIR}./${SLACKVER}-CHECKSUMS.md5"

	mv "${TMPDIR}./${SLACKVER}-CHECKSUMS.md5" CHECKSUMS.md5
	popd
fi

if [ ${DOISO} -eq 1 ]; then
	pushd "${DESTDIR}"
	make_iso
	popd
fi

