#!/bin/bash
set -e
set -u

DIRECTORY=${1:-'./'}

find $DIRECTORY -exec ls -lad {} \; | sed 's/ /@/g' | while read LINE; do
	RIGHTS=$(echo $LINE | cut -d '@' -f 1)
	LINKS=$(echo $LINE | cut -d '@' -f 2)
	FUID=$(echo $LINE | cut -d '@' -f 3)
	FGID=$(echo $LINE | cut -d '@' -f 4)
	SIZE=$(echo $LINE | cut -d '@' -f 5)
	DATE=$(echo $LINE | cut -d '@' -f 6)
	TIME=$(echo $LINE | cut -d '@' -f 7)
	FILE=$(echo $LINE | cut -d '@' -f 8-)
	printf "%s xXx%s %3i %s %s %10i %s %s %s\n" "${FILE}" "${RIGHTS}" "${LINKS}" \
	"${FUID}" "${FGID}" "${SIZE}" "${DATE}" "${TIME}" "${FILE}"
done

