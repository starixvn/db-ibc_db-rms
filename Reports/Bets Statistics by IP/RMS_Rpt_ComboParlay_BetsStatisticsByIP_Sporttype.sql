/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_BetsStatisticsByIP_Sporttype]
	@fromdate  DATETIME,
	@IP        VARCHAR(45),
	@custid    INT,
	@sporttype TINYINT
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

	Parameter's Explanation:
		@sporttype = '1': soccer only
					= 2: others
*/

BEGIN
	SET NOCOUNT ON

	SELECT  a.transid,
            a.refno,
            a.transdate,
            a.bettype,
            a.modds,
			CASE WHEN a.bettype = 29 AND a.betteam = N'1' AND a.oddsspread = 2 THEN 1 ELSE 0 END IsBoostBonus,
            a.odds, --Original Odds
			CASE WHEN a.statusID = 112 AND ISNULL(TRY_CAST(TRY_CAST(a.ExtraInfo AS XML).value('(/p1/@bba)[1]', 'VARCHAR(50)') AS DECIMAL(19,6)),0) > 0 
				THEN r.mOdds
				ELSE a.odds2 END odds2, --Boost Odds
			CASE WHEN a.statusID = 112 AND ISNULL(TRY_CAST(TRY_CAST(a.ExtraInfo AS XML).value('(/p1/@bba)[1]', 'VARCHAR(50)') AS DECIMAL(19,6)),0) > 0 
				THEN r.ExtraValue
				ELSE ISNULL(TRY_CAST(TRY_CAST(a.ExtraInfo AS XML).value('(/p1/@bbp)[1]', 'VARCHAR(50)') AS DECIMAL(19,6)),0) END bbp, --Boost Rate
			ISNULL(TRY_CAST(TRY_CAST(a.ExtraInfo AS XML).value('(/p1/@bba)[1]', 'VARCHAR(50)') AS DECIMAL(19,6)),0) bba,
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
			bm.ExtraInfo,
			a.actual_stake,
			CAST(CASE WHEN a.bettype = 29 AND a.oddsspread = 1 AND a.betteam = N'1' THEN 1 ELSE 0 END AS BIT) IsGOF
     FROM dbo.rmBettrans a WITH (NOLOCK)
          LEFT JOIN bodb02.dbo.match m WITH (NOLOCK) ON m.matchid = a.matchid AND a.bettype IN (38, 376)
		  LEFT JOIN  bodb02.dbo.bettrans bm WITH (NOLOCK) ON a.transid = bm.transid
		  LEFT JOIN bodb02.dbo.BetParlayResult r WITH (NOLOCK) ON bm.refno = r.RefNo
     WHERE a.IP = @IP
		AND a.custid = @custid
		AND a.transdate >= @fromdate AND a.transdate < DATEADD(DAY, 1, @fromdate)
        AND (
			(@sporttype = 1 AND a.liveawayscore = 1)
            OR (@sporttype = 2 AND a.liveawayscore IN (2,3))
		)
END
GO