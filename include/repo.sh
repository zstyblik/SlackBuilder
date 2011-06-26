#!/bin/bash

generate_checksums_md5()
{
	DIRECTORY=${1:-'./'}
	find $DIRECTORY -exec md5sum {} \; 2>/dev/null
	return 0
}
# Desc: format FILELIST.TXT
# $DIRETORY: str;
# @return: Bool
format_filelist()
{
	DIRECTORY=${1:-''}
	if [ -z "${DIRECTORY}" ] || [ ! -e "${DIRECTORY}" ]; then
		printf "[FAIL] File '%s' doesn't exist or empty." "${DIRECTORY}"
		return 1
	fi
	cat /dev/null > "${DIRECTORY}/FILELIST.TXT"
	find "${DIRECTORY}" -exec ls -lad {} \; | sed 's/ /@/g' | while read LINE; do
		RIGHTS=$(printf "%s" "${LINE}" | cut -d '@' -f 1)
		LINKS=$(printf "${LINE}" | cut -d '@' -f 2)
		FUID=$(printf "${LINE}" | cut -d '@' -f 3)
		FGID=$(printf "${LINE}" | cut -d '@' -f 4)
		SIZE=$(printf "${LINE}" | cut -d '@' -f 5)
		DATE=$(printf "${LINE}" | cut -d '@' -f 6)
		TIME=$(printf "${LINE}" | cut -d '@' -f 7)
		FILE=$(printf "${LINE}" | cut -d '@' -f 8-)
		printf "%s xXx%s %3i %s %s %10i %s %s %s\n" "${FILE}" \
			"${RIGHTS}" "${LINKS}" "${FUID}" "${FGID}" "${SIZE}" \
			"${DATE}" "${TIME}" "${FILE}" >> "${DIRECTORY}/FILELIST.TXT.tmp"
	done
	column -c 8 -t "${DIRECTORY}/FILELIST.TXT.tmp" > "${DIRECTORY}/FILELIST.TXT"
	rm -f "${DIRECTORY}/FILELIST.TXT.tmp"
	return 0
} # format_filelist

