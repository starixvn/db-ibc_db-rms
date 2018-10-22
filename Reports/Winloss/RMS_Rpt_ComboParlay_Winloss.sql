/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_Winloss]
	@fromdate	SMALLDATETIME,
	@todate		SMALLDATETIME,
	@movebetsday DATETIME,
	@balanceUpday DATETIME = NULL,
	@sporttype VARCHAR(100)='',
	@bettype INT = 9,
	@selection VARCHAR(100)='',
	@ParlayType	VARCHAR(10)='',
	@ReportType TINYINT=1
AS
	/*
		Created: Winnie
		Date: 2016-05-11
		DB: DBRMS/bodb_RMS
		Task: report comboparlay winloss
		
		Revisions:	
		- 20170719@Winnie: Add MuayThai RedmineID: #79500		
		- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
		- 20181010@Elodie: Enhance performance

		Parameter's Explanation:
			- @sporttype = '1' : soccer only
						= '2' : Other sports
						= '3' : combined sports
			-@ReportType = '1' : combo
						= '2' : Sporttype
			
	*/
SET NOCOUNT ON
	DECLARE @f_date SMALLDATETIME,
			@t_date SMALLDATETIME
			
	DECLARE @rptWinloss TABLE(
		winlostdate DATETIME,
		combo	INT,
		tickets_won	INT,
		tickets_lose INT,
		stake_won MONEY,
		stake_lose MONEY,
		member_won MONEY,
		member_lose MONEY,
		ourPT_won MONEY,
		ourPT_lose MONEY,
		sporttype INT
	)
	DECLARE @tmpSelection TABLE(selection tinyint)	
	DECLARE @10UP VARCHAR(500),@all varchar(500)
	DECLARE @tmpParlayType TABLE (parlaytype tinyint)
	DECLARE @_ParlayType	TINYINT
	DECLARE @tmpSport TABLE (sporttype int)
	DECLARE @tmpSelection_Sport TABLE(selection tinyint, sporttype int)		
	
	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')
	IF EXISTS (SELECT TOP 1 1 FROM @tmpSport WHERE sporttype=-2)
	BEGIN
	INSERT INTO @tmpSport
	SELECT SportType FROM bodb02.dbo.Sports(NOLOCK) WHERE SportType NOT IN (1,2,3,4,5,6,7,8,9,11,43,44)
	END

	INSERT INTO @tmpParlayType
	SELECT val
	FROM f_RMS_strSplit (@ParlayType,',')
	IF EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 1 ) AND EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 2)
		SELECT @_ParlayType=0
	ELSE IF EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 1 )
		SELECT @_ParlayType=1
	ELSE IF EXISTS(SELECT TOP 1 1 FROM @tmpParlayType WHERE parlaytype = 2 )
		SELECT @_ParlayType=2

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
	
	INSERT INTO @tmpSelection_Sport (sporttype, selection)
	SELECT sporttype, selection
	FROM @tmpSelection CROSS JOIN @tmpSport	


	CREATE TABLE #ExtraPT_Sel( ProductID  INT,
                                   Sporttype  INT,
                                   SubProduct VARCHAR(100),
                                   SuperID    INT,
							FromDate DATETIME,
							ToDate DATETIME,
                                   ExtraPT    DECIMAL(9, 8));
    INSERT INTO #ExtraPT_Sel
			 ( ProductID, Sporttype, SubProduct, SuperID, FromDate, ToDate, ExtraPT)
    SELECT ProductID, SportType, SubProduct, SuperId, FromDate, ToDate, SUM(ExtraPT) AS ExtraPT
    FROM bodb02.dbo.Acc_GroupExtraPTSetting a WITH ( NOLOCK )
    WHERE a.ProductID = 1
	   AND a.Sporttype = 0
	   AND a.SubProduct = ''
    GROUP BY ProductID, SportType, SubProduct, SuperId, FromDate, ToDate;

	IF @todate > @movebetsday
	BEGIN
		SELECT @f_date = CASE WHEN @fromdate <= @movebetsday THEN DATEADD(dd,1,@movebetsday) ELSE @fromdate END,
				@t_date = @todate
		
		INSERT INTO @rptWinloss(
				winlostdate
				,combo
				,tickets_won
				,tickets_lose
				,stake_won
				,stake_lose
				,member_won
				,member_lose
				,ourPT_won
				,ourPT_lose
				,sporttype
		)
		SELECT 
			winlostdate
			,CASE WHEN bettype=9 THEN right(betcheck,len(betcheck)-1) ELSE hdp2 END
			,sum(case when statusid = 112 then 1 else 0 end) as tickets_won
			,sum(case when statusid = 113 then 1 else 0 end) as tickets_lose,
			SUM(CASE
				   WHEN statusid = 112
				   THEN stake * actualrate * (1 - tpositiontaking - ISNULL(a.ExtraPT, 0))
				   ELSE 0
			    END) AS stake_won,
			SUM(CASE
				   WHEN statusid = 113
				   THEN stake * actualrate * (1 - tpositiontaking - ISNULL(a.ExtraPT, 0))
				   ELSE 0
			    END) AS stake_lose,
			SUM(CASE
				   WHEN statusid = 112
				   THEN-(winlost - actual_stake) * actualrate
				   ELSE 0
			    END) AS member_won,
			SUM(CASE
				   WHEN statusid = 113
				   THEN-(winlost - actual_stake) * actualrate
				   ELSE 0
			    END) AS member_lose,
			SUM(CASE
				   WHEN statusid = 112
				   THEN(-(winlost - actual_stake)  * (1 - tpositiontaking - ISNULL(a.ExtraPT, 0)) - scomm  + scomm * ISNULL(a.ExtraPT, 0) / (1 - tpositiontaking) ) * actualrate
				   ELSE 0
			    END) AS ourPT_won,
			SUM(CASE
				   WHEN statusid = 113
				   THEN(-(winlost - actual_stake) * (1 - tpositiontaking - ISNULL(a.ExtraPT, 0)) - scomm  + scomm * ISNULL(a.ExtraPT, 0) / (1 - tpositiontaking)) * actualrate
				   ELSE 0
			    END) AS ourPT_lose
			,transid2
		FROM rmBettrans WITH(NOLOCK)
			INNER JOIN @tmpSelection_Sport b ON CASE WHEN bettype=9 THEN right(betcheck,len(betcheck)-1) ELSE hdp2 END =b.selection AND transid2=b.sporttype
			LEFT JOIN #ExtraPT_Sel AS a WITH (NOLOCK) ON srecommend = a.SuperId AND winlostdate BETWEEN a.FromDate AND a.Todate
		 WHERE winlostdate BETWEEN @f_date AND @t_date
			AND matchid IN(9,29) 
			AND statusid IN (112,113)			
			AND currency <> 20
			AND (@_parlayType=0 OR (@_parlayType=1 AND betteam ='1' AND bettype=29)OR (@_parlayType=1 AND bettype=9) OR (@_parlayType=2 AND bettype=29 AND betteam <>'1' ))		
			
		GROUP BY winlostdate,CASE WHEN bettype=9 THEN right(betcheck,len(betcheck)-1) ELSE hdp2 END,transid2
	END
	
	IF @fromdate <= @movebetsday
	BEGIN
		IF @todate >= @balanceupday
		BEGIN
			SELECT @f_date = CASE WHEN @fromdate < @balanceupday THEN @balanceupday ELSE @fromdate END,
					@t_date = CASE WHEN @todate > @movebetsday THEN @movebetsday ELSE @todate END
			
			INSERT INTO @rptWinloss(
				winlostdate
				,combo
				,tickets_won
				,tickets_lose
				,stake_won
				,stake_lose
				,member_won
				,member_lose
				,ourPT_won
				,ourPT_lose
				,sporttype
				)
			SELECT 
				a.winlostdate
				,a.combo
				,sum(case when a.statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when a.statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when a.statusid = 112 then company_stake*actualrate - ISNULL(e.stake, 0) * actualrate else 0 end) as stake_won
				,sum(case when a.statusid = 113 then company_stake*actualrate - ISNULL(e.stake, 0) * actualrate else 0 end) as stake_lose
				,sum(case when a.statusid = 112 then -(a.winlost-a.stake)*actualrate else 0 end) as member_won
				,sum(case when a.statusid = 113 then -(a.winlost-a.stake)*actualrate else 0 end) as member_lose
				,sum(case when a.statusid = 112 then (company_winlost - ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) *actualrate else 0 end) as ourPT_won
				,sum(case when a.statusid = 113 then (company_winlost- ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) *actualrate else 0 end) as ourPT_lose		
				,a.sporttype	
			FROM rmSumWinloss a WITH(NOLOCK)
				INNER JOIN @tmpSelection_Sport b ON a.combo=b.selection AND a.sporttype=b.sporttype
				LEFT JOIN rmSumWinLossExtraPT e WITH(NOLOCK) ON a.[custid] = e.[custid] AND a.[winlostdate] = e.[winlostdate] AND a.[sporttype] = e.[sporttype] AND a.[statusid] = e.[statusid] AND a.[combo] = e.[combo] AND a.[parlaytype] = e.[parlaytype]
			WHERE a.winlostdate BETWEEN @f_date AND @t_date				
					AND a.statusid IN (112,113)
					AND currency <> 20				
					AND (@_parlayType=0 OR (@_parlayType=1 AND ISNULL(a.parlaytype,1)  IN (1,2)) OR (@_parlayType=2 AND ISNULL(a.parlaytype,1) =3))	
					
			GROUP BY a.winlostdate, a.combo,a.sporttype
		END
		IF @fromdate < @balanceupday
		BEGIN
			SELECT @f_date = @fromdate, 
					@t_date = CASE WHEN @todate >= @balanceupday THEN @balanceupday -1 ELSE @todate END
			
			INSERT INTO @rptWinloss(
				winlostdate
				,combo
				,tickets_won
				,tickets_lose
				,stake_won
				,stake_lose
				,member_won
				,member_lose
				,ourPT_won
				,ourPT_lose
				,sporttype
				)
			SELECT 
				a.winlostdate
				,a.combo
				,sum(case when a.statusid = 112 then betcount else 0 end) as tickets_won
				,sum(case when a.statusid = 113 then betcount else 0 end) as tickets_lose
				,sum(case when a.statusid = 112 then company_stake*actualrate - ISNULL(e.stake, 0) * actualrate else 0 end) as stake_won
				,sum(case when a.statusid = 113 then company_stake*actualrate - ISNULL(e.stake, 0) * actualrate else 0 end) as stake_lose
				,sum(case when a.statusid = 112 then -(a.winlost-a.stake)*actualrate else 0 end) as member_won
				,sum(case when a.statusid = 113 then -(a.winlost-a.stake)*actualrate else 0 end) as member_lose
				,sum(case when a.statusid = 112 then (company_winlost - ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) *actualrate else 0 end) as ourPT_won
				,sum(case when a.statusid = 113 then (company_winlost- ISNULL(e.winlost, 0) - ISNULL(e.scomm, 0) + ISNULL(e.comm, 0)) *actualrate else 0 end) as ourPT_lose				
				,a.sporttype	
			FROM rmSumWinloss_old a WITH(NOLOCK)
				INNER JOIN @tmpSelection_Sport b ON a.combo=b.selection AND a.sporttype=b.sporttype
				LEFT JOIN rmSumWinlossExtraPT_Old e WITH(NOLOCK) ON a.[custid] = e.[custid] AND a.[winlostdate] = e.[winlostdate] AND a.[sporttype] = e.[sporttype] AND a.[statusid] = e.[statusid] AND a.[combo] = e.[combo] AND a.[parlaytype] = e.[parlaytype]
			WHERE a.winlostdate BETWEEN @f_date AND @t_date				
				AND a.statusid IN (112,113)
				AND currency <> 20					
				AND (@_parlayType=0 OR (@_parlayType=1 AND ISNULL(a.parlaytype,1)  IN (1,2)) OR (@_parlayType=2 AND ISNULL(a.parlaytype,1) =3))	
				
			GROUP BY a.winlostdate, a.combo,a.sporttype		
		END			
	END
	
	IF @ReportType=1
	BEGIN
	SELECT winlostdate
				,CASE WHEN combo>10 THEN 10 ELSE combo END AS combo
				,SUM(tickets_won) AS tickets_won
				,SUM(tickets_lose) AS tickets_lose
				,SUM(stake_won) AS stake_won
				,SUM(stake_lose) AS stake_lose
				,SUM(member_won) AS member_won
				,SUM(member_lose) AS member_lose
				,SUM(ourPT_won) AS ourPT_won
				,SUM(ourPT_lose) AS ourPT_lose				
	 FROM @rptWinloss
	 GROUP BY  winlostdate, CASE WHEN combo>10 THEN 10 ELSE combo END
	 ORDER BY winlostdate ASC, combo ASC
	END
	ELSE
	SELECT winlostdate
				,CASE WHEN sporttype NOT IN  (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44) THEN -2 ELSE sporttype END AS sporttype
				,SUM(tickets_won) AS tickets_won
				,SUM(tickets_lose) AS tickets_lose
				,SUM(stake_won) AS stake_won
				,SUM(stake_lose) AS stake_lose
				,SUM(member_won) AS member_won
				,SUM(member_lose) AS member_lose
				,SUM(ourPT_won) AS ourPT_won
				,SUM(ourPT_lose) AS ourPT_lose				
	 FROM @rptWinloss
	 GROUP BY  winlostdate, CASE WHEN sporttype NOT IN (-1,-3,1,2,3,4,5,6,7,8,9,11,43,44) THEN -2 ELSE sporttype END
	 ORDER BY winlostdate ASC

	 DROP TABLE #ExtraPT_Sel
GO
