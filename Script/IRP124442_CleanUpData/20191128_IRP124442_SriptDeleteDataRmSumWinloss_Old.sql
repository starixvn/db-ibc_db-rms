/*
	Created: 20191128@Johnson
	Task: clean up RMS- delete data from rmSumWinloss_Old [redmine:#124442]
	DB: DBRMS/bodb_RMS
*/

SET NOCOUNT ON

DECLARE @fromdate DATETIME, @maxdate DATETIME
DECLARE @msg nvarchar(1000) 

--get min date
--select min(winlostdate) from rmSumWinloss_Old (nolock)
SELECT @fromdate = '2013-01-01 00:00:00',
		@maxdate = '2018-01-01'
		
WHILE(@fromdate < @maxdate)
BEGIN
	SELECT @msg = 'date: '+CONVERT(varchar(10),@fromdate,120)
	RAISERROR (@msg,0,1) WITH NOWAIT 
	
	WHILE(1=1)
	BEGIN
		DELETE TOP (5000)
		FROM rmSumWinloss_Old WITH(UPDLOCK,ROWLOCK)
		WHERE winlostdate = @fromdate
		
		IF @@rowcount < 5000
			BREAK;			
		
		WAITFOR DELAY '0:0:0.01'	
	END
	
	SELECT @fromdate = @fromdate + 1	
END		

