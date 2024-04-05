/*<info serverAlias="DBRMS-bodb_RMS" executers="wsv_rms" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[RMS_CurrencySel] @CurrencyName NVARCHAR(50) = ''
AS

/*
	Created: 2020305@Danny
	DB: DBRMS-bodb_RMS
	Task: get Active currency list
		
	Revisions:	
		- 20201030@Danny: Initialize SP [RedmineID: #148137]		
		- 20240312@Cherry: Change SQL account in metadata (#202012)

*/

BEGIN
	SET NOCOUNT ON

	SELECT ExchangeId as Currency, currency as CurrencyName 
	FROM bodb02.dbo.Exchange WITH(NOLOCK)
	WHERE isActive = 1 and ExchangeId <> 20 AND currency LIKE '%'+@CurrencyName+'%'
	ORDER BY CurrencyName

END
GO

