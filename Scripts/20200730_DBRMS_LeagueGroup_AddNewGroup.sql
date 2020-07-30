/*<info serverAlias="DBRMS-bodb_RMS"></info>*/

/*
	Created: 20200730
	DB: DBRMS-bodb_RMS
	Task: Manage league group
		1. Format league group name (upper text)
		2. Add new league group: Virtual
		3. Add leagues into new league group (Virtual)
*/

USE bodb_RMS
GO

-- SELECT * FROM dbo.rmLeagueGroup WITH (NOLOCK)

-- 1. Format league group name
	-- 8 rows
UPDATE dbo.rmLeagueGroup WITH (ROWLOCK)
SET GroupName = CASE GroupId
					WHEN 1 THEN 'MJ'
					WHEN 2 THEN 'M1'
					WHEN 3 THEN 'M2'
					WHEN 4 THEN 'M3'
					WHEN 5 THEN 'M4 (a)'
					WHEN 6 THEN 'M4 (b)'
					WHEN 7 THEN 'M4 (x)'
					WHEN 8 THEN 'Blacklist'
					ELSE GroupName END
GO

-- 2. Insert new league group
INSERT INTO dbo.rmLeagueGroup (GroupId, GroupName, OrderId)
VALUES (9, 'Virtual', 62)
GO

-- 3. Add leagues into new league group (Virtual)
INSERT INTO dbo.rmLeague (LeagueId, GroupId)
SELECT LeagueId, 9
FROM bodb02.dbo.league WITH (NOLOCK)
WHERE sporttype = 1
	AND isTest = 0
	AND LeagueGroupID = 42 -- 'Virtual' -- SELECT * FROM bodb02.dbo.LeagueGroup WITH (NOLOCK) WHERE GroupName = 'Virtual'
GO