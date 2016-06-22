USE bodb_RMS
GO
SELECT vvalue
  FROM [bodb_RMS].[dbo].rmsettings(NOLOCK) 
WHERE VName='rmBettransSync'