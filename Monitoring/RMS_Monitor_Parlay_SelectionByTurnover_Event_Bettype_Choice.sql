ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Event_Bettype_Choice]
	@bettype		INT = 9,
	@sporttype		INT = 0,	
	@winlostdate	DATETIME,
	@selection		INT = 2,
	@matchid		INT,
	@bettype2		INT,
	@max_transid	BIGINT
AS
	/*
		Created: Johnson
		Date: 20120808
		Task: Get report favourite choice by event and bettype
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20120822@Dan: update for Other bet types
			- 20130123@Johnson: move sp from DB054.bodb02 to DBRMS.bodb_RMS
		Parameter's Explanation:
			- @sporttype = 0 : all sports
							= 1 : soccer only
							= 2 : Other sports
							= 3 : combined sports
			- bettype2 : bettype of event choose
		EXEC RMS_Monitor_Parlay_SelectionByTurnover_Event_Bettype_Choice 9,1,'2012-07-01',3,2207345,1,3780712395

	*/ 
SET NOCOUNT ON
------------------------------
	DECLARE @tmp_Bettrans TABLE (refno bigint primary key, selection int, sporttype int, turnover money)
	DECLARE @tmp_Bettransm TABLE (refno bigint primary key)
	DECLARE @Result TABLE (betteam nvarchar(20), turnover money)

	DECLARE @matchid2	INT,
			@total		MONEY
	
	IF @bettype = 9 
		SELECT @matchid2 = 9
	ELSE IF @bettype = 29 
		SELECT @matchid2 = 29		
		
	INSERT INTO @tmp_Bettrans (refno, selection, sporttype, turnover)
	SELECT refno, right(betcheck,len(betcheck)-1), liveawayscore, actual_stake*actualrate
	FROM rmBettrans WITH(NOLOCK)
	WHERE matchid = @matchid2
		AND statusid = 0
		AND currency <> 20
		AND winlostdate >= @winlostdate
		AND transid <= @max_transid
	
	IF @sporttype <> 0
		DELETE @tmp_Bettrans WHERE sporttype <> @sporttype
	
	DELETE @tmp_Bettrans WHERE selection <> @selection
		
	;WITH T AS (
		SELECT bm.refno, 
			CASE WHEN BETTYPE IN (3,8) THEN bm.betteam + ':' + cast(hdp1 as varchar(10)) 
				ELSE bm.betteam END AS betteam				
		FROM bodb02.dbo.bettransm bm WITH(NOLOCK)
			INNER JOIN @tmp_Bettrans t ON bm.refno = t.refno
		WHERE bm.matchid = @matchid 
			AND bm.bettype = @bettype2
		UNION ALL
		SELECT bm.refno, 
			CASE WHEN BETTYPE IN (3,8) THEN bm.betteam + ':' + cast(hdp1 as varchar(10)) 
				ELSE bm.betteam END AS betteam				
		FROM bodb02.dbo.bettransm14 bm WITH(NOLOCK)
			INNER JOIN @tmp_Bettrans t ON bm.refno = t.refno
		WHERE bm.matchid = @matchid 
			AND bm.bettype = @bettype2
	)
	 
	INSERT INTO @Result (betteam, turnover)
	SELECT betteam, SUM(turnover) turnover
	FROM T t
		INNER JOIN @tmp_Bettrans b ON t.refno = b.refno
	GROUP BY t.betteam
	
	SELECT @total = ISNULL(sum(turnover),0) FROM @Result
	
	DECLARE @TopSelection TABLE (rn int, betteam nvarchar(10), turnover money, margin decimal(5,2))
		
	INSERT INTO @TopSelection (rn, betteam, margin, turnover)	
	SELECT TOP 5
		row_number () over (order by SUM(turnover) DESC),
		betteam, 
		SUM(turnover)/ISNULL(NULLIF(@total,0),1) as margin, 
		SUM(turnover) as turnover		
	FROM @Result
	GROUP BY betteam
	
	INSERT INTO @TopSelection (rn, betteam, margin, turnover)	
	SELECT 6, 'Others',  
		SUM(turnover)/ISNULL(NULLIF(@total,0),1) as margin, 
		SUM(turnover) as turnover		
	FROM @Result
	WHERE betteam NOT IN (SELECT betteam FROM @TopSelection)	
		
	SELECT * 
	FROM @TopSelection
	ORDER BY rn

GO
GRANT VIEW DEFINITION ON  [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Event_Bettype_Choice] TO [vnteam]
GO
GRANT EXECUTE ON  [dbo].[RMS_Monitor_Parlay_SelectionByTurnover_Event_Bettype_Choice] TO [bodbRMSNet]