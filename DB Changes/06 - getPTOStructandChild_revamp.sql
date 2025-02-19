USE [IDOneSourceHomeHealth]
GO

/****** Object:  StoredProcedure [dbo].[getPTOStructandChild_revamp]    Script Date: 2/19/2025 9:21:36 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- UPDATED BY: MARK A.
-- UPDATED ON: 05/29/2024
-- DESCRIPTION: ADDED CARE GOAL COMMENTS TO THE RESULT SET

ALTER PROCEDURE [dbo].[getPTOStructandChild_revamp] 
	@pocid bigint,
	@ptoid bigint,
	@episodeId int,
	@agencyid varchar(50)
AS
BEGIN

	SELECT *, oasis_poc_id = null
	FROM PTO 
	WHERE 1 = 0; -- just get a structure
	
	SELECT * 
	FROM POCFrequencyVisit 
	WHERE pocid = @pocid
	AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0;  -- only get rows belong to pto
	
	SELECT a.[Medication_ID]
      ,a.[POCID]
      ,a.[pto_id]
      ,a.[drug_gen_id]
      ,Cast(a.[Med_Date] as date) as [Med_Date]
      ,a.[Medication_Name]
      ,a.[Dose]
      ,a.[Frequency]
      ,a.[Route]
      ,a.[Source]
      ,a.[Date_Disc]
      ,a.[OldNew]
      ,a.[Note]
      ,a.[Created_By]
      ,a.[Create_Date]
      ,a.[LAST_UPDATED_BY]
      ,a.[LAST_UPDATE_DATE]
      ,a.[IsFreeText]
      ,a.[sortorder]
      ,a.[DrugClassificationId]
      ,a.[Classification]
      ,a.[LaboratoryNeeded]
      ,a.[MPStatus]
      ,a.[discby_ptoid]
      ,a.[ROCOrderContID]
      ,a.[source_id]
      ,a.[prefill_fr_prev_episode]
      ,a.[is_after_poc_lock]
	  ,a.[AgencyId]	  
	  ,a.[isDeleted]
	FROM POCMedications a
	JOIN poc p on a.pocid = p.pocid AND p.AgencyId = ISNULL(@agencyId, p.AgencyId) AND ISNULL(p.IsDeleted, 0) = 0
	JOIN oasis o on p.oasisid = o.oasisid  AND o.AgencyId = ISNULL(@agencyId, o.AgencyId) AND ISNULL(o.IsDeleted, 0) = 0
	WHERE o.episode_id = @episodeId
	AND a.AgencyId = ISNULL(@agencyId, a.AgencyId) AND ISNULL(a.IsDeleted, 0) = 0;

	SELECT * 
	FROM VisitPlan
	WHERE episode_id = @episodeId
	and AgencyId = @agencyid AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0; -- get all visit belongs to episode

	SELECT *
	FROM oasis
	WHERE 1=0; -- just get a structure

	SELECT * 
	FROM poc
	WHERE pocid = @pocid AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0; -- just get a structure

	SELECT *
	FROM pocmedicationcont
	WHERE 1 = 0;   -- just get structure

	SELECT pa.*, coalesce(v.actual_visit_date, vp.scheduled_visit_date, pa.alert_effective_date) as alert_date
	FROM episode e
		JOIN patientalert pa ON e.patient_intake_id = pa.patient_intake_id AND pa.AgencyId = ISNULL(@agencyId, pa.AgencyId) AND ISNULL(pa.IsDeleted, 0) = 0
		LEFT JOIN caregivernote cgn ON pa.source = 'VN' and pa.source_id = cgn.cg_note_id AND cgn.AgencyId = ISNULL(@agencyId, cgn.AgencyId) AND ISNULL(cgn.Is_Deleted, 0) = 0
		LEFT JOIN visits v ON v.visit_id = cgn.visit_id AND v.AgencyId = ISNULL(@agencyId, v.AgencyId) AND ISNULL(v.IsDeleted, 0) = 0
        LEFT JOIN visitplan vp ON vp.visit_plan_id = cgn.visit_plan_id AND vp.AgencyId = ISNULL(@agencyId, vp.AgencyId) AND ISNULL(vp.IsDeleted, 0) = 0
	WHERE e.episode_id = @episodeId
	AND e.AgencyId = ISNULL(@agencyId, e.AgencyId) AND ISNULL(e.IsDeleted, 0) = 0
	ORDER BY alert_date;

		SELECT 
	   [Medication_ID]
      ,[POCID]
      ,ptoid AS [pto_id]
      ,[drug_gen_id]
      ,Cast([Med_Date] as date) as [Med_Date]
      ,[Medication_Name]
      ,[Dose]
      ,[Frequency]
      ,[Route]
      ,[Source]
      ,[Date_Disc]
      ,[OldNew]
      ,[Note]
      ,[Created_By]
      ,[Create_Date]
      ,[LAST_UPDATED_BY]
      ,[LAST_UPDATE_DATE]
      ,[IsFreeText]
      ,[sortorder]
      ,[DrugClassificationId]
      ,[Classification]
      ,[LaboratoryNeeded]
      ,[MPStatus]
      ,[discby_ptoid]
      ,[ROCOrderContID]
      ,[source_id]
      ,[prefill_fr_prev_episode]
      ,[is_after_poc_lock]
	  ,[AgencyId]	  
	  ,[isDeleted]
	  ,[group_by_med_id]	
	  ,[episode_id]
	  ,'false|' AS errmessage,
	  ISNULL([DispensableDrugID], 0) as DispensableDrugID
	  ,ISNULL([MedicationSourceID], 1) as MedicationSourceID
	FROM dbo.getMedicationByEpisode(@episodeId, @agencyId)
	ORDER BY [sortorder]

 SELECT *
	FROM Agency 
	WHERE agency_id_login = @agencyId

	----CarePlan Problem
	--SELECT  1 AS isfromProfile, * FROM dbo.Func_GetAllCarePlanProblemProfileByEpisodeId(@episodeid, NULL)

	----CarePlan Goal
	--SELECT 1 AS isfromProfile, * FROM dbo.Func_GetAllCarePlanCareGoalProfileByEpisodeId(@episodeid, 1)

	----CarePlan Intervention
	--SELECT  1 AS isfromProfile, * FROM dbo.Func_GetAllCarePlanInterventionProfileByEpisodeId(@episodeid, NULL,NULL,NULL,NULL,NULL, 1)

	----CarePlan Intervention Comment
	--SELECT  1 AS isfromProfile, * FROM dbo.Func_GetAllCarePlanInterventionCommentByEpisodeId(@episodeid, -1, -1, -1, 'PTO')

	EXEC [GetCarePlanProfileDetailsForCareplan_revamp]
	@episode_id = @episodeid,
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

	DECLARE @OasisId BIGINT
	SET @OasisId = (SELECT TOP 1 OasisId FROM POC WHERE POCID = @pocid AND ISNULL(isDeleted, 0) = 0)

	--CarePlan Problem Oasis
	SELECT * FROM dbo.Func_GetAllCarePlanProblemByEpisodeId(@episodeid, -1, @OasisId, -1, -1, 'OASIS', DEFAULT)

	--CarePlan Goal
	SELECT * FROM dbo.Func_GetAllCarePlanCareGoalByEpisodeId(@episodeid, -1, @OasisId, -1, -1, 'OASIS', DEFAULT)

	--CarePlan Intervention
	SELECT * FROM dbo.Func_GetAllCarePlanInterventionByEpisodeId(@episodeid, -1, @OasisId, -1, -1, 'OASIS', DEFAULT)
END

  
GO

