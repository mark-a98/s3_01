GO

/****** Object:  UserDefinedFunction [dbo].[Func_GetAllCarePlanProblemProfileByEpisodeId]    Script Date: 2/19/2025 9:50:32 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- 05/09/2024 - Mark A. Fix the latest document dates conflict with start episode and added priority
-- 05/20/2024 - Mark. A. Fix conflicting date of care plan order by adding time
-- 08/02/2024 - Mark. A. Make POC and OASIS as one document to be appeared in care plan profile based on their SOC document dates
-- 09/04/2024 - Mark A. Fix latest care plan profile
ALTER FUNCTION [dbo].[Func_GetAllCarePlanProblemProfileByEpisodeId]      
(      
 -- Add the parameters for the function here      
 @episode_id BIGINT,      
 @severity_of_care_problem INT = NULL,    
 @cg_note_id INT = NULL 
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
 
 latestprodlem as      
 (      
  select *      
  from CarePlan_Problem cp      
  where episode_id = @episode_id      
   and problem_id in       
    (      
	select top 1 CarePlan_Problem.problem_id       
	from CarePlan_Problem JOIN latest_document ON 1 = 1

	where CarePlan_Problem.problem_template_id = cp.problem_template_id AND CarePlan_Problem.problem_group_id = cp.problem_group_id       
	and CarePlan_Problem.episode_id = @episode_id    
		/*and case when NOT COALESCE(@cg_note_id,0) = 0 THEN @cg_note_id ELSE COALESCE(CarePlan_Problem.cg_note_id,0) END = COALESCE(CarePlan_Problem.cg_note_id,0) --For getting only the profile bound to visit note*/
	and
	COALESCE(CarePlan_Problem.is_deleted,0) = 0
	and
	(
		(COALESCE(@cg_note_id,0) IN (-1, 0) AND latest_document.latest_doc_type in ('VisitPlan-PTO', 'PTO') and CarePlan_Problem.pto_id = latest_document.latest_doc_key AND CarePlan_Problem.page_source IN ('VisitPlan-PTO', 'PTO'))
		OR (COALESCE(@cg_note_id,0) IN (-1, 0) AND latest_document.latest_doc_type in ('OASIS') and CarePlan_Problem.page_source IN ('OASIS'))
		OR (COALESCE(@cg_note_id,0) IN (-1, 0) AND latest_document.latest_doc_type in ('POC') and CarePlan_Problem.page_source IN ('POC') and CarePlan_Problem.poc_id = latest_document.latest_doc_key)
		OR (COALESCE(@cg_note_id,0) IN (-1, 0) AND latest_document.latest_doc_type in ('TCN') and CarePlan_Problem.tcn_id = latest_document.latest_doc_key AND CarePlan_Problem.page_source IN ('TCN'))
		OR (COALESCE(@cg_note_id,0) IN (-1, 0) AND latest_document.latest_doc_type in ('VisitPlan-TCN') and CarePlan_Problem.cg_note_id = latest_document.latest_doc_key AND CarePlan_Problem.page_source IN ('VisitPlan-TCN'))
		OR (COALESCE(@cg_note_id,0) NOT IN (-1, 0) AND  COALESCE(@cg_note_id,0) = COALESCE(CarePlan_Problem.cg_note_id,0))
	)

	order by CarePlan_Problem.updated_date desc       
      
    )      
 )      
 SELECT      
   problem_id      
  , problem_template_id      
  , bodysystem_id      
  , problem_desc      
  , problem_status      
  , problem_source      
  , problem_group_id      
  , page_source      
  , related_to_hhc_diag      
  , severity_of_care_problem      
  , m0020_pat_id      
  , patient_intake_id      
  , episode_id      
  , pto_id      
  , oasis_id      
  , poc_id       
  , bodysystem_desc      
  , created_date
  , is_resolved_here  
 FROM      
 (      
  SELECT       
    prob.problem_id      
   , prob.problem_template_id      
   , prob.bodysystem_id      
   , prob.problem_desc      
   , prob.problem_status      
   , prob.problem_source      
   , prob.problem_group_id      
   , prob.page_source      
   , CAST(prob.related_to_hhc_diag AS VARCHAR) related_to_hhc_diag      
   , CAST(prob.severity_of_care_problem AS VARCHAR) severity_of_care_problem      
   , prob.m0020_pat_id      
   , prob.patient_intake_id      
   , prob.episode_id      
   , prob.pto_id      
   , prob.oasis_id      
   , prob.poc_id       
   , CONVERT(VARCHAR, prob.created_date, 101) created_date      
   , ISNULL(body.bodysystem_template_desc, 'None') AS bodysystem_desc      
   , row_number() OVER(PARTITION BY problem_group_id ORDER BY prob.updated_date DESC) AS rownum
   , prob.is_resolved_here      
  FROM       
   latestprodlem prob      
   LEFT JOIN CarePlan_BodySystem_Template body ON prob.bodysystem_id = body.bodysystem_id       
   AND ISNULL(body.is_Deleted, 0) = 0      
  WHERE       
   prob.episode_id = @episode_id      
   AND ISNULL(prob.is_deleted, 0) = 0      
 )      
 problem      
 where problem.rownum = 1      
 AND severity_of_care_problem = ISNULL(@severity_of_care_problem, severity_of_care_problem)      
) 
GO

