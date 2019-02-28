/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Similar_ComboParlay_Betlist]
	@transid	BIGINT
AS
	/*
		Created: Winnie
		Date: 2016-04-26
		Task: Get similar bets combo parlay tickets
		DB: DBRMS/bobd_RMS		
		Revisions:
		- 20160927@Winnie: fix issue conflict refno with racing RedmineID: #64286
		- 20170719@Winnie: Add MuayThai RedmineID: #79500
		-20190214@Jacob: Add Bet Builder RedmineID: #108694
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON
	
IF
(
    SELECT ISNULL(statusid, 1)
    FROM rmBettrans WITH (NOLOCK)
    WHERE transid = @transid
) > 0
    RETURN;
DECLARE @Bettype INT, @MatchId INT;
DECLARE @refno BIGINT, @combo INT, @cnt_bets INT, @yesterday DATETIME;

SELECT @yesterday = CONVERT(VARCHAR(10), DATEADD(dd, -1, current_timestamp), 120);
SELECT @Bettype = Bettype,
	  @MatchId = matchid,
       @refno = refno,
       @combo = hdp2
FROM rmBettrans r WITH (NOLOCK)
WHERE transid = @transid;
	

IF @Bettype  = 38
BEGIN	  
    DECLARE @OriginalSMP_Selection TABLE(transid BIGINT, SelectionType INT)
    DECLARE @SMP_Selection TABLE(transid BIGINT, SelectionType INT)
    
    DECLARE @SMP_result TABLE(transid BIGINT PRIMARY KEY, cnt INT);

    INSERT INTO @OriginalSMP_Selection(TransId, SelectionType)
    SELECT b.transid, a.SelectionType
    FROM rmBettrans b WITH(NOLOCK)
    INNER JOIN DBPRO.bodb02.dbo.SMP_MarketSelection a WITH(NOLOCK) ON b.betcheck = a.MarketId
    WHERE b.transid = @transid
 
    INSERT INTO @SMP_Selection(TransId, SelectionType)
    SELECT b.transid, a.SelectionType
    FROM rmBettrans b WITH(NOLOCK)
    INNER JOIN DBPRO.bodb02.dbo.SMP_MarketSelection a WITH(NOLOCK) ON b.betcheck = a.MarketId
    WHERE b.hdp2 = @combo 		
	   AND statusid = 0
	   AND b.matchid = @MatchId
	   AND transid <> @transid
        AND winlostdate > @yesterday

    INSERT INTO @SMP_result(transid,cnt)
    SELECT s.transid,count(1)
    FROM @OriginalSMP_Selection r
	   INNER JOIN @SMP_Selection s ON r.SelectionType = s.SelectionType
    GROUP BY s.transid
    HAVING count(1) >= CASE WHEN @combo =2 THEN @combo ELSE (@combo*1.0/2) END
	

    SELECT @cnt_bets = ISNULL(COUNT(1),0) FROM @SMP_result
    SELECT transdate
	   ,transid
	   ,refno
	   ,p.username
	   ,bettype
	   ,p.custid
	   ,isnull(c.level,0) as level
	   ,CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44) THEN -2 ELSE transid2 END AS Sporttype
	   ,odds2*TotalBet AS odds
	   ,stake*actualrate*(1-p.tpositiontaking)/TotalBet  as stake
	   ,stake*(odds2-1)*actualrate*(1-p.tpositiontaking) as net_win		
	   ,p.hdp2 AS TotalSelection,
	   p.TotalBet AS TotalBet,
	   @cnt_bets as cnt_bets
    FROM rmBettrans p WITH(NOLOCK) 
	   LEFT JOIN rmCustomer c WITH(NOLOCK) ON p.custid = c.custid
    WHERE transid = @transid and bettype=38
	
    SELECT p.transid
	   ,p.refno
	   ,p.username
	   ,p.custid
	   ,isnull(c.level,0) as level
	   ,stake*(odds2-1)*actualrate*(1-p.tpositiontaking) as net_win
	   ,cnt as similar_selection
    FROM @SMP_result r
	   INNER JOIN rmBettrans p WITH(NOLOCK) ON r.transid = p.transid
	   LEFT JOIN rmCustomer c WITH(NOLOCK) ON p.custid = c.custid
    ORDER BY cnt DESC
END
ELSE
BEGIN
    DECLARE @bettrans TABLE
					   (transid BIGINT
					    PRIMARY KEY,
					    refno   BIGINT
					   );
    DECLARE @Selection TABLE(matchid INT,
						bettype INT,
						betteam NVARCHAR(10));
						
    DECLARE @result TABLE
                      (refno BIGINT
                       PRIMARY KEY,
                       cnt   INT
                      );
    INSERT INTO @Selection (matchid, bettype, betteam)
    SELECT a.matchid, bettype, betteam
    FROM bodb02.dbo.bettransm a WITH(NOLOCK)
    INNER JOIN bodb02.dbo.match m(NOLOCK) ON a.matchid=m.matchid	
    WHERE refno = @refno AND m.sporttype<=99
    UNION
    SELECT a.matchid, bettype, betteam
    FROM bodb02.dbo.bettransm14 a WITH(NOLOCK)
    INNER JOIN bodb02.dbo.match14 m(NOLOCK) ON a.matchid=m.matchid	
    WHERE refno = @refno AND m.sporttype<=99
	
    INSERT INTO @bettrans(transid ,refno)
    SELECT b.transid, b.refno 
    FROM  rmBettrans b WITH(NOLOCK)
    WHERE 
	   b.bettype=29
	   AND b.combo = @combo 		
	   AND statusid = 0
	   AND winlostdate > @yesterday
	
    INSERT INTO @result(refno,cnt)
    SELECT refno,count(1)
    FROM 
    (
	   SELECT b.refno,bm. matchid, bettype, betteam
	   FROM bodb02.dbo.bettransm bm WITH(NOLOCK)
		  INNER JOIN @bettrans b ON bm.refno = b.refno	
		  INNER JOIN bodb02.dbo.match m(NOLOCK) ON bm.matchid=m.matchid		
		  WHERE m.sporttype<=99 
	   UNION 
	   SELECT b.refno, bm.matchid, bettype, betteam
	   FROM bodb02.dbo.bettransm14 bm WITH(NOLOCK)
		  INNER JOIN @bettrans b ON bm.refno = b.refno
		  INNER JOIN bodb02.dbo.match14 m(NOLOCK) ON bm.matchid=m.matchid	
		  WHERE m.sporttype<=99
    ) r
	   INNER JOIN @Selection s ON r.matchid = s.matchid AND r.bettype = s.bettype
    WHERE r.betteam = s.betteam
	   AND refno <> @refno
    GROUP BY refno
    HAVING count(1) >= CASE WHEN @combo =2 THEN @combo ELSE (@combo*1.0/2) END
    
    SELECT @cnt_bets = ISNULL(COUNT(1),0) FROM @result
    SELECT transdate
	   ,transid
	   ,refno
	   ,p.username
	   ,p.custid
	   ,bettype
	   ,isnull(c.level,0) as level
	   ,CASE WHEN transid2 NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44) THEN -2 ELSE transid2 END AS Sporttype
	   ,odds2*TotalBet AS odds
	   ,stake*actualrate*(1-p.tpositiontaking)/TotalBet  as stake
	   ,stake*(odds2-1)*actualrate*(1-p.tpositiontaking) as net_win		
	   ,p.hdp2 AS TotalSelection,
	   p.TotalBet AS TotalBet,
	   @cnt_bets as cnt_bets
    FROM rmBettrans p WITH(NOLOCK) 
	   LEFT JOIN rmCustomer c WITH(NOLOCK) ON p.custid = c.custid
    WHERE transid = @transid and bettype=29
	
    SELECT p.transid
	   ,p.refno
	   ,p.username
	   ,p.custid
	   ,isnull(c.level,0) as level
	   ,stake*(odds2-1)*actualrate*(1-p.tpositiontaking) as net_win
	   ,cnt as similar_selection
    FROM 
	   (
		  SELECT transid, cnt
		  FROM @result r
		  INNER JOIN @bettrans b ON r.refno = b.refno 
	   )b
	   INNER JOIN rmBettrans p WITH(NOLOCK) ON b.transid = p.transid
	   LEFT JOIN rmCustomer c WITH(NOLOCK) ON p.custid = c.custid
    ORDER BY cnt DESC
END


GO
