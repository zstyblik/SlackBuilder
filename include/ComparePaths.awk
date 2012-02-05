#!/usr/bin/awk -f
# 2012/Jan/01 @ Zdenek Styblik
# Desc: AWK script to show diff between two given paths.
# Presumption is the first argument is a path deep in repository, the
# second argument is path only to the repository.
# NOTE: make sure paths end with '/'. After all, they point to directories.
# Example: 
# * 1: /usr/src/repo/slackware64-13.37/slackware64/a/ 
# * 2: /usr/src/repo/slackware64-13.37/
BEGIN { 
	if (ARGC < 3) {
		exit 1;
	}
	path1=ARGV[1];
	path2=ARGV[2];
	len1=length(path1);
	len2=length(path2);
#	printf("%i:%i\n", len1, len2);
	if (len1 < len2) {
		pathTmp=path1;
		path1=path2;
		path2=pathTmp;
	}
#	printf("p1:%s\n", path1);
#	printf("p2:%s\n", path2);
	while (path1 != "") {
		index1=index(path1, "/");
		if (index1 == 0) {
			index1=length(path1)+1;
		}
		index2=index(path2, "/");
		if (index2 == 0) {
			index2 = length(path2)+1;
		}
		chunk1=substr(path1, 0, index1-1);
		chunk2=substr(path2, 0, index2-1);
#		printf("c1:c2:%s:%s\n", chunk1, chunk2);
		if (chunk1 != chunk2) {
			break;
		}
		path1=substr(path1, index1+1);
		path2=substr(path2, index2+1);
#		printf("path1:%s\n", path1);
	}
	printf("%s\n", path1);
}
