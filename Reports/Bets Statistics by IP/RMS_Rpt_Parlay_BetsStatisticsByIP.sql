/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_Parlay_BetsStatisticsByIP]
	@IP			VARCHAR(45)
	,@fromdate	DATETIME
	,@TicketStatus	VARCHAR(50) = '-1'
AS

/*
	Created: 20140418@Johnson
	DB: DBRMS/bodb_RMS
	Task: Get report customers bets by ip

	Revisions:	
		- 20200510@Percy: Change condition of transdate [RedmineID: #133961]
		- 20211001@Danny: Change dataType to support IPv6 [RedmineID: #162348]
		- 20230420@Cherry: Add Site column (#186735)
		- 20231115@Cherry: Add param TicketStatus, output column (#196550)
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241206@Cherry: Sporttype of Betbuilder (#213805)
		- 20251016@Cherry: Move sites NovaCasino, SEAL888 from Deposit to Credit (#241763)
	
	Parameter's Explanation:
		@TicketStatus: 
			-1:  All
			0:   Running
			112: Won
			113: Lose
			111: Draw
			101: Reject
			102: Void
*/

BEGIN 
	SET NOCOUNT ON 

	CREATE TABLE #tmpStatus (statusid INT)
	INSERT INTO #tmpStatus (statusid)
	SELECT value FROM STRING_SPLIT(@TicketStatus, ',')
	
	SELECT
		b.custid
		,CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END SiteGroup
		,b.username
		,SUM(CASE WHEN b.liveawayscore = 1 AND b.bettype = 29 THEN 1 
				WHEN b.bettype <> 29 AND m.sporttype = 1 THEN 1
				ELSE 0 END) as cnt_soccer
		,SUM(CASE WHEN b.liveawayscore IN (2,3) AND b.bettype = 29 THEN 1 
				WHEN b.bettype <> 29 AND m.sporttype <> 1 THEN 1
				ELSE 0 END) as cnt_others
		,SUM(stake * actualrate) Stake
		,SUM(CASE WHEN statusid = 0 THEN (odds2 - 1) * stake * actualrate
				ELSE (winlost - actual_stake) * actualrate
			END) WinningAmount
		,SUM(CASE WHEN statusid = 0 THEN (odds2 - 1) * stake * actualrate * (1 - tpositiontaking)
				ELSE ((winlost - actual_stake) * (1 - tpositiontaking - CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0))) + scomm - CASE WHEN tpositiontaking = 1 THEN 0 ELSE scomm * CONVERT(DECIMAL(9, 8), ISNULL(epositiontaking, 0)) / (1 - tpositiontaking) END) * actualrate
			END) HouseLoseAmount
	FROM dbo.rmBettrans b WITH (NOLOCK)	
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON b.custid = c.custid
		LEFT JOIN bodb02.dbo.site s WITH(NOLOCK) ON c.site = s.site
		LEFT JOIN bodb02.dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid AND b.bettype IN (38, 376)
	WHERE b.ip = @IP
		AND transdate >= @fromdate AND transdate < DATEADD(DAY, 1, @fromdate)
		AND (@TicketStatus = '-1' OR
			EXISTS (SELECT TOP 1 1 FROM #tmpStatus t WHERE b.statusID = t.statusid)
			)
	GROUP BY b.custid, b.username,
			CASE WHEN s.isDeposit = 0 OR s.site IN ('Saba789','NovaCasino','SEAL888') THEN 'C' ELSE 'L' END

	DROP TABLE #tmpStatus
END
GO