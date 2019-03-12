
/*<info serverAlias="DBACC-bodb02" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_BetList_BetBuilder_Detail] @TransId BIGINT,
                                                      @CustId  INT
AS  
  
/*  
 Created: Kos@20190220  
 Task : Get ticket detail from BetBuilder ticket (Single Match Parlay)  
 DB: DBACC.bodb02  
 Original:  
 Revisions:  
  - 20190219@Kos: Support BetBuilder [Redmine: #106905]  
  - 20190220@Jacob: Add Bet Builder RedmineID: #108694
*/


     SET NOCOUNT ON;
     DECLARE @MatchId INT, @MarketId VARCHAR(20), @TableId TINYINT= 0;
     SELECT @MatchId = matchid,
            @MarketId = betcheck,
            @TableId = 1   -- bettrans  
     FROM dbo.bettrans WITH (NOLOCK)
     WHERE transid = @TransId
           AND custid = @CustId
           AND bettype = 38;
     IF @TableId = 0
         BEGIN
             SELECT @MatchId = matchid,
                    @MarketId = betcheck,
                    @TableId = 2   -- bettrans14  
             FROM dbo.bettrans14 WITH (NOLOCK)
             WHERE transid = @TransId
                   AND custid = @CustId
                   AND bettype = 38;
         END;
     IF @TableId = 0
         BEGIN
             SELECT @MatchId = matchid,
                    @MarketId = betcheck,
                    @TableId = 3   -- bettrans_bk  
             FROM DBARC.bodb_archive.dbo.bettrans_bk WITH (NOLOCK)
             WHERE transid = @TransId
                   AND custid = @CustId
                   AND bettype = 38;
         END;
     IF @TableId = 1
         BEGIN
             SELECT SelectionType,
                    ISNULL(Result, 'RUNNING') Result
             FROM dbo.SMP_MarketSelection WITH (NOLOCK)
             WHERE MatchId = @MatchId
                   AND MarketId = @MarketId;
         END;
         ELSE
     IF @TableId = 2
         BEGIN
             SELECT SelectionType,
                    ISNULL(Result, 'RUNNING') Result
             FROM dbo.SMP_MarketSelection14 WITH (NOLOCK)
             WHERE MatchId = @MatchId
                   AND MarketId = @MarketId;
         END;
         ELSE
     IF @TableId = 3
         BEGIN
             SELECT SelectionType,
                    ISNULL(Result, 'RUNNING') Result
             FROM DBARC.bodb_archive.dbo.SMP_MarketSelection_bk WITH (NOLOCK)
             WHERE MatchId = @MatchId
                   AND MarketId = @MarketId;
         END;
         ELSE
         BEGIN
             DECLARE @DummyTable TABLE(Id INT)
             SELECT 0 AS SelectionType,
                    'N/A' AS Result
             FROM @DummyTable
         END;
GO