USE [IDOneSourceHomeHealth]
GO

/****** Object:  UserDefinedFunction [dbo].[Func_GetAllCarePlanCareGoalByEpisodeId]    Script Date: 2/19/2025 10:16:25 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




--	UPDATED BY: MARK A.
--	UPDATED ON: 05/24/2024
--	DESCRIPTION: Add care goal comment total and fix the where clause

-- UPDATED BY: Mark A.
-- UPDATED ON: 07/15/2024
-- DESCRIPTION: Date of visit note care plan comments will based on visit date and only comments from prior date will be shown


-- UPDATED BY: Mark A.
-- UPDATED ON: 09/03/2024
-- DESCRIPTION: Target date lock basis

ALTER FUNCTION [dbo].[Func_GetAllCarePlanCareGoalByEpisodeId]    
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
  goal.goal_id    
 ,goal.caregoal_template_id    
 ,goal.problem_id    
 ,goal.goal_desc    
 ,goal.goal_status    
 ,goal.goal_source    
 ,goal.goal_group_id    
 ,goal.page_source    
 ,CASE WHEN goal.target_date IS NULL OR goal.target_date = '01/01/0001' THEN '' ELSE CONVERT(VARCHAR, goal.target_date, 101) END target_date     
 ,CAST(goal.goal_setfor AS VARCHAR) goal_setfor    
 ,CASE WHEN goal.resolution_date IS NULL OR goal.resolution_date = '01/01/0001' THEN '' ELSE CONVERT(VARCHAR, goal.resolution_date, 101) END resolution_date     
 ,CASE WHEN @page_source ='POC' and goal.goal_source='VisitPlan-TCN' THEN '' ELSE goal.comment END as comment    
 ,goal.m0020_pat_id    
 ,goal.patient_intake_id    
 ,goal.episode_id    
 ,goal.pto_id    
 ,goal.oasis_id    
 ,goal.poc_id,
 goalcom.comment_total,
 goal.cg_note_id,
 goal.tcn_id,
 CASE WHEN COALESCE(goalsource.goal_id,0) = 0 THEN 0 ELSE (CASE WHEN goal.goal_group_id = goal.goal_id THEN 0 ELSE 1 END)  END  lockTargetDate
 

FROM CarePlan_Goal goal
CROSS APPLY   
(   
	SELECT COUNT(1) comment_total
	FROM Careplan_CareGoal_Comment com 
	LEFT JOIN (
		SELECT
			_vp.Scheduled_Visit_Date,
			_v.Actual_Visit_Date
		FROM CaregiverNote _cgn
		LEFT JOIN Visits _v ON _v.visit_id = _cgn.visit_id
		LEFT JOIN VisitPlan _vp ON _vp.visit_plan_id = _cgn.visit_plan_id
		WHERE _cgn.cg_note_id = @cg_note_id
		
	) v ON 1 = 1
	WHERE com.goal_group_id = goal.goal_group_id AND ISNULL(com.is_Deleted, 0) = 0
	AND
	(
		(COALESCE(@cg_note_id,0) NOT IN(-1,0) AND COALESCE(com.visit_date, com.created_date) <=  COALESCE(v.Actual_Visit_Date, v.Scheduled_Visit_Date))
		OR
		(COALESCE(@cg_note_id,0)IN(-1,0))
	)
) goalcom

LEFT JOIN CarePlan_Goal goalsource ON goalsource.goal_id = goal.goal_group_id AND COALESCE(goalsource.is_deleted,0) = 0

WHERE goal.episode_id = @episode_id


and (
		(@page_source in ('VisitPlan-PTO', 'PTO') and goal.pto_id = @pto_id and goal.page_source in ('VisitPlan-PTO', 'PTO'))
		OR (@page_source in ('OASIS') and goal.oasis_id = @oasis_id and goal.page_source = 'OASIS')
		OR (@page_source in ('POC') and goal.poc_id = @poc_id and goal.page_source = 'POC')
		OR (@page_source in ('VisitPlan-TCN') and goal.cg_note_id = @cg_note_id and goal.page_source = 'VisitPlan-TCN' )
		OR (@page_source in ('TCN') and goal.tcn_id = @tcn_id and goal.page_source = 'TCN')
	)

 
AND case 
		when goal.page_source in ('VisitPlan-TCN','VisitPlan-PTO') and @page_source in ('TCN', 'PTO') then @page_source
		else goal.page_source
	end = @page_source

AND ISNULL(goal.is_deleted, 0) = 0

/*
 FROM CarePlan_Goal goal    
 WHERE goal.episode_id = @episode_id     
 AND (case     
   when goal.page_source in ('VisitPlan-TCN') and @page_source in ('TCN', 'PTO') then @page_source    
   else goal.page_source    
  end = @page_source    
 OR (@page_source in ('VisitPlan-PTO', 'PTO') and goal.pto_id = @pto_id)    
 OR (@page_source in ('OASIS') and goal.oasis_id = @oasis_id)    
 OR (@page_source in ('POC') and goal.poc_id = @poc_id)    
 OR (@page_source in ('VisitPlan-TCN', 'TCN') and goal.tcn_id = @tcn_id)
 OR (@page_source in ('VisitPlan-TCN', 'TCN') and goal.cg_note_id = @cg_note_id)
 
 )   
 AND ISNULL(goal.is_deleted, 0) = 0    */





) 
GO

