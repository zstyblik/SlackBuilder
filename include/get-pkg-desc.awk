#!/usr/bin/awk -f
# 2012/Feb/28 @ Zdenek Styblik
# Desc: parse-out info from Slackware's package name
# Example input: kernel-huge-2.6.35.13-x86_64-1
{
	items = split($0, arr, "-");
	if (items < 4) {
		printf("Invalid input '%s'.\n", $0) > "/dev/stderr";
		exit 1;
	}
	build = arr[items];
	items--;
	arch = arr[items];
	items--;
	version = arr[items];
	items--;
	if (items < 1) {
		printf("Invalid input - items is less than 1.\n") > "/dev/stderr";
		exit 1;
	}
	counter = 2;
	name = arr[1];
	while (counter <= items) {
		name = sprintf("%s-%s", name, arr[counter]);
		counter++;
	}
	printf("APPL %s\n", name);
	printf("VERSION %s\n", version);
	printf("ARCH %s\n", arch);
	printf("BUILD %s\n", build);
}
