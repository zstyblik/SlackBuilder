-- Example of data:
--  appl: wine
--  version: 1.3.7
--  name: wine-1.3.7-x86_64-1alien
--  path: slackware64/xap/wine-1.3.7-x86_64-1alien
--  checksum: MD5#5483e192e6fbdc95c8eaf9ed46d61e70 -> ALGO:HASH
--
CREATE TABLE repo (
	appl TEXT,
	version TEXT,
	name TEXT, 
	repo_path TEXT, 
	checksum TEXT
);
