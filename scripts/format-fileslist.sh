#!/bin/bash
cat /dev/null > my.out
for LINE in $(head -n 50 repo/slackware64-13.1/FILELIST.TXT | \
	sed 's/ /@/g'); do
	RIGHTS="$(printf "%s" ${LINE} | cut -d '@' -f 1)"
	LINKS="$(printf "%s" ${LINE} | cut -d '@' -f 2)"
	FUID="$(printf "%s" ${LINE} | cut -d '@' -f 3)"
	FGID="$(printf "%s" ${LINE} | cut -d '@' -f 4)"
	SIZE="$(printf "%s" ${LINE} | cut -d '@' -f 5)"
	DATE="$(printf "%s" ${LINE} | cut -d '@' -f 6)"
	TIME="$(printf "%s" ${LINE} | cut -d '@' -f 7)"
	FILE="$(printf "%s" ${LINE} | cut -d '@' -f 8-)"
	printf "%s %3i %s %s %10i %s %s %s\n" ${RIGHTS} ${LINKS} ${FUID} \
		${FGID} ${SIZE} ${DATE} ${TIME} ${FILE} >> my.out
done

