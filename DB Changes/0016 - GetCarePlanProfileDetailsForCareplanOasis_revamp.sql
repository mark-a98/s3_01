USE [IDOneSourceHomeHealth]
GO

/****** Object:  StoredProcedure [dbo].[GetCarePlanProfileDetailsForCareplanOasis_revamp]    Script Date: 2/19/2025 9:19:07 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





--	UPDATED BY: Mark A.
--	UPDATED ON: 05/27/2024
--	DESCRIPTION: Add comment total for care goals

-- UPDATED BY: Mark A.
-- UPDATED ON: 07/15/2024
-- DESCRIPTION: Date of visit note care plan comments will based on visit date and only comments from prior date will be shown

-- UPDATED BY: Mark A.
-- UPDATED ON: 09/03/2024
-- DESCRIPTION: Lock target date column

ALTER PROCEDURE [dbo].[GetCarePlanProfileDetailsForCareplanOasis_revamp]
	@episode_id BIGINT,
	@pto_id BIGINT
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @referred_pto_id BIGINT

	SELECT @referred_pto_id = pto_id FROM PTO WHERE episode_id = @episode_id AND ISNULL(isDeleted, 0) = 0 AND order_type = 'InitialIntake'

	SELECT 'View' AS [action], * FROM dbo.Func_GetAllCarePlanProblemByEpisodeId(@episode_id, @pto_id, -1, -1, -1, 'PTO', DEFAULT)
	UNION
	SELECT 
	'AddFromLateAdmissionOrder' AS [action]
	,prob.problem_id
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
	FROM CarePlan_Problem prob
	LEFT JOIN CarePlan_BodySystem_Template body ON prob.bodysystem_id = body.bodysystem_id 
	AND ISNULL(body.is_Deleted, 0) = 0
	WHERE prob.episode_id = @episode_id AND prob.problem_source = 'OASIS' AND prob.page_source = 'OASIS'
	AND (prob.pto_id = @pto_id OR prob.pto_id = @referred_pto_id)
	AND ISNULL(prob.is_deleted, 0) = 0
	AND prob.problem_group_id NOT IN (SELECT _prob.problem_group_id FROM CarePlan_Problem _prob WHERE _prob.episode_id = @episode_id AND COALESCE(_prob.is_deleted,0) = 0 AND _prob.page_source = 'PTO' AND _prob.pto_id = @pto_id)

	--CarePlan Goal
	SELECT 'View' AS [action], * FROM dbo.Func_GetAllCarePlanCareGoalByEpisodeId(@episode_id, @pto_id, -1, -1, -1, 'PTO', DEFAULT)
	UNION
	SELECT 
	'AddFromLateAdmissionOrder' AS [action]
	,goal.goal_id
	,goal.caregoal_template_id
	,ISNULL((SELECT TOP 1 _cp.problem_id FROM Careplan_Problem _cp WHERE _cp.episode_id = @episode_id AND _cp.problem_group_id IN(SELECT cp.problem_group_id FROM Careplan_Problem cp WHERE cp.episode_id = @episode_id AND cp.problem_id = goal.problem_id AND COALESCE(cp.is_deleted,0) = 0) AND _cp.page_source = 'PTO' AND _cp.pto_id = @pto_id AND COALESCE(_cp.is_deleted,0) = 0), goal.problem_id) AS problem_id
	,goal.goal_desc
	,goal.goal_status
	,goal.goal_source
	,goal.goal_group_id
	,goal.page_source
	,CASE WHEN goal.target_date IS NULL OR goal.target_date = '01/01/0001' THEN '' ELSE CONVERT(VARCHAR, goal.target_date, 101) END target_date 
	,CAST(goal.goal_setfor AS VARCHAR) goal_setfor
	,CASE WHEN goal.resolution_date IS NULL OR goal.resolution_date = '01/01/0001' THEN '' ELSE CONVERT(VARCHAR, goal.resolution_date, 101) END resolution_date 
	,goal.comment
	,goal.m0020_pat_id
	,goal.patient_intake_id
	,goal.episode_id
	,goal.pto_id
	,goal.oasis_id
	,goal.poc_id,
	gcom.comment_total,
	goal.tcn_id,
	goal.cg_note_id,
	CASE WHEN COALESCE(goalsource.goal_id,0) = 0 THEN 0 ELSE (CASE WHEN goal.goal_group_id = goal.goal_id THEN 0 ELSE 1 END)  END  lockTargetDate
	FROM CarePlan_Goal goal
	CROSS APPLY 
   ( 
	   SELECT COUNT(1) comment_total FROM Careplan_CareGoal_Comment com
	   WHERE com.goal_group_id = goal.goal_group_id AND ISNULL(com.is_Deleted, 0) = 0
   ) gcom
   LEFT JOIN CarePlan_Goal goalsource ON goalsource.goal_id = goal.goal_group_id AND COALESCE(goalsource.is_deleted,0) = 0
	WHERE goal.episode_id = @episode_id AND goal.page_source = 'OASIS' AND goal.goal_source = 'OASIS'
	AND (goal.pto_id = @pto_id OR goal.pto_id = @referred_pto_id)
	AND ISNULL(goal.is_deleted, 0) = 0
	AND goal.goal_group_id NOT IN (SELECT _goal.goal_group_id FROM CarePlan_Goal _goal WHERE _goal.episode_id = @episode_id AND COALESCE(_goal.is_deleted,0) = 0 AND _goal.page_source = 'PTO' AND _goal.pto_id = @pto_id)

	--CarePlan Intervention
	SELECT 'View' AS [action],* FROM dbo.Func_GetAllCarePlanInterventionByEpisodeId(@episode_id, @pto_id, -1, -1, -1, 'PTO', DEFAULT)
	UNION
	SELECT
	'AddFromLateAdmissionOrder' AS [action]
	,i.intervention_id
	,i.intervention_template_id
	,ISNULL((SELECT TOP 1 _cg.goal_id FROM Careplan_Goal _cg WHERE _cg.episode_id = @episode_id AND _cg.goal_group_id IN(SELECT cg.goal_group_id FROM Careplan_Goal cg WHERE cg.episode_id = @episode_id AND cg.goal_id = i.goal_id AND COALESCE(cg.is_deleted,0) = 0) AND _cg.page_source = 'PTO' AND _cg.pto_id = @pto_id AND COALESCE(_cg.is_deleted,0) = 0), i.goal_id) AS goal_id
	,i.intervention_desc
	,i.intervention_status
	,i.intervention_source
	,i.intervention_group_id
	,i.page_source
	,CONVERT(VARCHAR(10), i.created_date, 101) created_date
	,i.created_by
	,i.m0020_pat_id
	,i.patient_intake_id
	,i.episode_id
	,i.pto_id
	,i.oasis_id
	,i.poc_id
	,CAST(i.goal_outcome AS VARCHAR) goal_outcome
	,ISNULL(i.initiated_by, -1) initiated_by
	,cg1.display_name AS initiated_by_name
	,CASE WHEN i.initiated_date IS NULL OR i.initiated_date = '01/01/0001' THEN NULL ELSE CONVERT(VARCHAR, i.initiated_date, 101) END initiated_date
	,ISNULL(i.resolved_by, -1) resolved_by
	,cg2.display_name AS resolved_by_name
	,CASE WHEN i.resolved_date IS NULL OR i.resolved_date = '01/01/0001' THEN NULL ELSE CONVERT(VARCHAR, i.resolved_date, 101) END resolved_date
	,intcom.comment_total
	FROM CarePlan_Intervention i
	LEFT JOIN(
		SELECT c1.Caregiver_Id, c1.last_name + ', ' + c1.first_name + coalesce('' + c1.middle_initial, '') + coalesce(' ' + coalesce(rtrim(c1.title), rtrim(cgt1.caregivertype_code)), '') as name,
        c1.first_name + coalesce(' ' + c1.middle_initial, '') + ' ' + c1.last_name + coalesce(' ' + coalesce(rtrim(c1.title), rtrim(cgt1.caregivertype_code)), '') as display_name
		FROM caregiver c1
        JOIN caregivertype cgt1 on c1.caregivertype_id =  cgt1.caregivertype_id AND ISNULL(cgt1.IsDeleted, 0) = 0
		WHERE c1.is_active = 1 AND ISNULL(c1.Is_Deleted, 0) = 0
	) cg1 ON i.initiated_by = cg1.Caregiver_Id
	LEFT JOIN(
		SELECT c2.Caregiver_Id, c2.last_name + ', ' + c2.first_name + coalesce('' + c2.middle_initial, '') + coalesce(' ' + coalesce(rtrim(c2.title), rtrim(cgt2.caregivertype_code)), '') as name,
        c2.first_name + coalesce(' ' + c2.middle_initial, '') + ' ' + c2.last_name + coalesce(' ' + coalesce(rtrim(c2.title), rtrim(cgt2.caregivertype_code)), '') as display_name
		FROM caregiver c2
        JOIN caregivertype cgt2 on c2.caregivertype_id =  cgt2.caregivertype_id AND ISNULL(cgt2.IsDeleted, 0) = 0
		WHERE c2.is_active = 1 AND ISNULL(c2.Is_Deleted, 0) = 0
	) cg2 ON i.resolved_by = cg2.Caregiver_Id
	CROSS APPLY 
   ( 
	   SELECT COUNT(1) comment_total FROM Careplan_Intervention_Comment com
	   WHERE com.intervention_id = i.intervention_group_id AND ISNULL(com.is_Deleted, 0) = 0
   ) intcom 
	WHERE i.episode_id = @episode_id AND i.page_source = 'OASIS' AND i.intervention_source = 'OASIS'
	AND (i.pto_id = @pto_id OR i.pto_id = @referred_pto_id)
	AND ISNULL(i.is_deleted, 0) = 0
	AND i.intervention_group_id NOT IN (SELECT _i.intervention_group_id FROM CarePlan_Intervention _i WHERE _i.episode_id = @episode_id AND COALESCE(_i.is_deleted,0) = 0 AND _i.page_source = 'PTO' AND _i.pto_id = @pto_id)

	--CarePlan Intervention Comment
	SELECT * FROM dbo.Func_GetAllCarePlanInterventionCommentByEpisodeId(@episode_id, @pto_id, -1, -1, 'PTO', NULL)  ORDER BY COALESCE(visit_date, created_timestamp), CASE WHEN visit_date IS NOT NULL THEN created_timestamp END

	--CarePlan Care Goal Comment
	SELECT * FROM dbo.Func_GetAllCarePlanCareGoalCommentByEpisodeId(@episode_id, @pto_id, -1, -1, 'PTO', NULL)  ORDER BY COALESCE(visit_date, created_timestamp), CASE WHEN visit_date IS NOT NULL THEN created_timestamp END

END

GO

