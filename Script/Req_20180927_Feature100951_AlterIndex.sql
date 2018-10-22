/*
	Created: 20181010@Elodie
	Task: Alter index
	DB: DBRMS\bodb_RMS
*/
USE bodb_RMS
GO

CREATE NONCLUSTERED INDEX IX_winlostdate_matchid_statusid ON dbo.rmBettrans (winlostdate,custid,matchid,statusid) 
INCLUDE (stake,actualrate,bettype,betcheck,hdp2,tpositiontaking,winlost,actual_stake,transid2,currency,betteam,srecommend,scomm, Username) 
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = ON, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
ON [rmTable]

CREATE NONCLUSTERED INDEX IX_Winlostdate ON dbo.rmSumWinloss (winlostdate)
INCLUDE (currency,stake,winlost,company_stake,company_winlost,actualrate,betcount,ParlayType,combo,sporttype,statusid,custid,username) 
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
ON [rmSumWinloss]
GO

CREATE NONCLUSTERED INDEX IX_Winlostdate ON dbo.rmSumWinloss_Old (winlostdate)
INCLUDE (currency,stake,winlost,company_stake,company_winlost,actualrate,betcount,ParlayType,combo,sporttype,statusid,custid,username) 
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
ON [rmSumWinlossOld]
GO


