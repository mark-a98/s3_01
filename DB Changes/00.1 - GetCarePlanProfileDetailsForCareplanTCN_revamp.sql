USE [IDOneSourceHomeHealth]
GO

/****** Object:  StoredProcedure [dbo].[GetCarePlanProfileDetailsForCareplanTCN_revamp]    Script Date: 2/19/2025 10:26:50 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




    
-- =============================================    
-- Author:  <Author,,Name>    
-- Create date: <Create Date,,>    
-- Description: <Description,,>    
-- ============================================= 

--	UPDATED BY: MARK A.
--	UPDATED ON: 05/29/2024
--	DESCRIPTION: ADDED CARE GOAL COMMENTS TO THE RESULT

-- UPDATED BY: Mark A.
-- UPDATED ON: 07/15/2024
-- DESCRIPTION: Date of visit note care plan comments will based on visit date and only comments from prior date will be shown

-- UPDATED BY: Mark A.
-- UPDATED ON: 09/03/2024
-- DESCRIPTION: Lock target date column

ALTER PROCEDURE [dbo].[GetCarePlanProfileDetailsForCareplanTCN_revamp]    
 @episode_id BIGINT,    
 @severity_of_care_problem INT = NULL,    
 @initiated_date_from DATE = NULL,    
 @initiated_date_to DATE = NULL,    
 @resolved_date_from DATE = NULL,    
 @resolved_date_to DATE = NULL,    
 @goal_outcome INT = NULL,    
 @target_type VARCHAR(20) = 'All',    
 @pending_day INT = 0,    
 @initiated_by BIGINT = NULL,    
 @resolved_by BIGINT = NULL,  
 @cg_note_id BIGINT = NULL,
 @cg_note_id_for_comments_use BIGINT = NULL
AS    
BEGIN    
    
 SET NOCOUNT ON;
 
 --Begin Check if there is careplan data bounded to visit note
 DECLARE @cgNoteHasCarePlan INT = 0
 SELECT @cgNoteHasCarePlan =  COUNT(*) FROM CarePlan_Problem WHERE cg_note_id = @cg_note_id AND COALESCE(is_deleted,0) = 0
 IF @cgNoteHasCarePlan = 0
 BEGIN
	SET @cg_note_id = NULL
 END
 --End Check if there is careplan data bounded to visit note

    
 DECLARE @ProblemTempTable TABLE (    
 problem_id BIGINT    
 ,problem_template_id BIGINT    
 ,bodysystem_id BIGINT    
 ,bodysystem_desc NVARCHAR(MAX)    
 ,problem_desc NVARCHAR(MAX)    
 ,problem_status VARCHAR(100)    
 ,problem_source VARCHAR(50)    
 ,problem_group_id BIGINT    
 ,page_source VARCHAR(50)    
 ,related_to_hhc_diag INT    
 ,severity_of_care_problem INT    
 ,created_date DATETIME)    
    
 INSERT INTO @ProblemTempTable    
 SELECT    
 problem_id,    
 problem_template_id,    
 bodysystem_id,    
 bodysystem_desc,    
 problem_desc,     
 problem_status,     
 problem_source,     
 problem_group_id,     
 page_source,     
 related_to_hhc_diag,     
 severity_of_care_problem,    
 created_date    
 FROM dbo.Func_GetAllCarePlanProblemProfileByEpisodeId(@episode_id, NULL,@cg_note_id)    
    
 DECLARE @CareGoalTempTable TABLE (    
 goal_id BIGINT    
 ,caregoal_template_id BIGINT    
 ,problem_id BIGINT    
 ,goal_desc NVARCHAR(MAX)    
 ,goal_status VARCHAR(20)    
 ,goal_source VARCHAR(20)    
 ,goal_group_id BIGINT    
 ,page_source VARCHAR(20)    
 ,target_date DATE    
 ,goal_setfor INT    
 ,resolution_date DATE    
 ,comment NVARCHAR(MAX),
 pto_id BIGINT,
 oasis_id BIGINT,
 poc_id BIGINT,
 tcn_id BIGINT,
 cg_note_id BIGINT,
 lockTargetDate BIT
 
 
 )    
    
 INSERT INTO @CareGoalTempTable    
 SELECT    
 goal_id    
 ,caregoal_template_id    
 ,problem_id    
 ,goal_desc    
 ,goal_status    
 ,goal_source    
 ,goal_group_id    
 ,page_source    
 ,target_date    
 ,goal_setfor    
 ,resolution_date    
 ,comment,
 pto_id,
 oasis_id,
 poc_id,
 tcn_id,
 cg_note_id,
 lockTargetDate
    FROM dbo.Func_GetAllCarePlanCareGoalProfileByEpisodeId(@episode_id, 0,@cg_note_id)    
    
    
 DECLARE @InterventionTempTable TABLE (    
 intervention_id BIGINT    
 ,intervention_template_id BIGINT    
 ,goal_id BIGINT    
 ,intervention_desc NVARCHAR(MAX)    
 ,intervention_status VARCHAR(100)    
 ,intervention_source VARCHAR(20)    
 ,intervention_group_id BIGINT    
 ,goal_outcome INT    
 ,initiated_by INT    
 ,initiated_date DATE    
 ,resolved_by INT    
 ,resolved_date DATE    
 ,page_source VARCHAR(20)    
 ,initiated_by_name NVARCHAR(MAX)    
 ,resolved_by_name NVARCHAR(MAX))    
    
 INSERT INTO @InterventionTempTable    
 SELECT    
 intervention_id    
 ,intervention_template_id    
 ,goal_id    
 ,intervention_desc    
 ,intervention_status    
 ,intervention_source    
 ,intervention_group_id    
 ,goal_outcome    
 ,initiated_by    
 ,initiated_date    
 ,resolved_by    
 ,resolved_date    
 ,page_source    
 ,initiated_by_name    
 ,resolved_by_name    
 FROM dbo.Func_GetAllCarePlanInterventionProfileByEpisodeId(@episode_id, NULL, NULL, NULL, NULL, NULL, 0, @cg_note_id)    
    
 DECLARE @no_initiated_date BIT, @no_resolved_date BIT    
    
 SET @no_initiated_date = CASE WHEN @initiated_date_from IS NULL AND @initiated_date_to IS NULL THEN 1 ELSE 0 END;    
 SET @no_resolved_date = CASE WHEN @resolved_date_from IS NULL AND @resolved_date_to IS NULL THEN 1 ELSE 0 END;    
    
 --Problem    
 SELECT DISTINCT     
 1 AS isfromProfileTCN,    
 p.problem_group_id AS problem_id    
 ,p.problem_template_id    
 ,p.bodysystem_desc    
 ,p.bodysystem_id    
 ,p.problem_desc    
 ,p.problem_status    
 ,p.problem_source    
 ,p.problem_group_id    
 ,p.page_source    
 ,CAST(p.related_to_hhc_diag AS VARCHAR) related_to_hhc_diag    
 ,CAST(p.severity_of_care_problem AS VARCHAR) severity_of_care_problem    
 ,CONVERT(VARCHAR, p.created_date, 101) created_date
 ,@cgNoteHasCarePlan as cgNoteHasCarePlan
 FROM @ProblemTempTable p    
 LEFT JOIN @CareGoalTempTable g ON g.problem_id = p.problem_id    
 LEFT JOIN @InterventionTempTable i ON i.goal_id = g.goal_id    
 WHERE     
 (@target_type <> 'Missed' OR (g.target_date < CONVERT(VARCHAR, GETDATE(), 101) AND p.problem_status <> 'resolved'))    
 AND (@target_type <> 'Pending' OR (g.target_date > CONVERT(VARCHAR, GETDATE(), 101) AND g.target_date <= DATEADD(DAY, @pending_day, CONVERT(VARCHAR, GETDATE(), 101)) AND p.problem_status = 'inprog'))    
 AND (@no_initiated_date <> 0 OR (i.initiated_date BETWEEN ISNULL(@initiated_date_from, i.initiated_date) AND ISNULL(@initiated_date_to, i.initiated_date)))    
 AND (@no_resolved_date <> 0 OR i.resolved_date BETWEEN ISNULL(@resolved_date_from, resolved_date) AND ISNULL(@resolved_date_to, resolved_date))    
 AND (@goal_outcome IS NULL OR i.goal_outcome = @goal_outcome)    
 AND (@severity_of_care_problem IS NULL OR p.severity_of_care_problem = @severity_of_care_problem)    
 AND (@initiated_by IS NULL OR i.initiated_by = @initiated_by)    
 AND (@resolved_by IS NULL OR i.resolved_by = @resolved_by)    
    
 --CareGoal    
 SELECT DISTINCT     
 1 AS isfromProfileTCN,    
 g.goal_group_id AS goal_id     
 ,g.problem_id    
 ,g.caregoal_template_id    
 ,g.goal_desc    
 ,g.goal_status    
 ,g.goal_source    
 ,g.goal_group_id    
 ,g.page_source    
 ,CASE WHEN g.target_date IS NULL OR g.target_date = '01/01/1900' THEN '' ELSE CONVERT(VARCHAR, g.target_date, 101) END target_date     
 ,CAST(g.goal_setfor AS VARCHAR) goal_setfor      
 ,CASE WHEN g.resolution_date IS NULL OR g.resolution_date = '01/01/1900' THEN '' ELSE CONVERT(VARCHAR, g.resolution_date, 101) END resolution_date     
 ,g.comment    
 ,CASE WHEN g.target_date < CONVERT(VARCHAR, GETDATE(), 101) AND p.problem_status <> 'resolved' THEN 1 ELSE 0 END is_target_missed
 ,@cgNoteHasCarePlan as cgNoteHasCarePlan,
 gcom.comment_total,
 g.pto_id,
 g.oasis_id,
 g.poc_id,
 g.tcn_id,
 g.cg_note_id,
 g.lockTargetDate
 FROM @CareGoalTempTable g    
 LEFT JOIN @ProblemTempTable p ON g.problem_id = p.problem_id    
 LEFT JOIN @InterventionTempTable i ON i.goal_id = g.goal_id
 CROSS APPLY     
 (     
    SELECT COUNT(1) comment_total FROM Careplan_CareGoal_Comment com
	
	LEFT JOIN (
		SELECT
			_vp.Scheduled_Visit_Date,
			_v.Actual_Visit_Date
		FROM CaregiverNote _cgn
		LEFT JOIN Visits _v ON _v.visit_id = _cgn.visit_id
		LEFT JOIN VisitPlan _vp ON _vp.visit_plan_id = _cgn.visit_plan_id
		WHERE _cgn.cg_note_id = @cg_note_id_for_comments_use
		
	) v ON 1 = 1

    WHERE com.goal_group_id = g.goal_group_id AND ISNULL(com.is_Deleted, 0) = 0
	AND
	(
		(COALESCE(@cg_note_id_for_comments_use,0) NOT IN(-1,0) AND COALESCE(com.visit_date, com.created_date) <=  COALESCE(v.Actual_Visit_Date, v.Scheduled_Visit_Date))
		OR
		(COALESCE(@cg_note_id_for_comments_use,0)IN(-1,0))
	)
 ) gcom 
 WHERE     
 (@target_type <> 'Missed' OR (g.target_date < CONVERT(VARCHAR, GETDATE(), 101) AND p.problem_status <> 'resolved'))    
 AND (@target_type <> 'Pending' OR (g.target_date > CONVERT(VARCHAR, GETDATE(), 101) AND g.target_date <= DATEADD(DAY, @pending_day, CONVERT(VARCHAR, GETDATE(), 101)) AND p.problem_status = 'inprog'))    
 AND (@no_initiated_date <> 0 OR (i.initiated_date BETWEEN ISNULL(@initiated_date_from, i.initiated_date) AND ISNULL(@initiated_date_to, i.initiated_date)))    
 AND (@no_resolved_date <> 0 OR i.resolved_date BETWEEN ISNULL(@resolved_date_from, resolved_date) AND ISNULL(@resolved_date_to, resolved_date))    
 AND (@goal_outcome IS NULL OR i.goal_outcome = @goal_outcome)    
 AND (@severity_of_care_problem IS NULL OR p.severity_of_care_problem = @severity_of_care_problem)    
 AND (@initiated_by IS NULL OR i.initiated_by = @initiated_by)    
 AND (@resolved_by IS NULL OR i.resolved_by = @resolved_by)    
    
 --Intervention    
 SELECT DISTINCT     
 1 AS isfromProfileTCN,    
 i.intervention_id    
 ,i.intervention_template_id    
 ,i.goal_id    
 ,i.intervention_desc    
 ,i.intervention_status    
 ,i.intervention_source    
 ,i.intervention_group_id    
 ,i.page_source    
 ,CAST(i.goal_outcome AS VARCHAR) goal_outcome    
 ,i.initiated_by    
 ,i.initiated_by_name    
 ,CASE WHEN i.initiated_date IS NULL OR i.initiated_date = '0001-01-01' THEN '' ELSE CONVERT(VARCHAR, i.initiated_date, 101) END initiated_date    
 ,i.resolved_by    
 ,i.resolved_by_name    
 ,CASE WHEN i.resolved_date IS NULL OR i.resolved_date = '0001-01-01' THEN '' ELSE CONVERT(VARCHAR, i.resolved_date, 101) END resolved_date    
 ,intcom.comment_total
 ,@cgNoteHasCarePlan as cgNoteHasCarePlan
 FROM @InterventionTempTable i    
 CROSS APPLY     
 (     
    SELECT COUNT(1) comment_total FROM Careplan_Intervention_Comment com
	
	LEFT JOIN (
		SELECT
			_vp.Scheduled_Visit_Date,
			_v.Actual_Visit_Date
		FROM CaregiverNote _cgn
		LEFT JOIN Visits _v ON _v.Visit_Id = _cgn.visit_id
		LEFT JOIN VisitPlan _vp ON _vp.visit_plan_id = _cgn.visit_plan_id
		WHERE _cgn.cg_note_id = @cg_note_id_for_comments_use
	) v ON 1 = 1

    WHERE com.intervention_id = i.intervention_group_id AND ISNULL(com.is_Deleted, 0) = 0
	AND (
		(COALESCE(@cg_note_id_for_comments_use,0) NOT IN (-1, 0) AND COALESCE(com.visit_date, com.created_date) <= COALESCE(v.Actual_Visit_Date, v.Scheduled_Visit_Date))
		OR
		(COALESCE(@cg_note_id_for_comments_use,0) IN (-1,0))
	)
 ) intcom     
 WHERE    
 i.initiated_date BETWEEN ISNULL(@initiated_date_from, initiated_date) AND ISNULL(@initiated_date_to, initiated_date)    
 AND i.resolved_date BETWEEN ISNULL(@resolved_date_from, resolved_date) AND ISNULL(@resolved_date_to, resolved_date)    
 AND i.goal_outcome = ISNULL(@goal_outcome, i.goal_outcome)    
 AND i.initiated_by = ISNULL(@initiated_by, i.initiated_by)    
 AND i.resolved_by = ISNULL(@resolved_by, i.resolved_by)    
    
 --CarePlan Intervention Comment    
 SELECT 1 AS isfromProfileTCN, * FROM dbo.Func_GetAllCarePlanInterventionCommentByEpisodeId(@episode_id, -1, -1, -1,'', @cg_note_id_for_comments_use)  ORDER BY COALESCE(visit_date, created_timestamp), CASE WHEN visit_date IS NOT NULL THEN created_timestamp END
 
  --CarePlan Care Goal Comment    
 SELECT 1 AS isfromProfileTCN, * FROM dbo.Func_GetAllCarePlanCareGoalCommentByEpisodeId(@episode_id, -1, -1, -1,'', @cg_note_id_for_comments_use)  ORDER BY COALESCE(visit_date, created_timestamp), CASE WHEN visit_date IS NOT NULL THEN created_timestamp END
    
END    
GO

