ALTER PROCEDURE [dbo].[RMS_FunctionSel]
AS
	/*
		Created: Johnson
		Date: 2012-05-16
		Task: Get functions info
		DB: DB054.bodb_RMS
		
		Revisions:
		
		Parameter's Explanation:
	*/ 
SET NOCOUNT ON
	
	SELECT FuncID, FuncName, FuncKey, FuncDesc, ParentID, ParentName, DisplayOrder, ModifiedDate 
	FROM rmFunction WITH(NOLOCK)
	ORDER BY parentID, DisplayOrder ASC
	
GO
GRANT VIEW DEFINITION ON [dbo].[RMS_FunctionSel] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[RMS_FunctionSel] TO [bodbRMSNet]