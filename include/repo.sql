-- Example of data:
--  appl: wine
--  version: 1.3.7
--  name: wine-1.3.7-x86_64-1alien
--  suffix: .txz
--  repo_path: slackware64/xap/
--  checksum: MD5#5483e192e6fbdc95c8eaf9ed46d61e70 -> ALGO:HASH
--
-- Package, all versions: repo_path + appl
-- Package, zero-in: repo_path + name
-- Package with different suffix is still treated as the same file!
CREATE TABLE repo (
	appl TEXT,
	version TEXT,
	name TEXT,
	suffix TEXT,
	repo_path TEXT,
	checksum TEXT
);
