
/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[RMS_BetList_BetBuilder_MatchDetail] @TransId BIGINT
AS  
  
/*  
 Created: Jacob@20190220  
 Task : Get match detail from BetBuilder ticket (Single Match Parlay)  
 DB: DBRMS.bodb_RMS  
 Original:  
 Revisions:  
  - 20190220@Jacob: Add Bet Builder RedmineID: #108694
*/

     SET NOCOUNT ON;
     SELECT m.homeid,
            m.awayid,
            m.sporttype,
            m.leagueid,
            m.GlobalShowTime AS EventDate,
            bettype,
            transid
     FROM rmBettrans a WITH (NOLOCK)
          LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON m.matchid = a.matchid
                                                           AND a.bettype = 38
     WHERE transid = @transid;
GO
  