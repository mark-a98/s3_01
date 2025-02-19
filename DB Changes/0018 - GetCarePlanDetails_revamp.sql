GO

/****** Object:  StoredProcedure [dbo].[GetCarePlanDetails_revamp]    Script Date: 2/19/2025 9:15:25 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






--	UPDATED BY: Mark A.
--	UPDATED ON: 05/27/2024
--	DESCRIPTION: Added Care Goal Comments to the Result Set

-- UPDATED BY: Mark A.
-- UPDATED ON: 07/15/2024
-- DESCRIPTION: Date of visit note care plan comments will based on visit date and only comments from prior date will be shown
ALTER PROCEDURE [dbo].[GetCarePlanDetails_revamp]
	@page VARCHAR(10),
	@key BIGINT,
	@episode_id BIGINT = -1
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @episodeid BIGINT,
	@ptoid BIGINT,
	@oasisid BIGINT,
	@pocid BIGINT,
	@tcnid BIGINT

	DECLARE 
	@isPTOHasCareplan INT = 0,
	@PTOType VARCHAR(MAX),
	@patient_intake_id BIGINT

	SELECT @patient_intake_id = patient_intake_id FROM PTO WHERE pto_id = @key AND COALESCE(isDeleted,0) = 0 
	SELECT @PTOType = order_type FROM PTO WHERE pto_id = @key AND COALESCE(isDeleted,0) = 0

	IF(@page = 'PTO')
		SELECT @episodeid = episode_id, @ptoid = pto_id FROM PTO WHERE pto_id = @key AND ISNULL(isdeleted, 0) = 0;

	IF(@page = 'OASIS')
		SELECT @episodeid = episode_id, @oasisid = oasisid FROM Oasis WHERE oasisid = @key AND ISNULL(isdeleted, 0) = 0
	IF(@page = 'POC')
	BEGIN
		SELECT @pocid = pocid, @oasisid = oasisid FROM Poc WHERE pocid = @key AND ISNULL(isdeleted, 0) = 0
		SELECT @episodeid = episode_id, @oasisid = oasisid FROM Oasis WHERE oasisid = @oasisid AND ISNULL(isdeleted, 0) = 0
	END
	IF(@page = 'TCN')
	BEGIN
		SELECT @episodeid = episode_id, @tcnid = tcn_id FROM TelCommunicationNote WHERE tcn_id = @key AND ISNULL(isdeleted, 0) = 0
	END


	IF (@page = 'PTO')
	BEGIN
		SELECT @isPTOHasCareplan = COUNT(problem_id) FROM dbo.Func_GetAllCarePlanProblemByEpisodeId(@episodeid, @ptoid, @oasisid, @pocid, @tcnid, @page, DEFAULT)
	END



	IF(@page = 'PTO' AND (@key = -1 OR @isPTOHasCareplan = 0) AND COALESCE(@PTOType,'') NOT IN ('AdmissionOrder'))
	BEGIN
		----CarePlan Problem
		--SELECT  1 AS isfromProfile, * FROM dbo.Func_GetAllCarePlanProblemProfileByEpisodeId(@episode_id, NULL)

		----CarePlan Goal
		--SELECT 1 AS isfromProfile, * FROM dbo.Func_GetAllCarePlanCareGoalProfileByEpisodeId(@episode_id, 1)

		----CarePlan Intervention
		--SELECT  1 AS isfromProfile, * FROM dbo.Func_GetAllCarePlanInterventionProfileByEpisodeId(@episode_id, NULL,NULL,NULL,NULL,NULL, 1)

		----CarePlan Intervention Comment
		--SELECT  1 AS isfromProfile, * FROM dbo.Func_GetAllCarePlanInterventionCommentByEpisodeId(@episode_id, -1, -1, -1, 'PTO')

		IF(@key != -1 AND COALESCE(@PTOType,'') = 'Recertification') --Get the care plan from last episode if the Recertification already exists but has no care plan by setting the episode id from the last
		BEGIN
			DECLARE @pto_call_date DATETIME;
			SELECT @pto_call_date = call_date FROM PTO WHERE pto_id = @key AND COALESCE(isDeleted,0) = 0
			SELECT TOP 1 @episode_id = e.episode_id FROM Episode e JOIN PTO ON pto.pto_id = e.pto_id WHERE pto.pto_id != @key AND e.patient_intake_id = @patient_intake_id AND COALESCE(e.isDeleted,0) = 0 AND call_date < @pto_call_date ORDER BY pto.call_date DESC
		END

		EXEC [GetCarePlanProfileDetailsForCareplan_revamp]
		@episode_id = @episode_id,
		@severity_of_care_problem  = NULL,
		@initiated_date_from  = NULL,
		@initiated_date_to  = NULL,
		@resolved_date_from  = NULL,
		@resolved_date_to  = NULL,
		@goal_outcome  = NULL,
		@target_type  = 'All',
		@pending_day  = 0,
		@initiated_by  = NULL,
		@resolved_by  = NULL

	END
	ELSE
	BEGIN
		--CarePlan Problem
		SELECT * FROM dbo.Func_GetAllCarePlanProblemByEpisodeId(@episodeid, @ptoid, @oasisid, @pocid, @tcnid, @page, DEFAULT)

		--CarePlan Goal
		SELECT * FROM dbo.Func_GetAllCarePlanCareGoalByEpisodeId(@episodeid, @ptoid, @oasisid, @pocid, @tcnid, @page, DEFAULT)

		--CarePlan Intervention
		SELECT * FROM dbo.Func_GetAllCarePlanInterventionByEpisodeId(@episodeid, @ptoid, @oasisid, @pocid, @tcnid, @page, DEFAULT)

		--CarePlan Intervention Comment
		SELECT * FROM dbo.Func_GetAllCarePlanInterventionCommentByEpisodeId(@episodeid, @ptoid, @oasisid, @pocid,@page, DEFAULT)  ORDER BY COALESCE(visit_date, created_timestamp), CASE WHEN visit_date IS NOT NULL THEN created_timestamp END

		--CarePlan Care Goal Comment
		SELECT * FROM dbo.Func_GetAllCarePlanCareGoalCommentByEpisodeId(@episodeid, @ptoid, @oasisid, @pocid,@page, DEFAULT)  ORDER BY COALESCE(visit_date, created_timestamp), CASE WHEN visit_date IS NOT NULL THEN created_timestamp END
	END
END
 

GO

