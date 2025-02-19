GO

/****** Object:  UserDefinedFunction [dbo].[Func_GetAllCarePlanProblemByEpisodeId]    Script Date: 2/19/2025 10:14:54 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- UPDATED BY: MARK A.
-- UPDATED ON: 05/14/2024
-- DESCRIPTION: FIX THE WHERE CLAUSE

ALTER FUNCTION [dbo].[Func_GetAllCarePlanProblemByEpisodeId]
(
	-- Add the parameters for the function here
	@episode_id BIGINT,
	@pto_id BIGINT,
	@oasis_id BIGINT,
	@poc_id BIGINT,
	@tcn_id BIGINT,
	@page_source VARCHAR(50),
	@cg_note_id BIGINT = NULL
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT 
	prob.problem_id
	,prob.problem_template_id
	,prob.bodysystem_id
	,prob.problem_desc
	,prob.problem_status
	,prob.problem_source
	,prob.problem_group_id
	,prob.page_source
	,CAST(prob.related_to_hhc_diag AS VARCHAR) related_to_hhc_diag
	,CAST(prob.severity_of_care_problem AS VARCHAR) severity_of_care_problem
	,prob.m0020_pat_id
	,prob.patient_intake_id
	,prob.episode_id
	,prob.pto_id
	,prob.oasis_id
	,prob.poc_id 
	,ISNULL(body.bodysystem_template_desc, 'None') AS bodysystem_desc
	,CONVERT(VARCHAR, prob.created_date, 101) created_date
	,prob.is_resolved_here
	FROM CarePlan_Problem prob
	INNER JOIN CarePlan_BodySystem_Template body ON prob.bodysystem_id = body.bodysystem_id 
	AND ISNULL(body.is_Deleted, 0) = 0
	and (
			(@page_source in ('VisitPlan-PTO', 'PTO') and prob.pto_id = @pto_id and prob.page_source in ('VisitPlan-PTO', 'PTO'))
			OR (@page_source in ('OASIS') and prob.oasis_id = @oasis_id and prob.page_source = 'OASIS')
			OR (@page_source in ('POC') and prob.poc_id = @poc_id and prob.page_source = 'POC')
			OR (@page_source in ('VisitPlan-TCN') and prob.cg_note_id = @cg_note_id and prob.page_source = 'VisitPlan-TCN' )
			OR (@page_source in ('TCN') and prob.tcn_id = @tcn_id and prob.page_source = 'TCN')
		)
	WHERE 
	prob.episode_id = @episode_id 
	AND case 
			when prob.page_source in ('VisitPlan-TCN','VisitPlan-PTO') and @page_source in ('TCN', 'PTO') then @page_source
			else prob.page_source
		end = @page_source
	--or (@page_source in ('VisitPlan-PTO', 'PTO') and prob.pto_id = @pto_id)
	--or (@page_source in ('OASIS') and prob.oasis_id = @oasis_id)
	--or (@page_source in ('POC') and prob.poc_id = @poc_id)
	--or (@page_source in ('VisitPlan-TCN', 'TCN') and prob.tcn_id = @tcn_id)
	AND ISNULL(prob.is_deleted, 0) = 0
)

GO

