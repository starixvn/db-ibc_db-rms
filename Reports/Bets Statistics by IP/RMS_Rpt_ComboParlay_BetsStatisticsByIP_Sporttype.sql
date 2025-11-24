/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_BetsStatisticsByIP_Sporttype]
	@fromdate  DATETIME,
	@IP        VARCHAR(45),
	@custid    INT,
	@sporttype INT,
	@TicketStatus	VARCHAR(50) = '-1'

AS

/*
	Created: 20160505@Winnie
	DB: DBRMS-bodb_RMS
	Task: get bets list of customer by sport
	
	Revisions:	
		- 20190214@Jacob: Add Bet Builder [RedmineID: #108694]
		- 20200510@Percy: Add Penalty Shootout Combo [RedmineID: #133961]
		- 20201204@Danny: Separate Data of Virtual Soccer & Virtual Basketball  [RedmineID: #145926]
		- 20210218@Danny: Monitor Performance of GOF  [RedmineID: #149966]
		- 20211001@Danny: Change dataType to support IPv6 [RedmineID: #162348]
		- 20231020@Cherry: Parlay Boost Bonus (#192681)
		- 20231115@Cherry: Add param TicketStatus (#196550)
		- 20240109@Cherry: Change Original Odds from ExtraInfo
		- 20240312@Cherry: Change SQL account in metadata (#202012)
		- 20241206@Cherry: Sporttype of Betbuilder (#213805)
		- 20251020@Cherry: Upgrade Sporttype (#242167)
		- 20251020@Cherry: Integrate Hybrid Parlay (#242165)

	Parameter's Explanation:
		@sporttype = '1': soccer only
					= 2: others
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

	SELECT  a.transid,
            a.refno,
            a.transdate,
            a.bettype,
            a.modds,
			CASE WHEN a.bettype = 29 AND a.betteam = N'1' AND a.oddsspread = 2 THEN 1 ELSE 0 END IsBoostBonus,
            TRY_CAST(TRY_CAST(a.ExtraInfo AS XML).value('(/p1/@o)[1]', 'VARCHAR(50)') AS DECIMAL(19,4)) odds, --Original Odds
			CASE WHEN a.statusID = 112 AND TRY_CAST(TRY_CAST(a.ExtraInfo AS XML).value('(/p1/@bba)[1]', 'VARCHAR(50)') AS SMALLMONEY) > 0 
				THEN r.mOdds
				ELSE TRY_CAST(TRY_CAST(a.ExtraInfo AS XML).value('(/p1/@bbo)[1]', 'VARCHAR(50)') AS SMALLMONEY) END odds2, --Boost Odds
			CASE WHEN a.statusID = 112 AND TRY_CAST(TRY_CAST(a.ExtraInfo AS XML).value('(/p1/@bba)[1]', 'VARCHAR(50)') AS SMALLMONEY) > 0 
				THEN r.ExtraValue
				ELSE TRY_CAST(TRY_CAST(a.ExtraInfo AS XML).value('(/p1/@bbp)[1]', 'VARCHAR(50)') AS SMALLMONEY) END bbp, --Boost Rate
			TRY_CAST(TRY_CAST(a.ExtraInfo AS XML).value('(/p1/@bba)[1]', 'VARCHAR(50)') AS SMALLMONEY) bba,
            a.stake,
			a.statusid,
            a.status,
            a.winlost - a.actual_stake AS winlost,
            a.hdp1,
            a.hdp2,
            a.betteam,
            a.betcheck,
            m.sporttype,
            m.leagueid,
            m.matchcode,
            m.GlobalShowTime AS EventDate,
            m.homeid,
            m.awayid,
            ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
            ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			a.oddsspread,
			a.ExtraInfo,
			a.actual_stake,
			CAST(CASE WHEN a.bettype = 29 AND a.oddsspread = 1 AND a.betteam = N'1' THEN 1 ELSE 0 END AS BIT) IsGOF,
			CASE
				WHEN a.bettype = 29 AND a.betteam = N'1' AND a.oddsspread = 3 THEN 8
				WHEN a.bettype = 29 AND a.betteam = N'1' THEN 1
				WHEN a.bettype = 29 AND a.betteam <> N'1' THEN 2
				WHEN a.bettype = 38 THEN 3
				WHEN a.bettype = 376 THEN 4
			ELSE 0 END AS ParlayType
     FROM dbo.rmBettrans a WITH (NOLOCK)
          LEFT JOIN bodb02.dbo.match m WITH (NOLOCK) ON m.matchid = a.matchid AND a.bettype IN (38, 376)
		  LEFT JOIN (SELECT DISTINCT transid, refno, modds, ExtraValue
                    FROM bodb02.dbo.BetParlayResult WITH (NOLOCK) 
                    ) r ON a.refno = r.RefNo
     WHERE a.IP = @IP
		AND a.custid = @custid
		AND a.transdate >= @fromdate AND a.transdate < DATEADD(DAY, 1, @fromdate)
        AND (
			(@sporttype = 1 AND a.bettype = 29 AND a.liveawayscore = 1)
            OR (@sporttype = 2 AND a.bettype = 29 AND a.liveawayscore IN (2,3))
			OR (a.bettype <> 29 AND m.sporttype = @sporttype)
			)
		AND (@TicketStatus = '-1' OR
			EXISTS (SELECT TOP 1 1 FROM #tmpStatus t WHERE a.statusID = t.statusid)
			)

	DROP TABLE #tmpStatus
END
GO