
/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_Rpt_ComboParlay_BetsStatisticsByIP_Sporttype] @fromdate  DATETIME,
                                                                         @IP        VARCHAR(30),
                                                                         @custid    INT,
                                                                         @sporttype TINYINT
AS
	
/*
		Created: Winnie
		Date: 2016-05-05
		Task: get bets list of customer by sport
		DB: DBRMS/bodb_RMS
		
	   Revisions:	
		- 20190214@Jacob: Add Bet Builder RedmineID: #108694

		Parameter's Explanation:
			@sporttype = '1': soccer only
						= 2: others
		
	*/


     SET NOCOUNT ON;
     DECLARE @todate DATETIME;
     SELECT @todate = @fromdate+'23:59:59';
     SELECT transid,
            refno,
            transdate,
            bettype,
            modds,
            odds,
            stake,
            statusid,
            status,
            winlost - actual_stake AS winlost,
            hdp1,
            hdp2,
            betteam,
            betcheck,
            m.sporttype,
            m.leagueid,
            m.matchcode,
            m.GlobalShowTime AS EventDate,
            m.homeid,
            m.awayid,
            ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
            ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral
     FROM rmBettrans a WITH (NOLOCK)
          LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON m.matchid = a.matchid
                                                           AND a.bettype = 38
     WHERE transdate BETWEEN @fromdate AND @todate
           AND custid = @custid
           AND IP = @IP
           AND ((@sporttype = 1
                 AND transid2 = 1)
                OR (@sporttype = 2
                    AND transid2 <> 1));
GO