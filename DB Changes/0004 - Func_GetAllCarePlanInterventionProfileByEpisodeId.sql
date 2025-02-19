GO

/****** Object:  UserDefinedFunction [dbo].[Func_GetAllCarePlanInterventionProfileByEpisodeId]    Script Date: 2/19/2025 10:06:27 AM ******/
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
-- 09/04/2024 - Mark A. Fix latest care plan profile
ALTER FUNCTION [dbo].[Func_GetAllCarePlanInterventionProfileByEpisodeId]  
(  
 -- Add the parameters for the function here  
 @episode_id BIGINT,  
 @initiated_date_from DATE,  
 @initiated_date_to DATE,  
 @resolved_date_from DATE,  
 @resolved_date_to DATE,  
 @goal_outcome INT,  
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
 
 
 
 latestintervention as  
 (  
  select ci.*  
  from CarePlan_Intervention ci  
  JOIN CarePlan_goal cg on cg.goal_id = ci.goal_id
  where ci.episode_id = @episode_id  
   and intervention_id in   
    (  
     select top 1 CarePlan_Intervention.intervention_id   
     from CarePlan_Intervention JOIN latest_document ON 1 = 1
	 INNER JOIN CarePlan_Goal on CarePlan_Goal.goal_id = CarePlan_Intervention.goal_id
     where CarePlan_Intervention.intervention_template_id = ci.intervention_template_id AND CarePlan_Intervention.intervention_group_id = ci.intervention_group_id  and CarePlan_Goal.caregoal_template_id = cg.caregoal_template_id and CarePlan_Goal.goal_group_id = cg.goal_group_id
     and CarePlan_Intervention.episode_id = @episode_id
	 and case when NOT COALESCE(@cg_note_id,'') = '' THEN @cg_note_id ELSE COALESCE(CarePlan_Intervention.cg_note_id,0) END = COALESCE(CarePlan_Intervention.cg_note_id,0)
	and
	COALESCE(CarePlan_Intervention.is_deleted,0) = 0
	and
	(
		(COALESCE(@cg_note_id,0) = 0 AND latest_document.latest_doc_type in ('VisitPlan-PTO', 'PTO') and CarePlan_Intervention.pto_id = latest_document.latest_doc_key AND CarePlan_Intervention.page_source IN ('VisitPlan-PTO', 'PTO'))
		OR (COALESCE(@cg_note_id,0) IN (-1, 0) AND latest_document.latest_doc_type in ('OASIS') and CarePlan_Intervention.page_source IN ('OASIS'))
		OR (COALESCE(@cg_note_id,0) IN (-1, 0) AND latest_document.latest_doc_type in ('POC') and CarePlan_Intervention.page_source IN ('POC') AND CarePlan_Intervention.poc_id = latest_document.latest_doc_key)
		OR (COALESCE(@cg_note_id,0) = 0 AND latest_document.latest_doc_type in ('TCN') and CarePlan_Intervention.tcn_id = latest_document.latest_doc_key AND CarePlan_Intervention.page_source IN ('TCN'))
		OR (COALESCE(@cg_note_id,0) = 0 AND latest_document.latest_doc_type in ('VisitPlan-TCN') and CarePlan_Intervention.cg_note_id = latest_document.latest_doc_key AND CarePlan_Intervention.page_source IN ('VisitPlan-TCN'))
		OR (COALESCE(@cg_note_id,0) NOT IN (-1, 0) AND  COALESCE(@cg_note_id,0) = COALESCE(CarePlan_Intervention.cg_note_id,0))
	)


	 order by CarePlan_Intervention.updated_date desc  
    )  
 )  
 SELECT  
   intervention_id  
  , intervention_template_id  
  , goal_id  
  , intervention_desc  
  , intervention_status  
  , intervention_source  
  , intervention_group_id  
  , page_source  
  , created_date  
  , created_by  
  , m0020_pat_id  
  , patient_intake_id  
  , episode_id  
  , pto_id  
  , oasis_id  
  , poc_id  
  , goal_outcome  
  , initiated_by  
  , initiated_by_name  
  , initiated_date  
  , resolved_by  
  , resolved_by_name  
  , resolved_date  
  , rownum  
  , comment_total 
  , goal_desc
  , is_resolved_here
 FROM  
 (  
  SELECT  
    i.intervention_id  
   , i.intervention_template_id  
   , CASE WHEN @isForPTO = 1 THEN cg.goal_id ELSE cg.goal_group_id END AS goal_id  
   , i.intervention_desc  
   , i.intervention_status  
   , i.intervention_source  
   , i.intervention_group_id  
   , i.page_source  
   , CASE WHEN i.created_date IS NULL OR i.created_date = '0001-01-01' THEN '' ELSE CONVERT(VARCHAR(10), i.created_date, 101) END created_date  
   , i.created_by  
   , i.m0020_pat_id  
   , i.patient_intake_id  
   , i.episode_id  
   , i.pto_id  
   , i.oasis_id  
   , i.poc_id  
   , CAST(i.goal_outcome AS VARCHAR) goal_outcome  
   , ISNULL(i.initiated_by, -1) initiated_by  
   , cg1.display_name AS initiated_by_name  
   , CASE WHEN i.initiated_date IS NULL OR i.initiated_date = '0001-01-01' THEN '' ELSE CONVERT(VARCHAR, i.initiated_date, 101) END initiated_date  
   , ISNULL(i.resolved_by, -1) resolved_by  
   , cg2.display_name AS resolved_by_name  
   , CASE WHEN i.resolved_date IS NULL OR i.resolved_date = '0001-01-01' THEN '' ELSE CONVERT(VARCHAR, i.resolved_date, 101) END resolved_date  
   , row_number() OVER(PARTITION BY intervention_group_id ORDER BY i.updated_date DESC) AS rownum  
   , intcom.comment_total  
   , cg.goal_desc
   , i.is_resolved_here
  FROM latestintervention i  
   INNER JOIN CarePlan_Goal cg ON i.goal_id = cg.goal_id  
   LEFT JOIN  
   (  
      SELECT   
       c1.Caregiver_Id, c1.last_name + ', ' + c1.first_name + coalesce('' + c1.middle_initial, '') + coalesce(' ' + coalesce(rtrim(c1.title), rtrim(cgt1.caregivertype_code)), '') as name,  
       c1.first_name + coalesce(' ' + c1.middle_initial, '') + ' ' + c1.last_name + coalesce(' ' + coalesce(rtrim(c1.title), rtrim(cgt1.caregivertype_code)), '') as display_name  
      FROM caregiver c1  
       JOIN caregivertype cgt1 on c1.caregivertype_id =  cgt1.caregivertype_id AND ISNULL(cgt1.IsDeleted, 0) = 0  
      WHERE   
       c1.is_active = 1 AND ISNULL(c1.Is_Deleted, 0) = 0  
   ) cg1 ON i.initiated_by = cg1.Caregiver_Id  
   LEFT JOIN  
   (  
    SELECT c2.Caregiver_Id, c2.last_name + ', ' + c2.first_name + coalesce('' + c2.middle_initial, '') + coalesce(' ' + coalesce(rtrim(c2.title), rtrim(cgt2.caregivertype_code)), '') as name,  
    c2.first_name + coalesce(' ' + c2.middle_initial, '') + ' ' + c2.last_name + coalesce(' ' + coalesce(rtrim(c2.title), rtrim(cgt2.caregivertype_code)), '') as display_name  
    FROM caregiver c2  
    JOIN caregivertype cgt2 on c2.caregivertype_id =  cgt2.caregivertype_id AND ISNULL(cgt2.IsDeleted, 0) = 0  
    WHERE c2.is_active = 1 AND ISNULL(c2.Is_Deleted, 0) = 0  
   ) cg2 ON i.resolved_by = cg2.Caregiver_Id  
   CROSS APPLY   
   (   
      SELECT COUNT(1) comment_total
	  FROM Careplan_Intervention_Comment com
	  
	  LEFT JOIN (
		SELECT
			_vp.Scheduled_Visit_Date,
			_v.Actual_Visit_Date
		FROM CaregiverNote _cgn
		LEFT JOIN Visits _v ON _v.visit_id = _cgn.visit_id
		LEFT JOIN VisitPlan _vp ON _vp.visit_plan_id = _cgn.visit_plan_id
		WHERE _cgn.cg_note_id = @cg_note_id
	  ) v ON 1 = 1

      WHERE com.intervention_id = i.intervention_group_id AND ISNULL(com.is_Deleted, 0) = 0  

	  AND (
		(COALESCE(@cg_note_id,0) NOT IN(-1,0) AND COALESCE(com.visit_date, com.created_date) <= COALESCE(v.Actual_Visit_Date, v.Scheduled_Visit_Date))
		OR
		(COALESCE(@cg_note_id,0) IN (-1, 0))
	  )

   ) intcom   
  WHERE   
   i.episode_id = @episode_id  
   AND ISNULL(i.is_deleted, 0) = 0  
 ) iterv  
 WHERE iterv.rownum = 1  
 AND initiated_date BETWEEN ISNULL(@initiated_date_from, initiated_date) AND ISNULL(@initiated_date_to, initiated_date)  
 AND resolved_date BETWEEN ISNULL(@resolved_date_from, resolved_date) AND ISNULL(@resolved_date_to, resolved_date)  
 AND goal_outcome = ISNULL(@goal_outcome, goal_outcome)  
)  
  
GO

