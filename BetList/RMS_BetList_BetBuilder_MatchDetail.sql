
/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[RMS_BetList_BetBuilder_MatchDetail] @TransId BIGINT
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
     DECLARE @match TABLE
                          (matchid         INT,
					  homeid         INT,
                           awayid         INT,
                           sporttype      INT,
                           leagueid       INT,
                           GlobalShowTime SMALLDATETIME
                          );
     DECLARE @matchid INT;
     SELECT @matchid = matchid
     FROM rmBettrans a WITH (NOLOCK)
     WHERE transid = @transid;

	IF @matchid IS NULL 
	BEGIN
	   SELECT @matchid = matchid
	   FROM bodb02.dbo.bettrans14  WITH (NOLOCK)
	   WHERE transid = @transid; 
	END

	IF @matchid IS NULL 
	BEGIN
	   SELECT @matchid = matchid
	   FROM DBARC.bodb_archive.dbo.bettrans_bk WITH (NOLOCK)     
	   WHERE transid = @transid; 
	END

     IF @matchid IS NOT NULL
         BEGIN

             INSERT INTO @match
                    SELECT m.matchid,
					  m.homeid,
                           m.awayid,
                           m.sporttype,
                           m.leagueid,
                           m.GlobalShowTime
                    FROM bodb02.dbo.match AS m WITH (NOLOCK)
                    WHERE m.matchid = @matchid;
             IF NOT EXISTS (SELECT 1 FROM @match)
                 BEGIN
                     INSERT INTO @match
                            SELECT m.matchid,
							m.homeid,
                                   m.awayid,
                                   m.sporttype,
                                   m.leagueid,
                                   m.GlobalShowTime
                            FROM bodb02.dbo.match14 AS m WITH (NOLOCK)
                            WHERE m.matchid = @matchid;
                 END;
             IF NOT EXISTS (SELECT 1 FROM @match)
                 BEGIN
                     INSERT INTO @match
                            SELECT m.matchid,
						     m.homeid,
                                   m.awayid,
                                   m.sporttype,
                                   m.leagueid,
                                   m.GlobalShowTime
                            FROM DBARC.bodb_archive.dbo.match_bk m(NOLOCK)
                            WHERE m.matchid = @matchid;
                 END;
         END;

     SELECT m.homeid,
            m.awayid,
            m.sporttype,
            m.leagueid,
            m.GlobalShowTime AS EventDate,
            38 AS bettype,
            @TransId AS TransId
     FROM @match AS m 

GO
  