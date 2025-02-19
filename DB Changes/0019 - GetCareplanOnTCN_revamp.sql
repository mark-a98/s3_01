GO

/****** Object:  StoredProcedure [dbo].[GetCareplanOnTCN_revamp]    Script Date: 2/19/2025 9:17:07 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



    
-- =============================================    
-- Author:  <Author,,Name>    
-- Create date: <Create Date,,>    
-- Description: <Description,,>    
-- =============================================
-- MARK A. ONLY GET CARE PLAN FROM VISIT NOTE IF TCN IS 0 - 05/16/2024

--	UPDATED BY: MARK A.
--	UPDATED ON: 05/29/2024
--	DESCRIPTION: ADDED CARE GOAL COMMENTS


-- UPDATED BY: Mark A.
-- UPDATED ON: 07/15/2024
-- DESCRIPTION: Date of visit note care plan comments will based on visit date and only comments from prior date will be shown

ALTER PROCEDURE [dbo].[GetCareplanOnTCN_revamp]    
 @tcn_id BIGINT,    
 @episodeid BIGINT,  
 @cg_note_id BIGINT = NULL  
AS    
BEGIN    
    
 DECLARE @agencyModule INT;    
 DECLARE @currentEpisode INT;
 DECLARE @pageSource VARCHAR(50) = 'TCN'
 DECLARE @cg_note_id_for_comments_use BIGINT = @cg_note_id
    
 SELECT @agencyModule = SettingID FROM AgencyModuleSetting WHERE ISNULL(IsEnabled, 0) = 1;
 
 DECLARE @cgNoteHasCarePlan INT = 0;
 SELECT @cgNoteHasCarePlan =  COUNT(*) FROM CarePlan_Problem WHERE cg_note_id = @cg_note_id AND COALESCE(is_deleted,0) = 0
 IF @cgNoteHasCarePlan = 0
 BEGIN
	SET @cg_note_id = NULL
 END


 IF(@agencyModule > 1)    
 BEGIN    
  SELECT TOP 1 @currentEpisode = Episode_Id     
  FROM PTO     
  WHERE patient_intake_id = @episodeid    
  AND order_type IN ('InitialIntake', 'AdmissionOrder', 'Recertification')    
  ORDER BY pto_id desc;    
 END    
 ELSE    
 BEGIN    
  SET @currentEpisode = @episodeid;    
 END    
    
 IF(@tcn_id = 0 AND COALESCE(@cg_note_id,0) = 0)    
 BEGIN     
  --SELECT  1 AS isfromProfileTCN, * FROM dbo.Func_GetAllCarePlanProblemProfileByEpisodeId(@episodeid, NULL)    
    
  --SELECT 1 AS isfromProfileTCN, * FROM dbo.Func_GetAllCarePlanCareGoalProfileByEpisodeId(@episodeid, 1)    
    
  --SELECT  1 AS isfromProfileTCN, * FROM dbo.Func_GetAllCarePlanInterventionProfileByEpisodeId(@episodeid, NULL,NULL,NULL,NULL,NULL, 1)    
    
  --SELECT  1 AS isfromProfileTCN, * FROM dbo.Func_GetAllCarePlanInterventionCommentByEpisodeId(@episodeid, -1, -1, -1, '')    
    
  EXEC [GetCarePlanProfileDetailsForCareplanTCN_revamp]    
  @episode_id = @currentEpisode,    
  @severity_of_care_problem  = NULL,    
  @initiated_date_from  = NULL,    
  @initiated_date_to  = NULL,    
  @resolved_date_from  = NULL,    
  @resolved_date_to  = NULL,    
  @goal_outcome  = NULL,    
  @target_type  = 'All',    
  @pending_day  = 0,    
  @initiated_by  = NULL,    
  @resolved_by  = NULL,  
  @cg_note_id = @cg_note_id,
  @cg_note_id_for_comments_use = @cg_note_id_for_comments_use
 END    
 ELSE    
 BEGIN
 
	IF(@tcn_id = 0)
	BEGIN
		SELECT @pageSource = 'VisitPlan-TCN';
	END

  SELECT *, @cgNoteHasCarePlan as cgNoteHasCarePlan FROM dbo.Func_GetAllCarePlanProblemByEpisodeId(@currentEpisode, -1, -1, -1, @tcn_id, @pageSource, @cg_note_id)    
    
  SELECT *, @cgNoteHasCarePlan as cgNoteHasCarePlan FROM dbo.Func_GetAllCarePlanCareGoalByEpisodeId(@currentEpisode, -1, -1, -1, @tcn_id, @pageSource, @cg_note_id)    
    
  SELECT *, @cgNoteHasCarePlan as cgNoteHasCarePlan FROM dbo.Func_GetAllCarePlanInterventionByEpisodeId(@currentEpisode, -1, -1, -1, @tcn_id, @pageSource, @cg_note_id)    
    
  SELECT * FROM dbo.Func_GetAllCarePlanInterventionCommentByEpisodeId(@currentEpisode, -1, -1, -1, @pageSource, @cg_note_id) ORDER BY COALESCE(visit_date, created_timestamp), CASE WHEN visit_date IS NOT NULL THEN created_timestamp END
  
  SELECT * FROM dbo.Func_GetAllCarePlanCareGoalCommentByEpisodeId(@currentEpisode, -1, -1, -1, @pageSource, @cg_note_id) ORDER BY COALESCE(visit_date, created_timestamp), CASE WHEN visit_date IS NOT NULL THEN created_timestamp END
 END    
    
END    
GO

