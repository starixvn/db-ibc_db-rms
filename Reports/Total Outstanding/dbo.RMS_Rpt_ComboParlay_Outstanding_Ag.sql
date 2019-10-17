/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

 ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Outstanding_Ag]
	@custid		INT,	
	@selection	VARCHAR(100) = '',
	@sporttype	VARCHAR(100) = '',
	@ParlayType	VARCHAR(10)=''
AS
	/*
		Created: Winnie
		Date: 2016-04-27
		Task: Get combo parlay betlist running by agent
		DB: DBRMS/bodb_RMS
		
		Revisions:
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		-20190214@Jacob: Add Bet Builder RedmineID: #108694
		Parameter's Explanation:
			-@sporttype = 0 : all sports
						= 1 : soccer only
						= 2 : Other sports
						= 3 : combined sports
	   - @ParlayType = 1: Mix parlay
							2: Combo parlay
							3: Single Match Parlay
	*/
SET NOCOUNT ON	
	DECLARE @tmpSelection TABLE (selection int)
	DECLARE @tmpSport TABLE (sporttype int)
	DECLARE @10up varchar(500)
	DECLARE @all varchar(500)

	DECLARE @IsMixParlay BIT = 0, @IsComboParlay BIT = 0, @IsSingleMatchParlay BIT = 0
	SELECT  @IsMixParlay = CASE WHEN CHARINDEX('1', @ParlayType) > 0 THEN 1 ELSE 0 END,
		   @IsComboParlay = CASE WHEN CHARINDEX('2', @ParlayType) > 0 THEN 1 ELSE 0 END,
		   @IsSingleMatchParlay = CASE WHEN CHARINDEX('3', @ParlayType) > 0 THEN 1 ELSE 0 END

	INSERT INTO @tmpSelection
	SELECT val
	FROM f_RMS_strSplit (@selection,',')
	
		--Check selection is 10-UP
	IF EXISTS(SELECT TOP 1 1 FROM @tmpSelection WHERE selection = 0)
	BEGIN
		SELECT @all = '2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'
		DELETE FROM @tmpSelection
		INSERT INTO @tmpSelection
		SELECT val
		FROM f_RMS_strSplit (@all,',')		
	END
	ELSE IF EXISTS(SELECT TOP 1 1 FROM @tmpSelection WHERE selection = 10)
	BEGIN
		SELECT @10up = '11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100'

		INSERT INTO @tmpSelection
		SELECT val
		FROM f_RMS_strSplit (@10up,',')		
	END	
	
	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	IF EXISTS (SELECT TOP 1 1 FROM @tmpSport WHERE sporttype=-2)
	BEGIN
	INSERT INTO @tmpSport
	SELECT SportType FROM bodb02.dbo.Sports(NOLOCK) WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
	END	
				
		SELECT custid,
			username,
			SUM(stake*actualrate*(1-tpositiontaking)) as stakePT,
			SUM(stake*actualrate*(odds2-1)*(1-tpositiontaking)) as net_win,
			COUNT(1) as betcount--,
			--CASE WHEN c.SportType NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43) THEN -2 ELSE c.sporttype END AS Sporttype
		FROM rmBettrans a WITH(NOLOCK)
		INNER JOIN @tmpSelection b ON a.hdp2=b.selection
		INNER JOIN @tmpSport c ON a.transid2=c.sporttype
		WHERE recommend = @custid			
			AND statusid = 0
			AND ((@IsMixParlay=1 AND betteam ='1' AND bettype=29 AND matchid = 29 ) OR (@IsComboParlay= 1 AND bettype=29 AND betteam <>'1' AND matchid = 29) OR (@IsSingleMatchParlay=1 AND bettype=38))		
		GROUP BY custid,username--,CASE WHEN c.SportType NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43) THEN -2 ELSE c.sporttype END
		ORDER  BY net_win DESC 
		
	

GO