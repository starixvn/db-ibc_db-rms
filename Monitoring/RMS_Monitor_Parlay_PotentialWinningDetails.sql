 ALTER PROCEDURE [dbo].[RMS_Monitor_Parlay_PotentialWinningDetails]
	@CustID			INT,
	@selection		VARCHAR(100) = '',
	@sporttype		VARCHAR(100) = ''
 AS
	/*	
		Created: Elodie
		Date: 2015-03-24
		DB: DBRMS/bodb_RMS
		Task: Get detail report of Potential Winning Tool
		
		Revisions:
		
		Parameter's Explanation:
		
	*/
BEGIN
	SET NOCOUNT ON
	DECLARE @tmpSelection TABLE (selection int)
	DECLARE @tmpSport TABLE (sporttype int)	
	DECLARE @6up varchar(100)

	INSERT INTO @tmpSelection
	SELECT val
	FROM f_RMS_strSplit (@selection,',')
	
	--Check selection is 6-UP
	IF EXISTS(SELECT 1 FROM @tmpSelection WHERE selection = 6)
	BEGIN
		SELECT @6up = '7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30'

		INSERT INTO @tmpSelection
		SELECT val
		FROM f_RMS_strSplit (@6up,',')		
	END

	INSERT INTO @tmpSport (sporttype)
	SELECT val
	FROM f_RMS_strSplit (@sporttype,',')

	SELECT	b.transdate,
			b.transid,
			b.refno,
			b.odds,
			b.stake*b.actualrate AS Stake,
			(b.odds-1)*b.stake*b.actualrate AS WinningAmount,
			(b.odds-1)*b.stake*b.actualrate*(1-b.tpositiontaking) AS CompanyLoseAmount,
			b.ip,
			(1-b.tpositiontaking) AS HousePT, 
			b.combo
	FROM rmBettrans b WITH (NOLOCK)	
	WHERE b.custid = @CustID
		AND b.combo IN (SELECT selection FROM @tmpSelection)
		AND b.matchid = 9
		AND b.statusid = 0
		AND currency <> 20
		AND b.liveawayscore IN (SELECT sporttype FROM @tmpSport)
	ORDER BY b.transdate
END

GO
GRANT EXECUTE ON [dbo].[RMS_Monitor_Parlay_PotentialWinningDetails] TO [bodbRMSNet]
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_Monitor_Parlay_PotentialWinningDetails] TO [vnteam]