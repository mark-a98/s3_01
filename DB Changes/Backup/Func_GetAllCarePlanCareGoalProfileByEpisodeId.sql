USE [IDOneSourceHomeHealth]
GO

/****** Object:  UserDefinedFunction [dbo].[Func_GetAllCarePlanCareGoalProfileByEpisodeId]    Script Date: 2/19/2025 9:58:17 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





-- 05/09/2024 - Mark A. Fix the latest document dates conflict with start episode and added priority
-- 05/20/2024 - Mark. A. Fix conflicting date of care plan order by adding time

-- UPDATED BY: Mark A.
-- UPDATED ON: 07/15/2024
-- DESCRIPTION: Date of visit note care plan comments will based on visit date and only comments from prior date will be shown
-- 08/02/2024 - Mark. A. Make POC and OASIS as one document to be appeared in care plan profile based on their SOC document dates

-- UPDATED BY: Mark A.
-- UPDATED ON: 09/03/2024
-- DESCRIPTION: Lock target date
ALTER FUNCTION [dbo].[Func_GetAllCarePlanCareGoalProfileByEpisodeId] 
(   
 -- Add the parameters for the function here  
 @episode_id BIGINT,  
 @isForPTO BIT = 0,
 @cg_note_id BIGINT = NULL
)  
RETURNS TABLE   
AS  
RETURN   
(  
 WITH 

	latest_document as ( --CTE to get the latest document with careplan
		SELECT TOP 1
			doc_dates.doc_date AS latest_doc_date, 
			doc_dates.doc_type AS latest_doc_type,
			doc_dates.doc_key AS latest_doc_key
		FROM (
			--Get POC care plan data. The document date for the POC was based on the OASIS(SOC, ROC and Recert) dates accordingly - Mark A.
			SELECT TOP 1 CASE WHEN o.m0100_assmt_reason = '01' THEN CAST(o.m0030_start_care_dt AS DATE) WHEN o.m0100_assmt_reason = '03' THEN CAST(o.m0032_roc_dt AS DATE) ELSE CAST(pto.call_date AS DATE) END AS doc_date, 'POC' AS doc_type, cp.poc_id AS doc_key, 1 AS group_priority, 1 if_same_doc_date_priority FROM CarePlan_Problem cp JOIN POC p ON p.pocid = cp.poc_id JOIN OASIS o ON o.oasisid = p.oasisid JOIN PTO pto ON pto.pto_id = p.pto_id WHERE cp.episode_id = @episode_id AND COALESCE(cp.is_deleted, 0) = 0 AND cp.page_source = 'POC' ORDER BY CASE WHEN o.m0100_assmt_reason = '01' THEN o.m0030_start_care_dt WHEN o.m0100_assmt_reason = '03' THEN o.m0032_roc_dt ELSE pto.call_date END DESC

			UNION 

			--The document date for PTO, TCN, VisitPlan-TCN was based on their dates accordingly - Mark A.
			SELECT call_date +  CAST(call_time AS TIME) AS doc_date, 'PTO' AS doc_type, pto_id AS doc_key, 1 AS group_priority, 1 if_same_doc_date_priority FROM PTO WHERE COALESCE(order_type,'') = 'CarePlanOrder' AND episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND pto_id IN (SELECT cp.pto_id FROM CarePlan_Problem cp WHERE episode_id = @episode_id AND COALESCE(cp.is_deleted,0) = 0 AND cp.page_source = 'PTO')
			UNION
			SELECT call_date +  CAST(call_time AS TIME) AS doc_date, 'TCN' AS doc_type, tcn_id AS doc_key, 1 AS group_priority, 1 if_same_doc_date_priority FROM TelCommunicationNote WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND tcn_id IN (SELECT cp.tcn_id FROM CarePlan_Problem cp WHERE episode_id = @episode_id AND COALESCE(cp.is_deleted,0) = 0 AND cp.page_source IN ('TCN'))
			UNION
			SELECT v.Actual_Visit_Date AS doc_date, 'VisitPlan-TCN' AS doc_type, cgn.cg_note_id AS doc_key, 1 AS group_priority, 2 if_same_doc_date_priority  FROM CaregiverNote cgn JOIN Visits v ON v.Visit_Id = cgn.visit_id WHERE COALESCE(cgn.is_deleted,0) = 0 AND cgn.cg_note_id IN (SELECT cp.cg_note_id FROM CarePlan_Problem cp WHERE episode_id = @episode_id AND COALESCE(cp.is_deleted,0) = 0)
			UNION
			SELECT vp.Scheduled_Visit_Date AS doc_date, 'VisitPlan-TCN' AS doc_type, cgn.cg_note_id AS doc_key, 1 AS group_priority, 2 if_same_doc_date_priority  FROM CaregiverNote cgn JOIN VisitPlan vp ON vp.visit_plan_id = cgn.visit_plan_id WHERE  COALESCE(cgn.is_deleted,0) = 0 AND cgn.cg_note_id IN (SELECT cp.cg_note_id FROM CarePlan_Problem cp WHERE episode_id = @episode_id AND COALESCE(cp.is_deleted,0) = 0)
		
		) doc_dates
	
	ORDER BY doc_dates.group_priority DESC, doc_dates.doc_date DESC, doc_dates.if_same_doc_date_priority DESC
 
 ),
 
 latestcaregoal as  
 (  
  select cg.*  
  from CarePlan_Goal cg  
  INNER JOIN CarePlan_Problem cp on cg.problem_id = cp.problem_id
  where cg.episode_id = @episode_id  
   and goal_id in   
    (  
	select top 1 CarePlan_Goal.goal_id   
	from CarePlan_Goal JOIN latest_document ON 1 = 1
	INNER JOIN CarePlan_Problem on CarePlan_Problem.problem_id = CarePlan_Goal.problem_id
	where CarePlan_Goal.goal_group_id = cg.goal_group_id AND CarePlan_Goal.caregoal_template_id = cg.caregoal_template_id   and CarePlan_Problem.problem_template_id = cp.problem_template_id AND CarePlan_Problem.problem_group_id = cp.problem_group_id
	and CarePlan_Goal.episode_id = @episode_id
	and case when NOT COALESCE(@cg_note_id,'') = '' THEN @cg_note_id ELSE COALESCE(CarePlan_Goal.cg_note_id, 0) END = COALESCE(CarePlan_Goal.cg_note_id,0)
	and
	COALESCE(CarePlan_Goal.is_deleted, 0) = 0
	and
	(
		(COALESCE(@cg_note_id,0) = 0 AND latest_document.latest_doc_type in ('VisitPlan-PTO', 'PTO') and CarePlan_Goal.pto_id = latest_document.latest_doc_key AND CarePlan_Goal.page_source IN ('VisitPlan-PTO', 'PTO'))
		OR (COALESCE(@cg_note_id,0) IN (-1, 0) AND latest_document.latest_doc_type in ('OASIS') and CarePlan_Goal.page_source IN ('OASIS'))
		OR (COALESCE(@cg_note_id,0) IN (-1, 0) AND latest_document.latest_doc_type in ('POC') and CarePlan_Goal.page_source IN ('POC') AND CarePlan_Goal.poc_id = latest_document.latest_doc_key)
		OR (COALESCE(@cg_note_id,0) = 0 AND latest_document.latest_doc_type in ('TCN') and CarePlan_Goal.tcn_id = latest_document.latest_doc_key AND CarePlan_Goal.page_source IN ('TCN'))
		OR (COALESCE(@cg_note_id,0) = 0 AND latest_document.latest_doc_type in ('VisitPlan-TCN') and CarePlan_Goal.cg_note_id = latest_document.latest_doc_key AND CarePlan_Goal.page_source IN ('VisitPlan-TCN'))
		OR (COALESCE(@cg_note_id,0) NOT IN (-1, 0) AND  COALESCE(@cg_note_id,0) = COALESCE(CarePlan_Goal.cg_note_id,0))
	)
     
	 order by CarePlan_Goal.updated_date desc   
    )  
 )  
 SELECT   
   goal_id  
  , problem_id  
  , caregoal_template_id  
  , goal_desc  
  , goal_status  
  , goal_source  
  , goal_group_id  
  , page_source  
  , target_date   
  , goal_setfor  
  , resolution_date  
  , comment  
  , m0020_pat_id  
  , patient_intake_id  
  , episode_id  
  , pto_id  
  , oasis_id  
  , poc_id 
  , problem_desc
  , rownum,
  comment_total,
  tcn_id,
  cg_note_id,
  lockTargetDate
 FROM  
 (  
  SELECT   
    goal.goal_id  
   , CASE WHEN @isForPTO = 1 THEN prob.problem_id ELSE prob.problem_group_id END AS problem_id  
   , goal.caregoal_template_id  
   , goal.goal_desc  
   , goal.goal_status  
   , goal.goal_source  
   , goal.goal_group_id  
   , goal.page_source  
   , CASE WHEN goal.target_date IS NULL OR goal.target_date = '0001-01-01' THEN '' ELSE CONVERT(VARCHAR, goal.target_date, 101) END target_date   
   , CAST(goal.goal_setfor AS VARCHAR) goal_setfor  
   , CASE WHEN goal.resolution_date IS NULL OR goal.resolution_date = '0001-01-01' THEN '' ELSE CONVERT(VARCHAR, goal.resolution_date, 101) END resolution_date   
   , goal.comment  
   , goal.m0020_pat_id  
   , goal.patient_intake_id  
   , goal.episode_id  
   , goal.pto_id  
   , goal.oasis_id  
   , prob.problem_desc
   , goal.poc_id  
   , row_number() OVER(PARTITION BY goal.goal_group_id ORDER BY goal.updated_date DESC) AS rownum,
   gcom.comment_total,
   goal.tcn_id,
   goal.cg_note_id,
   CASE WHEN COALESCE(goalsource.goal_id,0) = 0 THEN 0 ELSE (CASE WHEN goal.goal_group_id = goal.goal_id THEN 0 ELSE 1 END)  END  lockTargetDate
  FROM latestcaregoal goal  
   INNER JOIN CarePlan_Problem prob ON goal.problem_id = prob.problem_id
   CROSS APPLY   
   (   
      SELECT COUNT(1) comment_total 
	  FROM 
	  Careplan_CareGoal_Comment com
	  
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
   ) gcom
   
   LEFT JOIN CarePlan_Goal goalsource ON goalsource.goal_id = goal.goal_group_id AND COALESCE(goalsource.is_deleted,0) = 0

  WHERE goal.episode_id = @episode_id  
   AND ISNULL(goal.is_deleted, 0) = 0  
 ) cgoal  
 where cgoal.rownum = 1  
)  
  
GO

