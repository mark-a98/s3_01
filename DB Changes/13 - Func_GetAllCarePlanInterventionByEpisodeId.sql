GO

/****** Object:  UserDefinedFunction [dbo].[Func_GetAllCarePlanInterventionByEpisodeId]    Script Date: 2/19/2025 10:17:19 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



--	UPDATED BY: MARK A.
--	UPDATED ON: 05/14/2024
--	DESCRIPTION: FIX THE WHERE CLAUSE


-- UPDATED BY: Mark A.
-- UPDATED ON: 07/15/2024
-- DESCRIPTION: Date of visit note care plan comments will based on visit date and only comments from prior date will be shown

ALTER FUNCTION [dbo].[Func_GetAllCarePlanInterventionByEpisodeId]  
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
 i.intervention_id  
 ,i.intervention_template_id  
 ,i.goal_id  
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
 ,i.is_resolved_here  
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
    SELECT COUNT(1) comment_total
	FROM Careplan_Intervention_Comment com
	LEFT JOIN (
		SELECT
			_vp.Scheduled_Visit_Date,
			_v.Actual_Visit_Date
		FROM CaregiverNote _cgn
		LEFT JOIN Visits _v ON _v.Visit_Id = _cgn.visit_id
		LEFT JOIN VisitPlan _vp ON _vp.visit_plan_id = _cgn.visit_plan_id
		WHERE _cgn.cg_note_id = @cg_note_id
	) v ON 1 = 1
    WHERE com.intervention_id = i.intervention_group_id AND ISNULL(com.is_Deleted, 0) = 0
	AND
	(
		(COALESCE(@cg_note_id,0) NOT IN (-1,0) AND COALESCE(com.visit_date, com.created_date) <= COALESCE(v.Actual_Visit_Date, v.Scheduled_Visit_Date))
		OR
		(COALESCE(@cg_note_id,0) IN (-1,0))
	)
   ) intcom   
 
 
 /*WHERE i.episode_id = @episode_id   
 AND (case   
   when i.page_source in ('VisitPlan-TCN') and @page_source in ('TCN', 'PTO') then @page_source  
   else i.page_source  
  end = @page_source  
 or (@page_source in ('VisitPlan-PTO', 'PTO') and i.pto_id = @pto_id)  
 or (@page_source in ('OASIS') and i.oasis_id = @oasis_id)  
 or (@page_source in ('POC') and i.poc_id = @poc_id)  
 or (@page_source in ('VisitPlan-TCN', 'TCN') and i.tcn_id = @tcn_id)
 or (@page_source in ('VisitPlan-TCN', 'TCN') and i.cg_note_id = @cg_note_id)
 
 )  
 AND ISNULL(i.is_deleted, 0) = 0 */
 

 WHERE i.episode_id = @episode_id


and (
		(@page_source in ('VisitPlan-PTO', 'PTO') and i.pto_id = @pto_id and i.page_source in ('VisitPlan-PTO', 'PTO'))
		OR (@page_source in ('OASIS') and i.oasis_id = @oasis_id and i.page_source = 'OASIS')
		OR (@page_source in ('POC') and i.poc_id = @poc_id and i.page_source = 'POC')
		OR (@page_source in ('VisitPlan-TCN') and i.cg_note_id = @cg_note_id and i.page_source = 'VisitPlan-TCN' )
		OR (@page_source in ('TCN') and i.tcn_id = @tcn_id and i.page_source = 'TCN')
	)

 
AND case 
		when i.page_source in ('VisitPlan-TCN','VisitPlan-PTO') and @page_source in ('TCN', 'PTO') then @page_source
		else i.page_source
	end = @page_source

AND ISNULL(i.is_deleted, 0) = 0



)  
  
GO

