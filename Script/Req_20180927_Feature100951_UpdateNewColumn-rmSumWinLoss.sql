
/*
		Created: Jacob
		Date: 2018-09-27
		Task: Apply Extra PT and Super Comm to Report.  RedmineID: #100951
		DB: DBRMS/bodb_RMS
		
		Revisions:
			- 20180927@Jacob: Apply Extra PT and Super Comm to Report.  RedmineID: #100951 		
		Parameter's Explanation:
*/

USE [bodb_RMS];
GO
-- UPDATE rmSumWinloss
UPDATE t
  SET
      scomm = tt.scomm,
      extra_stake = tt.stake,
      extra_winlost = tt.winlost,
      extra_comm = tt.comm
FROM [dbo].[rmSumWinloss] t WITH (rowlock, updlock)
     INNER JOIN rmSumWinlossExtraPT tt ON t.[custid] = tt.[custid]
                                          AND t.[winlostdate] = tt.[winlostdate]
                                          AND t.[sporttype] = tt.[sporttype]
                                          AND t.[statusid] = tt.[statusid]
                                          AND t.[combo] = tt.[combo]
                                          AND t.[parlaytype] = tt.[parlaytype];
 
 -- UPDATE rmSumWinloss_Old
UPDATE t
  SET
      scomm = tt.scomm,
      extra_stake = tt.stake,
      extra_winlost = tt.winlost,
      extra_comm = tt.comm
FROM [dbo].[rmSumWinloss_Old] t WITH (rowlock, updlock)
     INNER JOIN rmSumWinlossExtraPT_Old tt ON t.[custid] = tt.[custid]
                                              AND t.[winlostdate] = tt.[winlostdate]
                                              AND t.[sporttype] = tt.[sporttype]
                                              AND t.[statusid] = tt.[statusid]
                                              AND t.[combo] = tt.[combo]
                                              AND t.[parlaytype] = tt.[parlaytype];