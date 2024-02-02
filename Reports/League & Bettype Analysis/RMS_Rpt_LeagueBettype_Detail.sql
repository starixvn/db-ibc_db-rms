/*<info serverAlias="DBRMS-bodb_RMS" executers="bodbRMSNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_Rpt_LeagueBettype_Detail]
	@TransList		VARBINARY(MAX) = ''
AS

/*
	Created: 20240115@Cherry
	DB: DBRMS-bodb_RMS
	Task: League & Bettype Data Analysis

	Revisions:
		- 20240115@Cherry: Initialize SP [RedmineID: #197684]

	Param's Explanation:


*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBU (BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @MoveBetsDay DATETIME
	SELECT @MoveBetsDay = MoveBetsDay FROM @MBU
	
	DECLARE @TransIDs NVARCHAR(MAX)
	BEGIN TRY
		SELECT @TransIDs = tl
		FROM  OPENJSON (CAST( DECOMPRESS(@TransList) AS NVARCHAR(MAX)))
		WITH (
			tl VARCHAR(MAX)
			)
	END TRY
	BEGIN CATCH
		RETURN
	END CATCH

	CREATE TABLE #tmpTransID (TransID BIGINT)

	INSERT INTO #tmpTransID (TransID)
	SELECT val
	FROM bodb02.dbo.strSplit(@TransIDs, ',')

	CREATE TABLE #rmBettrans
	(
		transdate			DATETIME,
		transid				BIGINT,
		refno				BIGINT,
		custid				INT,
		SiteGroup			VARCHAR(10),
		username			NVARCHAR(50),
		bettype				SMALLINT,
		odds				SMALLMONEY,
		Stake				MONEY,
		StakeAfterPT		MONEY,
		WinningAmount		MONEY,
		HouseLoseAmount		MONEY,
		TotalBet			INT,
		TotalSelection		INT,
		SportType			SMALLINT,
		IP					VARCHAR(45),
		currencyName		NVARCHAR(50),
		CustomerClass		SMALLINT
	)

END
GO