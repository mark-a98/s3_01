USE [IDOneSourceHomeHealth]
GO

/****** Object:  StoredProcedure [dbo].[SaveCarePlan_revamp]    Script Date: 2/17/2025 12:09:40 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO







-- Mark A. Add cg_note_id and fix the query - 11/14/2023
-- Mark A. 05/13/2024 - Auto update other care plan upon updating POC
-- Mark A. 05/17/2024 - Fix bug copying data when Saving VN Care Plan as Comm.Notes/PTO

-- UPDATED BY: Mark A.
-- UPDATED ON: 07/15/2024
-- DESCRIPTION: Date of visit note care plan comments will based on visit date and only comments from prior date will be shown

-- UPDATED BY: Mark A.
-- UPDATED ON: 08/05/2024
-- DESCRIPTION: Don't flow back data upon updating POC

-- UPDATED BY: Mark A.
-- UPDATED ON: 09/03/2024
-- DESCRIPTION: Bug fix when adding adata from oasis

ALTER PROCEDURE [dbo].[SaveCarePlan_revamp]  
 @problem_list AS XML,  
 @caregoal_list AS XML,  
 @intervention_list AS XML,  
 @intervention_comment_list AS XML,
 @caregoal_comment_list AS XML,
 @page_source VARCHAR(50),  
 @patient_id AS BIGINT,  
 @intake_id AS BIGINT,  
 @episode_id AS BIGINT,  
 @pto_id AS BIGINT,  
 @oasis_id AS BIGINT,  
 @poc_id AS BIGINT,  
 @tcn_id AS BIGINT,  
 @user_id AS VARCHAR(50),  
 @agencyId AS VARCHAR(50) = NULL,
 @cg_note_id AS BIGINT = NULL
AS  
BEGIN  
  
 SET NOCOUNT ON;  
 DECLARE @msg NVARCHAR(MAX);  
  
 BEGIN TRANSACTION  
 BEGIN TRY  
  
 DECLARE   
 @pbm_Action VARCHAR(100)  
 ,@pbm_problem_id BIGINT  
 ,@pbm_problem_template_id BIGINT  
 ,@pbm_bodysystem_id BIGINT  
 ,@pbm_problem_desc NVARCHAR(MAX)  
 ,@pbm_problem_status VARCHAR(100)  
 ,@pbm_problem_source VARCHAR(50)  
 ,@pbm_problem_group_id BIGINT  
 ,@pbm_page_source VARCHAR(50)  
 ,@pbm_related_to_hhc_diag BIT  
 ,@pbm_severity_of_care_problem INT  
 ,@pbm_episode_id BIGINT  
 ,@pbm_pto_id BIGINT  
 ,@pbm_oasis_id BIGINT  
 ,@pbm_poc_id BIGINT
 ,@pbm_add_option INT
 ,@pbm_edit_option INT
 ,@compound_edit_option INT
  
 ,@cg_Action VARCHAR(100)  
 ,@cg_goal_id BIGINT  
 ,@cg_caregoal_template_id BIGINT  
 ,@cg_problem_id BIGINT  
 ,@cg_goal_desc NVARCHAR(MAX)  
 ,@cg_goal_status VARCHAR(20)  
 ,@cg_goal_source VARCHAR(20)  
 ,@cg_goal_group_id BIGINT  
 ,@cg_page_source VARCHAR(20)  
 ,@cg_target_date DATE  
 ,@cg_goal_setfor INT  
 ,@cg_resolution_date DATE  
 ,@cg_comment NVARCHAR(MAX)  
 ,@cg_episode_id BIGINT  
 ,@cg_pto_id BIGINT  
 ,@cg_oasis_id BIGINT  
 ,@cg_poc_id BIGINT
 ,@cg_add_option INT
 ,@cg_edit_option INT
  
 ,@in_Action VARCHAR(100)  
 ,@in_intervention_id BIGINT  
 ,@in_intervention_template_id BIGINT  
 ,@in_goal_id BIGINT  
 ,@in_intervention_desc NVARCHAR(MAX)  
 ,@in_intervention_status VARCHAR(100)  
 ,@in_intervention_source VARCHAR(20)  
 ,@in_intervention_group_id BIGINT  
 ,@in_goal_outcome INT  
 ,@in_initiated_by INT  
 ,@in_initiated_date DATE  
 ,@in_resolved_by INT  
 ,@in_resolved_date DATE  
 ,@in_page_source VARCHAR(20)  
 ,@in_episode_id BIGINT  
 ,@in_pto_id BIGINT  
 ,@in_oasis_id BIGINT  
 ,@in_poc_id BIGINT
 ,@in_add_option INT
 ,@in_edit_option INT
  
 ,@com_Action VARCHAR(100)  
 ,@com_comment_id BIGINT  
 ,@com_intervention_id BIGINT  
 ,@com_comment NVARCHAR(MAX)  
 ,@com_comment_source VARCHAR(20)  
 ,@com_parent_comment_id BIGINT  
 ,@com_page_source VARCHAR(20)  
 ,@com_episode_id BIGINT  
 ,@com_pto_id BIGINT  
 ,@com_oasis_id BIGINT  
 ,@com_poc_id BIGINT
 

 ,@gcom_Action VARCHAR(100)  
 ,@gcom_comment_id BIGINT  
 ,@gcom_goal_group_id BIGINT  
 ,@gcom_comment NVARCHAR(MAX)  
 ,@gcom_comment_source VARCHAR(20)  
 ,@gcom_parent_comment_id BIGINT  
 ,@gcom_page_source VARCHAR(20)  
 ,@gcom_episode_id BIGINT  
 ,@gcom_pto_id BIGINT  
 ,@gcom_oasis_id BIGINT  
 ,@gcom_poc_id BIGINT
  
 DECLARE @ProblemTempTable TABLE (  
 [Action] VARCHAR(100)  
 ,problem_id BIGINT  
 ,problem_template_id BIGINT  
 ,bodysystem_id BIGINT  
 ,problem_desc NVARCHAR(MAX)  
 ,problem_status VARCHAR(100)  
 ,problem_source VARCHAR(50)  
 ,problem_group_id BIGINT  
 ,page_source VARCHAR(50)  
 ,related_to_hhc_diag BIT  
 ,severity_of_care_problem INT  
 ,episode_id BIGINT  
 ,pto_id BIGINT  
 ,oasis_id BIGINT  
 ,poc_id BIGINT
 ,add_option INT
 ,edit_option INT
 )  
  
 DECLARE @CareGoalTempTable TABLE (  
 [Action] VARCHAR(100)  
 ,goal_id BIGINT  
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
 ,comment NVARCHAR(MAX)  
 ,episode_id BIGINT  
 ,pto_id BIGINT  
 ,oasis_id BIGINT  
 ,poc_id BIGINT
 ,add_option INT
 ,edit_option INT
 )  
  
 DECLARE @InterventionTempTable TABLE (  
 [Action] VARCHAR(100)  
 ,intervention_id BIGINT  
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
 ,episode_id BIGINT  
 ,pto_id BIGINT  
 ,oasis_id BIGINT  
 ,poc_id BIGINT
 ,add_option INT
 ,edit_option INT
 )  
  
 DECLARE @InterventionCommentTempTable TABLE (  
 [Action] VARCHAR(100),  
 comment_id BIGINT,  
 intervention_id BIGINT,  
 comment NVARCHAR(MAX),  
 comment_source VARCHAR(20),  
 parent_comment_id BIGINT,  
 page_source VARCHAR(20),  
 episode_id BIGINT,  
 pto_id BIGINT,  
 oasis_id BIGINT,  
 poc_id BIGINT)
 

 DECLARE @CareGoalCommentTempTable TABLE (  
 [Action] VARCHAR(100),  
 comment_id BIGINT,  
 goal_group_id BIGINT,  
 comment NVARCHAR(MAX),  
 comment_source VARCHAR(20),  
 parent_comment_id BIGINT,  
 page_source VARCHAR(20),  
 episode_id BIGINT,  
 pto_id BIGINT,  
 oasis_id BIGINT,  
 poc_id BIGINT) 

  
 INSERT INTO @ProblemTempTable  
 SELECT  
 Tbl.Col.value('Action[1]', 'VARCHAR(100)') AS [Action],  
 Tbl.Col.value('problem_id[1]', 'BIGINT') AS problem_id,  
 Tbl.Col.value('problem_template_id[1]', 'BIGINT') AS problem_template_id,  
 Tbl.Col.value('bodysystem_id[1]', 'BIGINT') AS bodysystem_id,  
 Tbl.Col.value('problem_desc[1]', 'NVARCHAR(MAX)') AS problem_desc,   
 Tbl.Col.value('problem_status[1]', 'VARCHAR(100)') AS problem_status,   
 Tbl.Col.value('problem_source[1]', 'VARCHAR(50)') AS problem_source,   
 Tbl.Col.value('problem_group_id[1]', 'BIGINT') AS problem_group_id,   
 Tbl.Col.value('page_source[1]', 'VARCHAR(50)') AS page_source,   
 Tbl.Col.value('related_to_hhc_diag[1]', 'INT') AS related_to_hhc_diag,   
 Tbl.Col.value('severity_of_care_problem[1]', 'INT') AS severity_of_care_problem,   
 Tbl.Col.value('episode_id[1]', 'BIGINT') AS episode_id,    
 Tbl.Col.value('pto_id[1]', 'BIGINT') AS pto_id,   
 Tbl.Col.value('oasis_id[1]', 'BIGINT') AS oasis_id,   
 Tbl.Col.value('poc_id[1]', 'BIGINT') AS poc_id,
 Tbl.Col.value('add_option[1]','INT') AS add_option,
 Tbl.Col.value('edit_option[1]','INT') AS edit_option
 FROM @problem_list.nodes('/Problem/problem') Tbl(Col)  
  
 INSERT INTO @CareGoalTempTable  
 SELECT  
 Tbl.Col.value('Action[1]', 'VARCHAR(100)') AS [Action],  
 Tbl.Col.value('goal_id[1]', 'BIGINT') AS goal_id,  
 Tbl.Col.value('caregoal_template_id[1]', 'BIGINT') AS caregoal_template_id,  
 Tbl.Col.value('problem_id[1]', 'BIGINT') AS problem_id,  
 Tbl.Col.value('goal_desc[1]', 'NVARCHAR(MAX)') AS goal_desc,  
 Tbl.Col.value('goal_status[1]', 'VARCHAR(20)') AS goal_status,  
 Tbl.Col.value('goal_source[1]', 'VARCHAR(20)') AS goal_source,  
 Tbl.Col.value('goal_group_id[1]', 'BIGINT') AS goal_group_id,  
 Tbl.Col.value('page_source[1]', 'VARCHAR(20)') AS page_source,  
 Tbl.Col.value('target_date[1]', 'DATE') AS target_date,  
 Tbl.Col.value('goal_setfor[1]', 'INT') AS goal_setfor,  
 Tbl.Col.value('resolution_date[1]', 'DATE') AS resolution_date,  
 Tbl.Col.value('comment[1]', 'NVARCHAR(MAX)') AS comment,  
 Tbl.Col.value('episode_id[1]', 'BIGINT') AS episode_id,    
 Tbl.Col.value('pto_id[1]', 'BIGINT') AS pto_id,   
 Tbl.Col.value('oasis_id[1]', 'BIGINT') AS oasis_id,   
 Tbl.Col.value('poc_id[1]', 'BIGINT') AS poc_id,
 Tbl.Col.value('add_option[1]','INT') AS add_option,
 Tbl.Col.value('edit_option[1]','INT') AS edit_option
 FROM @caregoal_list.nodes('/CareGoal/caregoal') Tbl(Col)  
  
 INSERT INTO @InterventionTempTable  
 SELECT  
 Tbl.Col.value('Action[1]', 'VARCHAR(100)') AS [Action],  
 Tbl.Col.value('intervention_id[1]', 'BIGINT') AS intervention_id,  
 Tbl.Col.value('intervention_template_id[1]', 'BIGINT') AS intervention_template_id,  
 Tbl.Col.value('goal_id[1]', 'BIGINT') AS goal_id,  
 Tbl.Col.value('intervention_desc[1]', 'NVARCHAR(MAX)') AS intervention_desc,  
 Tbl.Col.value('intervention_status[1]', 'VARCHAR(100)') AS intervention_status,  
 Tbl.Col.value('intervention_source[1]', 'VARCHAR(20)') AS intervention_source,  
 Tbl.Col.value('intervention_group_id[1]', 'BIGINT') AS intervention_group_id,  
 Tbl.Col.value('goal_outcome[1]', 'INT') AS goal_outcome,  
 Tbl.Col.value('initiated_by[1]', 'INT') AS initiated_by,  
 Tbl.Col.value('initiated_date[1]', 'DATE') AS initiated_date,  
 Tbl.Col.value('resolved_by[1]', 'INT') AS resolved_by,  
 Tbl.Col.value('resolved_date[1]', 'DATE') AS resolved_date,  
 Tbl.Col.value('page_source[1]', 'VARCHAR(20)') AS page_source,  
 Tbl.Col.value('episode_id[1]', 'BIGINT') AS episode_id,  
 Tbl.Col.value('pto_id[1]', 'BIGINT') AS pto_id,  
 Tbl.Col.value('oasis_id[1]', 'BIGINT') AS oasis_id,  
 Tbl.Col.value('poc_id[1]', 'BIGINT') AS poc_id,
 Tbl.Col.value('add_option[1]', 'INT') AS add_option,
 Tbl.Col.value('edit_option[1]', 'INT') AS edit_option
 FROM @intervention_list.nodes('/Intervention/intervention') Tbl(Col)  
  
 INSERT INTO @InterventionCommentTempTable  
 SELECT  
 Tbl.Col.value('Action[1]', 'VARCHAR(100)') AS [Action],  
 Tbl.Col.value('comment_id[1]', 'BIGINT') AS comment_id,  
 Tbl.Col.value('intervention_id[1]', 'BIGINT') AS intervention_id,  
 Tbl.Col.value('comment[1]', 'NVARCHAR(MAX)') AS comment,  
 Tbl.Col.value('comment_source[1]', 'VARCHAR(20)') AS comment_source,  
 Tbl.Col.value('parent_comment_id[1]', 'BIGINT') AS parent_comment_id,  
 Tbl.Col.value('page_source[1]', 'VARCHAR(20)') AS page_source,  
 Tbl.Col.value('episode_id[1]', 'BIGINT') AS episode_id,  
 Tbl.Col.value('pto_id[1]', 'BIGINT') AS pto_id,  
 Tbl.Col.value('oasis_id[1]', 'BIGINT') AS oasis_id,  
 Tbl.Col.value('poc_id[1]', 'BIGINT') AS poc_id  
 FROM @intervention_comment_list.nodes('/InterventionComment/interventioncomment') Tbl(Col)
 
 INSERT INTO @CareGoalCommentTempTable  
 SELECT  
 Tbl.Col.value('Action[1]', 'VARCHAR(100)') AS [Action],  
 Tbl.Col.value('comment_id[1]', 'BIGINT') AS comment_id,  
 Tbl.Col.value('goal_group_id[1]', 'BIGINT') AS goal_group_id,  
 Tbl.Col.value('comment[1]', 'NVARCHAR(MAX)') AS comment,  
 Tbl.Col.value('comment_source[1]', 'VARCHAR(20)') AS comment_source,  
 Tbl.Col.value('parent_comment_id[1]', 'BIGINT') AS parent_comment_id,  
 Tbl.Col.value('page_source[1]', 'VARCHAR(20)') AS page_source,  
 Tbl.Col.value('episode_id[1]', 'BIGINT') AS episode_id,  
 Tbl.Col.value('pto_id[1]', 'BIGINT') AS pto_id,  
 Tbl.Col.value('oasis_id[1]', 'BIGINT') AS oasis_id,  
 Tbl.Col.value('poc_id[1]', 'BIGINT') AS poc_id  
 FROM @caregoal_comment_list.nodes('/CareGoalComment/caregoalcomment') Tbl(Col)
  
 DECLARE @ToBeUpdatedTCNList TABLE (  
 tcn_id BIGINT,  
 call_date_time DATETIME)  
  
 DECLARE @tcn_call_date_time AS DATETIME  
 SELECT @tcn_call_date_time = (call_date + call_time) FROM [TelCommunicationNote] WHERE tcn_id = @tcn_id AND episode_id = @episode_id AND ISNULL(IsDeleted, 0) = 0  
  
 INSERT INTO @ToBeUpdatedTCNList(tcn_id, call_date_time)  
 SELECT tcn_id, call_time FROM [TelCommunicationNote] WHERE NOT tcn_id = @tcn_id AND episode_id = @episode_id AND (call_date + call_time) > @tcn_call_date_time AND ISNULL(IsDeleted, 0) = 0  


  --Start Mark A. 05/13/2024 Enhancement


--Start creating copy for TCN,PTO to be used by visit note saving care plan as Comm. Note or PTO

DECLARE 
@new_temp_problem_id [bigint] = 0,
@new_temp_goal_id[bigint] = 0,
@new_temp_intervention_id[bigint] = 0

SELECT @new_temp_problem_id = MAX(problem_id) FROM @ProblemTempTable

SELECT @new_temp_goal_id = MAX(goal_id) FROM @CareGoalTempTable

SELECT @new_temp_intervention_id = MAX(intervention_id) FROM @InterventionTempTable


DECLARE @ProblemCopyRefs TABLE(
	from_problem_id [BIGINT],
	to_new_problem_id [BIGINT],
	db_identity [BIGINT]
)

DECLARE @CareGoalCopyRefs TABLE(
	from_goal_id [BIGINT],
	to_new_goal_id [BIGINT],
	db_identity [BIGINT],
	problem_id_db_identity [BIGINT],
	from_probem_id [BIGINT]
)

DECLARE @InterventionCopyRefs TABLE(
	from_intervention_id [BIGINT],
	to_new_intervention_id [BIGINT],
	db_identity [BIGINT],
	goal_id_db_identity [BIGINT],
	from_goal_id [BIGINT]
)

INSERT INTO @ProblemCopyRefs
SELECT
	problem_id,
	@new_temp_problem_id + ROW_NUMBER() OVER(ORDER BY problem_id ASC),
	null
FROM @ProblemTempTable

INSERT INTO @CareGoalCopyRefs
SELECT
	goal_id,
	@new_temp_goal_id + ROW_NUMBER() OVER(ORDER BY goal_id ASC),
	null,
	null,
	problem_id
FROM @CareGoalTempTable

INSERT INTO @InterventionCopyRefs
SELECT 
	intervention_id,
	@new_temp_intervention_id + ROW_NUMBER() OVER(ORDER BY intervention_id ASC),
	null,
	null,
	goal_id
FROM @InterventionTempTable

--End creating copy for TCN,PTO to be used by visit note saving care plan as Comm. Note or PTO

DECLARE @visit_date DATETIME = NULL;

IF COALESCE(@cg_note_id,0) != 0
BEGIN
	SELECT @visit_date = COALESCE(_v.Actual_Visit_Date, _vp.Scheduled_Visit_Date)
	FROM CaregiverNote _cgn
	LEFT JOIN Visits _v ON _v.visit_id = _cgn.visit_id
	LEFT JOIN VisitPlan _vp ON _vp.visit_plan_id = _cgn.visit_plan_id
	WHERE _cgn.cg_note_id = @cg_note_id		
END

 --End Mark A. 05/13/2024 Enhancement




 --Start Mark A. 10/09/2024 Enhancement

 --FOR POC - STORE THE EXISTING DATA OF OTHER CARE PLAN DOCUMENTS TO TEMP TABLE BEFORE DELETING
 DECLARE @ExistingTempProblem TABLE(
	problem_id BIGINT,
	problem_group_id BIGINT,
	problem_source VARCHAR(100),
	problem_template_id BIGINT,
	bodysystem_id BIGINT,
	problem_status VARCHAR(100)
 )

 DECLARE @ExistingTempGoal TABLE(
	problem_id BIGINT,
	goal_id BIGINT,
	goal_group_id BIGINT,
	goal_source VARCHAR(100),
	caregoal_template_id BIGINT,
	resolution_date DATE
 )

 DECLARE @ExistingInterventionTempTable TABLE(
	goal_id BIGINT,
	intervention_group_id BIGINT,
	intervention_source VARCHAR(100),
	intervention_template_id BIGINT,
	goal_outcome INT
 )

 INSERT INTO @ExistingTempProblem (problem_id, problem_group_id, problem_source, problem_template_id, bodysystem_id, problem_status) SELECT problem_id, problem_group_id, problem_source, problem_template_id, bodysystem_id, problem_status FROM CarePlan_Problem WHERE COALESCE(is_deleted, 0) = 0 AND episode_id = @episode_id
 INSERT INTO @ExistingTempGoal (problem_id, goal_id, goal_group_id, goal_source, caregoal_template_id, resolution_date) SELECT problem_id, goal_id, goal_group_id, goal_source, caregoal_template_id, resolution_date FROM CarePlan_Goal WHERE COALESCE(is_deleted,0) = 0 AND episode_id = @episode_id
 INSERT INTO @ExistingInterventionTempTable (goal_id, intervention_group_id, intervention_source, intervention_template_id, goal_outcome) SELECT goal_id, intervention_group_id, intervention_source, intervention_template_id, goal_outcome FROM CarePlan_Intervention WHERE COALESCE(is_deleted,0) = 0 AND episode_id = @episode_id


 --CARE PLAN DOCUMENTS  MARK A. 10/09/2024

DECLARE @CarePlanDocumentsForUpdates TABLE(
	doc_date DATETIME,
	doc_type VARCHAR(100),
	[key] BIGINT
)


INSERT INTO @CarePlanDocumentsForUpdates

SELECT
	doc_dates.doc_date AS doc_date, 
	doc_dates.doc_type AS doc_type,
	doc_dates.doc_key AS doc_key
FROM (
	--Get POC Documents
	SELECT CASE WHEN o.m0100_assmt_reason = '01' THEN CAST(o.m0030_start_care_dt AS DATE) WHEN o.m0100_assmt_reason = '03' THEN CAST(o.m0032_roc_dt AS DATE) ELSE CAST(pto.call_date AS DATE) END AS doc_date, 'POC' doc_type, poc.POCID doc_key FROM POC poc JOIN OASIS o ON o.OasisID = poc.OASISID JOIN PTO pto ON pto.pto_id = poc.pto_id   WHERE o.episode_id = @episode_id AND COALESCE(poc.isdeleted,0) = 0 AND o.m0100_assmt_reason IN('01','03','04')
	UNION 
	--Get OASIS Documents
	SELECT CASE WHEN o.m0100_assmt_reason = '01' THEN CAST(o.m0030_start_care_dt AS DATE) WHEN o.m0100_assmt_reason = '03' THEN CAST(o.m0032_roc_dt AS DATE) ELSE CAST(pto.call_date AS DATE) END AS doc_date, 'OASIS' doc_type, o.OasisID doc_key FROM Oasis o JOIN PTO pto ON pto.pto_id = o.pto_id   WHERE o.episode_id = @episode_id AND COALESCE(o.isdeleted,0) = 0 AND o.m0100_assmt_reason IN('01','03','04') 
	UNION
	--The document date for PTO, TCN, VisitPlan-TCN was based on their dates accordingly - Mark A.
	SELECT call_date +  CAST(call_time AS TIME) AS doc_date, 'PTO' AS doc_type, pto_id AS doc_key FROM PTO WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND order_type IN ('AdmissionOrder','ResumptionOfCare', 'Recertification', 'CarePlanOrder', 'OtherFollowUp')
	UNION
	SELECT call_date +  CAST(call_time AS TIME) AS doc_date, 'TCN' AS doc_type, tcn_id AS doc_key FROM TelCommunicationNote WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND tcn_id IN (SELECT cp.tcn_id FROM CarePlan_Problem cp WHERE episode_id = @episode_id AND COALESCE(cp.is_deleted,0) = 0 AND cp.page_source IN ('TCN'))
	UNION
	SELECT COALESCE(v.Actual_Visit_Date, vp.Scheduled_Visit_Date) as doc_date, 'VisitPlan-TCN' AS doc_type, cgn.cg_note_id AS doc_key FROM CaregiverNote cgn LEFT JOIN Visits v ON v.Visit_Id = cgn.visit_id LEFT JOIN VisitPlan vp ON vp.visit_plan_id = cgn.visit_plan_id  WHERE COALESCE(cgn.is_deleted,0) = 0 AND cgn.cg_note_id IN (SELECT cp.cg_note_id FROM CarePlan_Problem cp WHERE episode_id = @episode_id AND COALESCE(cp.is_deleted,0) = 0 AND cp.page_source = 'VisitPlan-TCN')
		
) doc_dates



-- Delete all data if updating via POC
DECLARE @poc_date DATETIME;

IF @page_source = 'POC'
BEGIN

	SELECT @poc_date = CASE WHEN o.m0100_assmt_reason = '01' THEN CAST(o.m0030_start_care_dt AS DATE) WHEN o.m0100_assmt_reason = '03' THEN CAST(o.m0032_roc_dt AS DATE) ELSE CAST(pto.call_date AS DATE) END FROM POC p JOIN OASIS o ON o.OasisID = p.OASISID JOIN PTO pto ON pto.pto_id = p.pto_id WHERE p.POCID = @poc_id AND COALESCE(p.isdeleted,0) = 0

	DECLARE @d_doc_date DATETIME, @d_doc_type VARCHAR(100), @d_doc_key BIGINT
	DECLARE D_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates
	OPEN D_Document_Cursor
	FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @d_doc_date >= @poc_date AND ((@d_doc_type = 'POC' AND @d_doc_key != @poc_id) or (@d_doc_type != 'POC'))
		BEGIN
			UPDATE CarePlan_Problem SET is_deleted = 1, updated_date = GETDATE(), updated_by = 'pocupdate' WHERE  episode_id = @episode_id AND  COALESCE(is_deleted,0) = 0 AND ((page_source = 'POC' AND @d_doc_type = 'POC' AND poc_id = @d_doc_key) or  (page_source = 'OASIS' AND @d_doc_type = 'OASIS' AND oasis_id = @d_doc_key) or  (page_source = 'PTO' AND @d_doc_type = 'PTO' AND pto_id = @d_doc_key) OR  (page_source = 'TCN' AND @d_doc_type = 'TCN' AND tcn_id = @d_doc_key)  or  (page_source = 'VisitPlan-TCN' AND @d_doc_type = 'VisitPlan-TCN' AND cg_note_id = @d_doc_key) )
			UPDATE CarePlan_Goal SET is_deleted = 1, updated_date = GETDATE(), updated_by = 'pocupdate' WHERE  episode_id = @episode_id AND  COALESCE(is_deleted,0) = 0 AND  ((page_source = 'POC' AND @d_doc_type = 'POC' AND poc_id = @d_doc_key) or  (page_source = 'OASIS' AND @d_doc_type = 'OASIS' AND oasis_id = @d_doc_key) or  (page_source = 'PTO' AND @d_doc_type = 'PTO' AND pto_id = @d_doc_key) OR  (page_source = 'TCN' AND @d_doc_type = 'TCN' AND tcn_id = @d_doc_key)  or  (page_source = 'VisitPlan-TCN' AND @d_doc_type = 'VisitPlan-TCN' AND cg_note_id = @d_doc_key) )
			UPDATE CarePlan_Intervention SET is_deleted = 1, updated_date = GETDATE(), updated_by = 'pocupdate' WHERE  episode_id = @episode_id AND  COALESCE(is_deleted,0) = 0 AND  ((page_source = 'POC' AND @d_doc_type = 'POC' AND poc_id = @d_doc_key) or  (page_source = 'OASIS' AND @d_doc_type = 'OASIS' AND oasis_id = @d_doc_key) or  (page_source = 'PTO' AND @d_doc_type = 'PTO' AND pto_id = @d_doc_key) OR  (page_source = 'TCN' AND @d_doc_type = 'TCN' AND tcn_id = @d_doc_key)  or  (page_source = 'VisitPlan-TCN' AND @d_doc_type = 'VisitPlan-TCN' AND cg_note_id = @d_doc_key) )
		END
		FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	END
	CLOSE D_Document_Cursor
	DEALLOCATE D_Document_Cursor

END


 --End Mark A. 10/09/2024 Enhancement


  
 --Problem Process Start----------------------------------  
 DECLARE ProblemCursor CURSOR FOR  
 SELECT   
  [Action]  
 ,problem_id  
 ,problem_template_id  
 ,bodysystem_id   
 ,problem_desc  
 ,problem_status   
 ,problem_source  
 ,problem_group_id   
 ,page_source   
 ,related_to_hhc_diag   
 ,severity_of_care_problem   
 ,episode_id   
 ,pto_id   
 ,oasis_id   
 ,poc_id
 ,add_option
 ,edit_option
 FROM @ProblemTempTable  
  
 OPEN ProblemCursor  
  
 FETCH NEXT FROM ProblemCursor  
 INTO    
  @pbm_Action  
 ,@pbm_problem_id  
 ,@pbm_problem_template_id  
 ,@pbm_bodysystem_id   
 ,@pbm_problem_desc  
 ,@pbm_problem_status   
 ,@pbm_problem_source  
 ,@pbm_problem_group_id   
 ,@page_source   
 ,@pbm_related_to_hhc_diag   
 ,@pbm_severity_of_care_problem   
 ,@pbm_episode_id   
 ,@pbm_pto_id   
 ,@pbm_oasis_id   
 ,@pbm_poc_id
 ,@pbm_add_option
 ,@pbm_edit_option
  
 DECLARE @PTOType VARCHAR(100),  
 @current_pto_call_date DATETIME  
 --,@referred_pto_id BIGINT  
  
 SELECT @PTOType = order_type, @current_pto_call_date = call_date FROM PTO WHERE pto_id = @pto_id  
 --SELECT @referred_pto_id = pto_id FROM PTO WHERE episode_id = 7781 AND ISNULL(isDeleted, 0) = 0 AND order_type = 'InitialIntake'  
  
 WHILE @@FETCH_STATUS = 0    
 BEGIN   
  
 IF @pbm_Action = 'Add' OR @pbm_Action = 'AddFromLateAdmissionOrder' OR @pbm_Action = 'AddFromProfile' OR @pbm_Action = 'AddFromProfileTCN' or @pbm_Action = 'AddFromVisitNote'  
 BEGIN  
  
  DECLARE @new_problem_id BIGINT;  
  SET @page_source = CASE WHEN @pbm_Action = 'AddFromLateAdmissionOrder' OR @pbm_Action = 'AddFromProfile' THEN 'PTO' WHEN @pbm_Action = 'AddFromProfileTCN' THEN 'TCN' ELSE @page_source END
  
  DECLARE @pbm_existing_problem_group_id BIGINT, @pbm_existing_problem_source VARCHAR(100), @pbm_addtoall_source_id BIGINT
  SET @pbm_existing_problem_group_id = NULL
  SET @pbm_existing_problem_source = NULL
  SET @pbm_addtoall_source_id = NULL
  
  
  SELECT TOP 1 @pbm_existing_problem_group_id = problem_group_id, @pbm_existing_problem_source = problem_source FROM @ExistingTempProblem WHERE problem_template_id = @pbm_problem_template_id AND bodysystem_id = @pbm_bodysystem_id AND problem_group_id NOT IN (SELECT _cp.problem_group_id FROM @ExistingTempProblem _cp WHERE _cp.problem_group_id = problem_group_id AND ISNULL(problem_status,'') = 'resolved')
    
  INSERT INTO CarePlan_Problem  
  (problem_template_id  
  ,bodysystem_id  
  ,problem_desc  
  ,problem_status  
  ,problem_source  
  ,problem_group_id  
  ,page_source  
  ,related_to_hhc_diag  
  ,severity_of_care_problem  
  ,m0020_pat_id  
  ,patient_intake_id  
  ,episode_id  
  ,pto_id  
  ,oasis_id  
  ,poc_id  
  ,tcn_id  
  ,created_date  
  ,created_by  
  ,updated_date  
  ,updated_by  
  ,agency_id
  ,cg_note_id)  
  VALUES(  
   @pbm_problem_template_id  
  ,@pbm_bodysystem_id  
  ,@pbm_problem_desc  
  ,@pbm_problem_status  
  ,CASE WHEN COALESCE(@pbm_existing_problem_source, '') <> '' AND @page_source <> 'POC' THEN @pbm_existing_problem_source ELSE  @pbm_problem_source END --@pbm_problem_source   
  ,CASE WHEN COALESCE(@pbm_existing_problem_group_id,0) <> 0 AND @page_source <> 'POC' THEN @pbm_existing_problem_group_id ELSE  @pbm_problem_group_id END  
  ,CASE WHEN @page_source = 'VisitPlan-PTO' THEN 'VisitPlan-TCN' ELSE @page_source END 
  ,@pbm_related_to_hhc_diag  
  ,@pbm_severity_of_care_problem  
  ,@patient_id  
  ,@intake_id  
  ,@episode_id  
  ,CASE WHEN @page_source = 'VisitPlan-PTO' THEN -1 ELSE @pto_id END  
  ,@oasis_id  
  ,@poc_id  
  ,CASE WHEN @page_source = 'VisitPlan-TCN' THEN -1 ELSE @tcn_id END 
  ,CASE WHEN @pbm_Action = 'AddFromLateAdmissionOrder' THEN @current_pto_call_date ELSE GETDATE() END  
  ,@user_id  
  ,GETDATE()  
  ,@user_id  
  ,@agencyId
  ,@cg_note_id
  )  
  
  SET @new_problem_id = SCOPE_IDENTITY();
  SET @pbm_addtoall_source_id = @new_problem_id;
  
  UPDATE @CareGoalTempTable SET problem_id = @new_problem_id WHERE problem_id = @pbm_problem_id AND ([Action] = 'Add' OR @pbm_Action = 'AddFromProfile' OR @pbm_Action = 'AddFromProfileTCN' OR @pbm_Action = 'AddFromVisitNote')  

  --BEGIN Mark A. 05/13/2024 Enhancement
  IF(@page_source = 'POC' AND @pbm_Action = 'Add')
  BEGIN

  	DECLARE D_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates
	OPEN D_Document_Cursor
	FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @d_doc_date >= @poc_date AND ((@d_doc_type = 'POC' AND @d_doc_key != @poc_id) or (@d_doc_type != 'POC'))
		BEGIN

		 
		  INSERT INTO CarePlan_Problem  
		  (
		  problem_template_id,
		  bodysystem_id,
		  problem_desc,
		  problem_status,
		  problem_source,
		  problem_group_id,
		  page_source,
		  related_to_hhc_diag,
		  severity_of_care_problem,
		  m0020_pat_id,
		  patient_intake_id,
		  episode_id,
		  pto_id,
		  oasis_id,
		  poc_id,
		  tcn_id,
		  created_date,
		  created_by,
		  updated_date,
		  updated_by,
		  agency_id,
		  cg_note_id) 

		  SELECT
			@pbm_problem_template_id,
			@pbm_bodysystem_id,
			@pbm_problem_desc,
			@pbm_problem_status,
			@page_source,
			@new_problem_id,
			@d_doc_type,
			@pbm_related_to_hhc_diag,
			@pbm_severity_of_care_problem,
			@patient_id,
			@intake_id,
			@episode_id,
			CASE WHEN @d_doc_type = 'PTO' THEN @d_doc_key ELSE -1 END,
			CASE WHEN @d_doc_type = 'OASIS' THEN @d_doc_key ELSE -1 END,
			CASE WHEN @d_doc_type = 'POC' THEN @d_doc_key ELSE -1 END,
			CASE WHEN @d_doc_type = 'TCN' THEN @d_doc_key ELSE -1 END,
			GETDATE(),
			'pocupdate',
			GETDATE(),
			'pocupdate',
			@agencyId,
			CASE WHEN @d_doc_type = 'VisitPlan-TCN' THEN @d_doc_key ELSE -1 END

		END

		FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	END
	CLOSE D_Document_Cursor
	DEALLOCATE D_Document_Cursor


 END



  --END Mark A. 05/13/2024
  
  IF(NOT @pbm_Action = 'AddFromLateAdmissionOrder')  
   BEGIN  
  
    IF(@pbm_Action = 'ADD' OR (@pbm_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') NOT IN ('CarePlanOrder','ResumptionOfCare')) )  
    BEGIN  
    UPDATE CarePlan_Problem SET problem_group_id = CASE WHEN COALESCE(@pbm_existing_problem_group_id,0) <> 0 AND page_source <> 'POC' THEN @pbm_existing_problem_group_id ELSE @new_problem_id END WHERE problem_id = @new_problem_id  
    END
	
	IF(@page_source = 'PTO' AND @pbm_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') = 'Recertification')
	BEGIN
		UPDATE CarePlan_Problem SET problem_source = 'PTO' WHERE problem_id = @new_problem_id
	END
  
    IF(NOT COALESCE(@PTOType, '') = 'CarePlanOrder' AND NOT COALESCE(@pbm_Action,'') = 'AddFromVisitNote')  
    BEGIN  
  
    IF(@page_source = 'TCN')  
    BEGIN  
     UPDATE CarePlan_Problem SET  
     problem_status = @pbm_problem_status  
     ,updated_date = DATEADD(ss,1,GETDATE())  
     ,updated_by = @user_id  
     WHERE problem_group_id = @pbm_problem_group_id AND page_source = 'TCN'  
     AND tcn_id IN(SELECT tcn_id FROM @ToBeUpdatedTCNList)  
    END  
     
     IF(@page_source = 'PTO')  
     BEGIN  
     --OASIS  
      INSERT INTO CarePlan_Problem  
     (problem_template_id  
     ,bodysystem_id  
     ,problem_desc  
     ,problem_status  
     ,problem_source  
     ,problem_group_id  
     ,page_source  
     ,related_to_hhc_diag  
     ,severity_of_care_problem  
     ,m0020_pat_id  
     ,patient_intake_id  
     ,episode_id  
     ,pto_id  
     ,oasis_id  
     ,poc_id  
     ,created_date  
     ,created_by  
     ,updated_date  
     ,updated_by  
     ,agency_id)  
     VALUES(  
      @pbm_problem_template_id  
     ,@pbm_bodysystem_id  
     ,@pbm_problem_desc  
     ,@pbm_problem_status  
     ,CASE WHEN @pbm_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') = 'ResumptionOfCare' THEN @pbm_problem_source ELSE (CASE WHEN COALESCE(@pbm_existing_problem_source, '') <> '' THEN @pbm_existing_problem_source ELSE  @page_source END) END
     ,CASE WHEN COALESCE(@pbm_existing_problem_group_id,0) <> 0 THEN @pbm_existing_problem_group_id ELSE @new_problem_id END  
     ,'OASIS'  
     ,@pbm_related_to_hhc_diag  
     ,@pbm_severity_of_care_problem  
     ,@patient_id  
     ,@intake_id  
     ,@episode_id  
     ,@pto_id  
     ,@oasis_id  
     ,@poc_id  
     ,GETDATE()  
     ,@user_id  
     ,GETDATE()  
     ,@user_id  
     ,@agencyId
	 )  
     END  
  
     IF(@page_source <> 'POC' AND @page_source <> 'TCN' AND @poc_id <> -1)  
     BEGIN  
      --POC  
      INSERT INTO CarePlan_Problem  
     (problem_template_id  
     ,bodysystem_id  
     ,problem_desc  
     ,problem_status  
     ,problem_source  
     ,problem_group_id  
     ,page_source  
     ,related_to_hhc_diag  
     ,severity_of_care_problem  
     ,m0020_pat_id  
     ,patient_intake_id  
     ,episode_id  
     ,pto_id  
     ,oasis_id  
     ,poc_id  
     ,created_date  
     ,created_by  
     ,updated_date  
     ,updated_by  
     ,agency_id)  
     VALUES(  
      @pbm_problem_template_id  
     ,@pbm_bodysystem_id  
     ,@pbm_problem_desc  
     ,@pbm_problem_status  
     ,CASE WHEN @page_source = 'PTO' AND @pbm_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') = 'ResumptionOfCare' THEN @pbm_problem_source ELSE (CASE WHEN COALESCE(@pbm_existing_problem_source, '') <> '' THEN @pbm_existing_problem_source ELSE  @page_source END) END 
     ,CASE WHEN COALESCE(@pbm_existing_problem_group_id,0) <> 0 THEN @pbm_existing_problem_group_id ELSE @new_problem_id END  
     ,'POC'  
     ,@pbm_related_to_hhc_diag  
     ,@pbm_severity_of_care_problem  
     ,@patient_id  
     ,@intake_id  
     ,@episode_id  
     ,@pto_id  
     ,@oasis_id  
     ,@poc_id  
     ,GETDATE()  
     ,@user_id  
     ,GETDATE()  
     ,@user_id  
     ,@agencyId)  
    END  
   END  
  END  
  ELSE  
  BEGIN  
   UPDATE @CareGoalTempTable SET problem_id = @new_problem_id WHERE problem_id = @pbm_problem_group_id AND [Action] = 'AddFromLateAdmissionOrder'  
  
   UPDATE CarePlan_Problem SET  
   problem_status = @pbm_problem_status  
   ,related_to_hhc_diag = @pbm_related_to_hhc_diag  
   ,severity_of_care_problem = @pbm_severity_of_care_problem  
   --,problem_source = 'PTO'  
   ,created_date = @current_pto_call_date  
   ,updated_date = GETDATE()  
   ,updated_by = @user_id  
   --,pto_id = @pto_id  
   WHERE problem_group_id = @pbm_problem_group_id AND problem_source = 'OASIS'  
  END

  --Start Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024

	IF @page_source IN ('VisitPlan-TCN','VisitPlan-PTO') AND (COALESCE(@tcn_id,0) NOT IN (-1,0) OR COALESCE(@pto_id,0) NOT IN (-1,0))
	BEGIN
		INSERT INTO CarePlan_Problem (
			problem_template_id,
			bodysystem_id,  
			problem_desc,  
			problem_status,  
			problem_source,  
			problem_group_id,  
			page_source,  
			related_to_hhc_diag,  
			severity_of_care_problem,  
			m0020_pat_id,  
			patient_intake_id,  
			episode_id,  
			pto_id,  
			oasis_id,  
			poc_id,  
			tcn_id,  
			created_date,  
			created_by,  
			updated_date,  
			updated_by,  
			agency_id,
			cg_note_id
		)
		
		SELECT
			@pbm_problem_template_id,  
			@pbm_bodysystem_id,  
			@pbm_problem_desc,  
			@pbm_problem_status,  
			CASE WHEN COALESCE(@pbm_existing_problem_source, '') <> '' THEN @pbm_existing_problem_source ELSE  @pbm_problem_source END,   
			CASE WHEN COALESCE(@pbm_existing_problem_group_id,0) <> 0 THEN @pbm_existing_problem_group_id ELSE @new_problem_id END,  
			CASE WHEN @page_source = 'VisitPlan-TCN' THEN 'TCN' ELSE 'PTO' END,  
			@pbm_related_to_hhc_diag,  
			@pbm_severity_of_care_problem,  
			@patient_id,  
			@intake_id,  
			@episode_id,  
			@pto_id,  
			@oasis_id,  
			@poc_id,  
			@tcn_id, 
			CASE WHEN @pbm_Action = 'AddFromLateAdmissionOrder' THEN @current_pto_call_date ELSE GETDATE() END,  
			@user_id,  
			GETDATE(),  
			@user_id,  
			@agencyId,
			-1
		FROM @ProblemCopyRefs pcr

		WHERE pcr.from_problem_id = @pbm_problem_id
  
		SET @new_problem_id = SCOPE_IDENTITY();

		UPDATE @ProblemCopyRefs SET db_identity = @new_problem_id WHERE from_problem_id = @pbm_problem_id

		UPDATE cgcr SET cgcr.problem_id_db_identity = @new_problem_id FROM @CareGoalCopyRefs cgcr WHERE cgcr.from_probem_id = @pbm_problem_id

	END

  --End Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024



	--Start Mark A. 10/09/2024 Check if the add option is 'Add to all referencing documents', 'Add and replace in all referencing document' or 'Add to this document only'

	IF @pbm_Action = 'Add' AND @page_source <> 'POC' AND ISNULL(@pbm_problem_status,'') <> 'resolved'
	BEGIN


		DECLARE @current_document_date DATETIME, @current_document_key BIGINT, @existing_problem_group_id BIGINT, @existing_problem_id BIGINT

		IF @page_source = 'PTO'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM PTO WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND pto_id = @pto_id
			SELECT @current_document_key = @pto_id
		END

		IF @page_source = 'OASIS'
		BEGIN
			SELECT  @current_document_date = CASE WHEN o.m0100_assmt_reason = '01' THEN CAST(o.m0030_start_care_dt AS DATE) WHEN o.m0100_assmt_reason = '03' THEN CAST(o.m0032_roc_dt AS DATE) ELSE CAST(pto.call_date AS DATE) END FROM Oasis o JOIN PTO pto ON pto.pto_id = o.pto_id   WHERE o.episode_id = @episode_id AND COALESCE(o.isdeleted,0) = 0 AND o.m0100_assmt_reason IN('01','03','04') AND o.OasisID = @oasis_id
			SELECT @current_document_key = @oasis_id
		END

		IF @page_source = 'TCN'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM TelCommunicationNote WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND tcn_id = @tcn_id
			SELECT @current_document_key = @tcn_id
		END

		IF @page_source IN ('VisitPlan-TCN','VisitPlan-PTO')
		BEGIN
			SELECT @current_document_date = COALESCE(v.Actual_Visit_Date, vp.Scheduled_Visit_Date) FROM CaregiverNote cgn LEFT JOIN Visits v ON v.Visit_Id = cgn.visit_id LEFT JOIN VisitPlan vp ON vp.visit_plan_id = cgn.visit_plan_id  WHERE COALESCE(cgn.is_deleted,0) = 0 AND cgn.cg_note_id = @cg_note_id
			SELECT @current_document_key = @cg_note_id
		END


		DECLARE @u_doc_date DATETIME, @u_doc_type VARCHAR(100), @u_key BIGINT
		DECLARE U_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates 
		WHERE
		(
		(@page_source = doc_type AND @current_document_key != [key])
		OR
		(@page_source != doc_type AND @current_document_key = [key])
		OR
		(@page_source != doc_type AND @current_document_key != [key])
		)

		AND doc_date >= @current_document_date

		OPEN U_Document_Cursor
		FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key
		WHILE @@FETCH_STATUS = 0
		BEGIN

			SELECT @existing_problem_group_id = NULL, @existing_problem_id = NULL
			SELECT TOP 1 @existing_problem_group_id = problem_group_id, @existing_problem_id = problem_id FROM dbo.Func_GetAllCarePlanProblemByEpisodeId(@episode_id, CASE WHEN @u_doc_type = 'PTO' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'OASIS' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'POC' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'TCN' THEN @u_key ELSE 0 END, @u_doc_type, CASE WHEN @u_doc_type = 'VisitPlan-TCN' THEN @u_key ELSE -1 END)  WHERE problem_template_id = @pbm_problem_template_id AND bodysystem_id = @pbm_bodysystem_id AND ISNULL(problem_status,'') <> 'resolved'

			IF( @pbm_add_option = 1 AND COALESCE(@existing_problem_group_id,0) = 0) OR ( @pbm_add_option = 2 AND COALESCE(@existing_problem_group_id,0) = 0)
			BEGIN
				INSERT INTO CarePlan_Problem(problem_template_id, bodysystem_id, problem_desc, problem_status, problem_source, problem_group_id, page_source, related_to_hhc_diag, severity_of_care_problem, m0020_pat_id, patient_intake_id, episode_id, pto_id, oasis_id, poc_id, created_date, created_by, updated_date, updated_by, agency_id, is_deleted, tcn_id, isDisabled, cg_note_id)
				SELECT TOP 1 @pbm_problem_template_id, @pbm_bodysystem_id, @pbm_problem_desc, @pbm_problem_status, problem_source, problem_group_id, @u_doc_type, @pbm_related_to_hhc_diag, @pbm_severity_of_care_problem, m0020_pat_id, patient_intake_id, episode_id, CASE WHEN @u_doc_type = 'PTO' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'OASIS' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'POC' THEN @u_key ELSE -1 END, GETDATE(), 'addtoall', GETDATE(), 'addtoall', agency_id, NULL, CASE WHEN @u_doc_type = 'TCN' THEN @u_key ELSE -1 END, isDisabled, CASE WHEN @u_doc_type = 'VisitPlan-TCN' THEN @u_key ELSE -1 END FROM CarePlan_Problem WHERE problem_id = @pbm_addtoall_source_id
			END

			IF @pbm_add_option = 2 AND COALESCE(@existing_problem_group_id,0) <> 0 AND @pbm_existing_problem_group_id = @existing_problem_group_id
			BEGIN
				UPDATE CarePlan_Problem SET problem_status = @pbm_problem_status, related_to_hhc_diag = @pbm_related_to_hhc_diag, severity_of_care_problem = @pbm_severity_of_care_problem, updated_date = GETDATE(), updated_by = 'updatetoall' WHERE problem_id = @existing_problem_id
			END


			FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key
		END
		CLOSE U_Document_Cursor
		DEALLOCATE U_Document_Cursor


		--Update source and group id if 'Add and Replace'
		IF (@pbm_add_option = 2 AND COALESCE(@pbm_existing_problem_group_id,0) <> 0)
		BEGIN
			UPDATE CarePlan_Problem SET problem_source = @pbm_problem_source, problem_group_id = @new_problem_id WHERE problem_group_id = @pbm_existing_problem_group_id
		END



	END


	

	--End Mark A. 10/09/2024 Check if the add option is 'Add to all referencing documents', 'Add and replace in all referencing document' or 'Add to this document only'








 END  
  
 IF @pbm_Action = 'Edit'  
 BEGIN
       
  UPDATE CarePlan_Problem SET  
  problem_status = @pbm_problem_status  
  ,related_to_hhc_diag = @pbm_related_to_hhc_diag  
  ,severity_of_care_problem = @pbm_severity_of_care_problem  
  ,updated_date = GETDATE()  
  ,updated_by = @user_id
  WHERE problem_id = @pbm_problem_id
  


  --BEGIN Mark A. 05/13/2024 Enhancement
  IF(@page_source = 'POC')
  BEGIN

	--Code for overriding care plan to succeeding documents of POC Mark A. 10/15/2024

	DECLARE D_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates
	OPEN D_Document_Cursor
	FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @d_doc_date >= @poc_date AND ((@d_doc_type = 'POC' AND @d_doc_key != @poc_id) or (@d_doc_type != 'POC'))
		BEGIN

		 
		  INSERT INTO CarePlan_Problem  
		  (
		  problem_template_id,
		  bodysystem_id,
		  problem_desc,
		  problem_status,
		  problem_source,
		  problem_group_id,
		  page_source,
		  related_to_hhc_diag,
		  severity_of_care_problem,
		  m0020_pat_id,
		  patient_intake_id,
		  episode_id,
		  pto_id,
		  oasis_id,
		  poc_id,
		  tcn_id,
		  created_date,
		  created_by,
		  updated_date,
		  updated_by,
		  agency_id,
		  cg_note_id
		  ) 

		  SELECT
			  @pbm_problem_template_id,
			  @pbm_bodysystem_id,
			  @pbm_problem_desc,
			  @pbm_problem_status,
			  @pbm_problem_source,
			  @pbm_problem_group_id,
			  @d_doc_type,
			  @pbm_related_to_hhc_diag,
			  @pbm_severity_of_care_problem,
			  @patient_id,
			  @intake_id,
			  @episode_id,
			  CASE WHEN @d_doc_type = 'PTO' THEN @d_doc_key ELSE -1 END,
			  CASE WHEN @d_doc_type = 'OASIS' THEN @d_doc_key ELSE -1 END,
			  CASE WHEN @d_doc_type = 'POC' THEN @d_doc_key ELSE -1 END,
			  CASE WHEN @d_doc_type = 'TCN' THEN @d_doc_key ELSE -1 END,
			  GETDATE(),
			  'pocupdate',
			  GETDATE(),
			  'pocupdate',
			  @agencyId,
			  CASE WHEN @d_doc_type = 'VisitPlan-TCN' THEN @d_doc_key ELSE -1 END

		END

		FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	END
	CLOSE D_Document_Cursor
	DEALLOCATE D_Document_Cursor

 END


   --Start Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024

	IF @page_source IN ('VisitPlan-TCN','VisitPlan-PTO') AND (COALESCE(@tcn_id,0) NOT IN (-1,0) OR COALESCE(@pto_id,0) NOT IN (-1,0))
	BEGIN
		INSERT INTO CarePlan_Problem (
			problem_template_id,
			bodysystem_id,  
			problem_desc,  
			problem_status,  
			problem_source,  
			problem_group_id,  
			page_source,  
			related_to_hhc_diag,  
			severity_of_care_problem,  
			m0020_pat_id,  
			patient_intake_id,  
			episode_id,  
			pto_id,  
			oasis_id,  
			poc_id,  
			tcn_id,  
			created_date,  
			created_by,  
			updated_date,  
			updated_by,  
			agency_id,
			cg_note_id
		)
		
		SELECT
			@pbm_problem_template_id,  
			@pbm_bodysystem_id,  
			@pbm_problem_desc,  
			@pbm_problem_status,  
			@pbm_problem_source,   
			@pbm_problem_group_id,  
			CASE WHEN @page_source = 'VisitPlan-TCN' THEN 'TCN' ELSE 'PTO' END,  
			@pbm_related_to_hhc_diag,  
			@pbm_severity_of_care_problem,  
			@patient_id,  
			@intake_id,  
			@episode_id,  
			@pto_id,  
			@oasis_id,  
			@poc_id,  
			@tcn_id, 
			CASE WHEN @pbm_Action = 'AddFromLateAdmissionOrder' THEN @current_pto_call_date ELSE GETDATE() END,  
			@user_id,  
			GETDATE(),  
			@user_id,  
			@agencyId,
			-1
		FROM @ProblemCopyRefs pcr

		WHERE pcr.from_problem_id = @pbm_problem_id
  
		SET @new_problem_id = SCOPE_IDENTITY();

		UPDATE @ProblemCopyRefs SET db_identity = @new_problem_id WHERE from_problem_id = @pbm_problem_id

		UPDATE cgcr SET cgcr.problem_id_db_identity = @new_problem_id FROM @CareGoalCopyRefs cgcr WHERE cgcr.from_probem_id = @pbm_problem_id


	END

  --End Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024



  --END Mark A. 05/13/2024

  
    
  IF(NOT COALESCE(@PTOType, '') = 'CarePlanOrder')  
  BEGIN  
  
   IF(@page_source = 'TCN')  
   BEGIN  
    UPDATE CarePlan_Problem SET  
    problem_status = @pbm_problem_status  
    ,updated_date = DATEADD(ss,1,GETDATE())  
    ,updated_by = @user_id
    WHERE problem_group_id = @pbm_problem_group_id AND page_source = 'TCN'  
    AND tcn_id IN(SELECT tcn_id FROM @ToBeUpdatedTCNList)  
   END  
  
   IF(@page_source = 'PTO')  
    BEGIN  
  
    --OASIS  
    UPDATE CarePlan_Problem SET  
    problem_status = @pbm_problem_status  
    ,related_to_hhc_diag = @pbm_related_to_hhc_diag  
    ,severity_of_care_problem = @pbm_severity_of_care_problem  
    ,updated_date = GETDATE()  
    ,updated_by = @user_id
    WHERE problem_group_id = @pbm_problem_group_id AND page_source = 'OASIS' AND oasis_id = @oasis_id
     
    END  
  
    IF(@page_source <> 'POC' AND @page_source <> 'TCN' AND @page_source <> 'VisitPlan-TCN' AND @page_source <> 'VisitPlan-PTO')  
    BEGIN  
     --POC  
     UPDATE CarePlan_Problem SET  
    problem_status = @pbm_problem_status  
    ,related_to_hhc_diag = @pbm_related_to_hhc_diag  
    ,severity_of_care_problem = @pbm_severity_of_care_problem  
    ,updated_date = GETDATE()  
    ,updated_by = @user_id
    WHERE problem_group_id = @pbm_problem_group_id AND page_source = 'POC' AND poc_id = @poc_id  
   END  
  END


	
	IF (@pbm_edit_option = 1 OR ISNULL(@pbm_problem_status,'') = 'resolved') AND ISNULL(@page_source,'') <> 'POC'
	BEGIN
	
		SELECT @current_document_date = NULL, @current_document_key = NULL, @existing_problem_group_id = NULL, @existing_problem_id = NULL
		
		IF @page_source = 'PTO'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM PTO WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND pto_id = @pto_id
			SELECT @current_document_key = @pto_id
		END
		
		
		
		
		IF @page_source = 'OASIS'
		BEGIN
			SELECT  @current_document_date = CASE WHEN o.m0100_assmt_reason = '01' THEN CAST(o.m0030_start_care_dt AS DATE) WHEN o.m0100_assmt_reason = '03' THEN CAST(o.m0032_roc_dt AS DATE) ELSE CAST(pto.call_date AS DATE) END FROM Oasis o JOIN PTO pto ON pto.pto_id = o.pto_id   WHERE o.episode_id = @episode_id AND COALESCE(o.isdeleted,0) = 0 AND o.m0100_assmt_reason IN('01','03','04') AND o.OasisID = @oasis_id
			SELECT @current_document_key = @oasis_id
		END
		
		
		
		
		IF @page_source = 'TCN'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM TelCommunicationNote WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND tcn_id = @tcn_id
			SELECT @current_document_key = @tcn_id
		END
		
		
		IF @page_source IN ('VisitPlan-TCN','VisitPlan-PTO')
		BEGIN
			SELECT @current_document_date = COALESCE(v.Actual_Visit_Date, vp.Scheduled_Visit_Date) FROM CaregiverNote cgn LEFT JOIN Visits v ON v.Visit_Id = cgn.visit_id LEFT JOIN VisitPlan vp ON vp.visit_plan_id = cgn.visit_plan_id  WHERE COALESCE(cgn.is_deleted,0) = 0 AND cgn.cg_note_id = @cg_note_id
			SELECT @current_document_key = @cg_note_id
		END
		
		
		DECLARE U_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates 
		WHERE
		(
		(@page_source = doc_type AND @current_document_key != [key])
		OR
		(@page_source != doc_type AND @current_document_key = [key])
		OR
		(@page_source != doc_type AND @current_document_key != [key])
		)

		AND doc_date >= @current_document_date
		
		OPEN U_Document_Cursor
		FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key
		WHILE @@FETCH_STATUS = 0
		BEGIN
		
		  UPDATE CarePlan_Problem SET  
		  problem_status = CASE WHEN problem_status = 'resolved' THEN 'resolved' ELSE @pbm_problem_status END,  
		  related_to_hhc_diag = @pbm_related_to_hhc_diag,  
		  severity_of_care_problem = @pbm_severity_of_care_problem,
		  updated_date = GETDATE(),  
		  updated_by = @user_id
		  WHERE problem_group_id = @pbm_problem_group_id
		  AND (
			(@u_doc_type = 'PTO' AND pto_id = @u_key AND page_source = 'PTO')
			OR
			(@u_doc_type = 'POC' AND poc_id = @u_key AND page_source = 'POC')
			OR
			(@u_doc_type = 'OASIS' AND oasis_id = @u_key AND page_source = 'OASIS')
			OR
			(@u_doc_type = 'TCN' AND tcn_id = @u_key AND page_source = 'TCN')
			OR
			(@u_doc_type IN ('VisitPlan-TCN','VisitPlan-PTO') AND cg_note_id = @u_key AND page_source IN ('VisitPlan-TCN','VisitPlan-PTO'))
			
		  )
		
			FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key
		END
		
		CLOSE U_Document_Cursor
		DEALLOCATE U_Document_Cursor
		
		
		
	
	END




  
 END  
  
 IF @pbm_Action = 'Delete'  
 BEGIN


	IF(@page_source IN ('VisitPlan-TCN', 'VisitPlan-PTO', 'TCN') OR (@page_source = 'PTO' AND @PTOType != 'AdmissionOrder'))
	BEGIN
		UPDATE CarePlan_Problem SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE problem_id = @pbm_problem_id


		UPDATE CarePlan_Goal SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE problem_id = @pbm_problem_id


		UPDATE CarePlan_Intervention SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE goal_id IN(SELECT goal_id FROM CarePlan_Goal WHERE problem_id = @pbm_problem_id AND is_deleted = 1)
	END


  
	IF(@page_source = 'PTO' AND NOT COALESCE(@PTOType, '') = 'CarePlanOrder' )  
	BEGIN  
		UPDATE CarePlan_Problem SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE (
			problem_group_id = @pbm_problem_group_id AND (
				(page_source = 'PTO' AND pto_id = @pto_id)
				OR
				(page_source = 'OASIS' AND oasis_id = @oasis_id)
				OR
				(page_source = 'POC' AND poc_id = @poc_id)
			) 

		OR problem_id = @pbm_problem_id
		)
  
		UPDATE CarePlan_Goal SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE goal_group_id = (
			SELECT TOP 1 goal_group_id FROM CarePlan_Goal WHERE episode_id = @episode_id AND COALESCE(is_deleted,0) = 0 AND problem_id = @pbm_problem_id
		) 

		AND (
			(page_source = 'PTO' AND pto_id = @pto_id)
			OR
			(page_source = 'OASIS' AND oasis_id = @oasis_id)
			OR
			(page_source = 'POC' AND poc_id = @poc_id)
		)
		
  
		UPDATE CarePlan_Intervention SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE intervention_group_id = (
			SELECT TOP 1 intervention_group_id FROM CarePlan_Intervention WHERE episode_id = @episode_id AND COALESCE(is_deleted,0) = 0 AND goal_id = (
				SELECT TOP 1 goal_id FROM CarePlan_Goal WHERE problem_id = @pbm_problem_id AND episode_id = @episode_id AND COALESCE(is_deleted,0) = 1
			)
			
		) 

		AND (
				(page_source = 'PTO' AND pto_id = @pto_id)
				OR
				(page_source = 'OASIS' AND oasis_id = @oasis_id)
				OR
				(page_source = 'POC' AND poc_id = @poc_id)
			)
	 
	END
   

  
	IF(@page_source = 'OASIS')  
	BEGIN  
  
		UPDATE CarePlan_Problem SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE problem_group_id = @pbm_problem_group_id AND (
			(page_source = 'OASIS' AND oasis_id = @oasis_id)
			OR
			(page_source = 'POC' AND poc_id = @poc_id)
		)
  
		UPDATE CarePlan_Goal SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE problem_id IN(SELECT problem_id FROM Careplan_problem WHERE problem_group_id = @pbm_problem_group_id AND(
			(page_source = 'OASIS' AND oasis_id = @oasis_id)
			OR
			(page_source = 'POC' AND poc_id = @poc_id)
		))   
		AND page_source IN('OASIS', 'POC')  
  
		UPDATE CarePlan_Intervention SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE goal_id IN(
			SELECT goal_id FROM CarePlan_Goal WHERE problem_id IN (
				SELECT problem_id FROM Careplan_problem WHERE problem_group_id = @pbm_problem_group_id AND(
					(page_source = 'OASIS' AND oasis_id = @oasis_id)
					OR
					(page_source = 'POC' AND poc_id = @poc_id)
				)
			)  
			AND page_source IN('OASIS', 'POC')
		)  
		AND page_source IN('OASIS', 'POC')  
	END
  
 
	IF(@page_source = 'POC')  
	BEGIN  
  
		UPDATE CarePlan_Problem SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE problem_id = @pbm_problem_id AND page_source IN('POC')  
  
		UPDATE CarePlan_Goal SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE problem_id IN(SELECT problem_id FROM Careplan_problem WHERE problem_id = @pbm_problem_id AND page_source IN('POC'))   
		AND page_source IN('POC')  
  
		UPDATE CarePlan_Intervention SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE goal_id IN(SELECT goal_id FROM CarePlan_Goal WHERE   
		problem_id IN (SELECT problem_id FROM Careplan_problem WHERE problem_id = @pbm_problem_id AND page_source IN('POC'))  
		AND page_source IN('POC'))  
		AND page_source IN('POC')  
	END  
  
 END 
 
 IF @pbm_Action = 'View'
 BEGIN
   --BEGIN Mark A. 05/13/2024 Enhancement
  
   
  IF(@page_source = 'POC')
  BEGIN

	--Code for overriding care plan to succeeding documents of POC Mark A. 10/15/2024

	DECLARE D_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates
	OPEN D_Document_Cursor
	FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @d_doc_date >= @poc_date AND ((@d_doc_type = 'POC' AND @d_doc_key != @poc_id) or (@d_doc_type != 'POC'))
		BEGIN

		 
		  INSERT INTO CarePlan_Problem  
		  (
		  problem_template_id,
		  bodysystem_id,
		  problem_desc,
		  problem_status,
		  problem_source,
		  problem_group_id,
		  page_source,
		  related_to_hhc_diag,
		  severity_of_care_problem,
		  m0020_pat_id,
		  patient_intake_id,
		  episode_id,
		  pto_id,
		  oasis_id,
		  poc_id,
		  tcn_id,
		  created_date,
		  created_by,
		  updated_date,
		  updated_by,
		  agency_id,
		  cg_note_id
		  ) 

		  SELECT
			  @pbm_problem_template_id,
			  @pbm_bodysystem_id,
			  @pbm_problem_desc,
			  @pbm_problem_status,
			  @pbm_problem_source,
			  @pbm_problem_group_id,
			  @d_doc_type,
			  @pbm_related_to_hhc_diag,
			  @pbm_severity_of_care_problem,
			  @patient_id,
			  @intake_id,
			  @episode_id,
			  CASE WHEN @d_doc_type = 'PTO' THEN @d_doc_key ELSE -1 END,
			  CASE WHEN @d_doc_type = 'OASIS' THEN @d_doc_key ELSE -1 END,
			  CASE WHEN @d_doc_type = 'POC' THEN @d_doc_key ELSE -1 END,
			  CASE WHEN @d_doc_type = 'TCN' THEN @d_doc_key ELSE -1 END,
			  GETDATE(),
			  'pocupdate',
			  GETDATE(),
			  'pocupdate',
			  @agencyId,
			  CASE WHEN @d_doc_type = 'VisitPlan-TCN' THEN @d_doc_key ELSE -1 END

		END

		FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	END
	CLOSE D_Document_Cursor
	DEALLOCATE D_Document_Cursor



 END



    --Start Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024

	IF @page_source IN ('VisitPlan-TCN','VisitPlan-PTO') AND (COALESCE(@tcn_id,0) NOT IN (-1,0) OR COALESCE(@pto_id,0) NOT IN (-1,0))
	BEGIN
		INSERT INTO CarePlan_Problem (
			problem_template_id,
			bodysystem_id,  
			problem_desc,  
			problem_status,  
			problem_source,  
			problem_group_id,  
			page_source,  
			related_to_hhc_diag,  
			severity_of_care_problem,  
			m0020_pat_id,  
			patient_intake_id,  
			episode_id,  
			pto_id,  
			oasis_id,  
			poc_id,  
			tcn_id,  
			created_date,  
			created_by,  
			updated_date,  
			updated_by,  
			agency_id,
			cg_note_id
		)
		
		SELECT
			@pbm_problem_template_id,  
			@pbm_bodysystem_id,  
			@pbm_problem_desc,  
			@pbm_problem_status,  
			@pbm_problem_source,   
			@pbm_problem_group_id,  
			CASE WHEN @page_source = 'VisitPlan-TCN' THEN 'TCN' ELSE 'PTO' END,  
			@pbm_related_to_hhc_diag,  
			@pbm_severity_of_care_problem,  
			@patient_id,  
			@intake_id,  
			@episode_id,  
			@pto_id,  
			@oasis_id,  
			@poc_id,  
			@tcn_id, 
			CASE WHEN @pbm_Action = 'AddFromLateAdmissionOrder' THEN @current_pto_call_date ELSE GETDATE() END,  
			@user_id,  
			GETDATE(),  
			@user_id,  
			@agencyId,
			-1
		FROM @ProblemCopyRefs pcr

		WHERE pcr.from_problem_id = @pbm_problem_id
  
		SET @new_problem_id = SCOPE_IDENTITY();

		UPDATE @ProblemCopyRefs SET db_identity = @new_problem_id WHERE from_problem_id = @pbm_problem_id

		UPDATE cgcr SET cgcr.problem_id_db_identity = @new_problem_id FROM @CareGoalCopyRefs cgcr WHERE cgcr.from_probem_id = @pbm_problem_id

	END

  --End Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024



  --END Mark A. 05/13/2024
 END
  
 FETCH NEXT FROM ProblemCursor     
 INTO  @pbm_Action  
 ,@pbm_problem_id  
 ,@pbm_problem_template_id  
 ,@pbm_bodysystem_id   
 ,@pbm_problem_desc  
 ,@pbm_problem_status   
 ,@pbm_problem_source  
 ,@pbm_problem_group_id   
 ,@page_source   
 ,@pbm_related_to_hhc_diag   
 ,@pbm_severity_of_care_problem   
 ,@pbm_episode_id   
 ,@pbm_pto_id   
 ,@pbm_oasis_id   
 ,@pbm_poc_id
 ,@pbm_add_option
 ,@pbm_edit_option
  
 END  
  
 CLOSE ProblemCursor;    
 DEALLOCATE ProblemCursor;    
 --Problem Process End-------------------------------------  
  
 --Care Goal Process Start----------------------------------  
 DECLARE CareGoalCursor CURSOR FOR  
 SELECT   
  [Action]  
 ,goal_id   
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
 ,comment   
 ,episode_id   
 ,pto_id   
 ,oasis_id   
 ,poc_id
 ,add_option
 ,edit_option
 FROM @CareGoalTempTable  
  
 OPEN CareGoalCursor  
  
 FETCH NEXT FROM CareGoalCursor  
 INTO    
  @cg_Action  
 ,@cg_goal_id   
 ,@cg_caregoal_template_id   
 ,@cg_problem_id   
 ,@cg_goal_desc   
 ,@cg_goal_status   
 ,@cg_goal_source   
 ,@cg_goal_group_id   
 ,@cg_page_source   
 ,@cg_target_date  
 ,@cg_goal_setfor  
 ,@cg_resolution_date  
 ,@cg_comment   
 ,@cg_episode_id   
 ,@cg_pto_id   
 ,@cg_oasis_id   
 ,@cg_poc_id
 ,@cg_add_option
 ,@cg_edit_option
  
 WHILE @@FETCH_STATUS = 0    
 BEGIN   
  
 IF @cg_Action = 'Add' OR @cg_Action = 'AddFromLateAdmissionOrder' OR @cg_Action = 'AddFromProfile' OR @cg_Action = 'AddFromProfileTCN' OR @cg_Action = 'AddFromVisitNote'  
 BEGIN  
    
  DECLARE @new_caregoal_id BIGINT;  
  
  SET @page_source = CASE WHEN @cg_Action = 'AddFromLateAdmissionOrder' OR @cg_Action = 'AddFromProfile' THEN 'PTO' WHEN @pbm_Action = 'AddFromProfileTCN' THEN 'TCN' ELSE @page_source END  
  
  

  DECLARE @cg_existing_goal_group_id BIGINT, @cg_existing_goal_source VARCHAR(100), @cg_addtoall_source_id BIGINT
  SET @cg_existing_goal_group_id = NULL
  SET @cg_existing_goal_source = NULL
  SET @cg_addtoall_source_id = NULL
  

  SELECT TOP 1 @cg_existing_goal_group_id = goal_group_id, @cg_existing_goal_source = goal_source FROM @ExistingTempGoal etg JOIN @ExistingTempProblem etp ON etp.problem_id = etg.problem_id WHERE etg.goal_group_id NOT IN (SELECT _etg.goal_group_id FROM @ExistingTempGoal _etg WHERE ISNULL(_etg.resolution_date,'') NOT IN ('','0001-01-01') AND _etg.goal_group_id = etg.goal_group_id) AND etg.caregoal_template_id = @cg_caregoal_template_id AND etp.problem_template_id = (SELECT cp.problem_template_id FROM CarePlan_Problem cp WHERE COALESCE(is_deleted,0) = 0 AND cp.problem_id = @cg_problem_id) AND etp.bodysystem_id = (SELECT cp.bodysystem_id FROM CarePlan_Problem cp WHERE COALESCE(is_deleted,0) = 0 AND cp.problem_id = @cg_problem_id) AND etp.problem_group_id = (SELECT cp.problem_group_id FROM CarePlan_Problem cp WHERE COALESCE(is_deleted,0) = 0 AND cp.problem_id = @cg_problem_id)

  INSERT INTO CarePlan_Goal  
  (caregoal_template_id  
  ,problem_id  
  ,goal_desc  
  ,goal_status  
  ,goal_source  
  ,goal_group_id  
  ,page_source  
  ,target_date  
  ,goal_setfor  
  ,resolution_date  
  ,comment  
  ,m0020_pat_id  
  ,patient_intake_id  
  ,episode_id  
  ,pto_id  
  ,oasis_id  
  ,poc_id  
  ,tcn_id  
  ,created_date  
  ,created_by  
  ,updated_date  
  ,updated_by  
  ,agency_id
  ,cg_note_id)  
  VALUES(  
   @cg_caregoal_template_id  
  ,@cg_problem_id  
  ,@cg_goal_desc  
  ,@cg_goal_status  
  ,CASE WHEN COALESCE(@cg_existing_goal_source, '') <> '' AND @page_source <> 'POC' THEN @cg_existing_goal_source ELSE  @cg_goal_source END   
  ,CASE WHEN COALESCE(@cg_existing_goal_group_id,0) <> 0 AND @page_source <> 'POC' THEN  @cg_existing_goal_group_id ELSE  @cg_goal_group_id  END
  ,CASE WHEN @page_source = 'VisitPlan-PTO' THEN 'VisitPlan-TCN' ELSE @page_source END  
  ,@cg_target_date  
  ,@cg_goal_setfor  
  ,@cg_resolution_date  
  ,@cg_comment  
  ,@patient_id  
  ,@intake_id  
  ,@episode_id  
  ,CASE WHEN @page_source = 'VisitPlan-PTO' THEN -1 ELSE @pto_id END  
  ,@oasis_id  
  ,@poc_id  
  ,CASE WHEN @page_source = 'VisitPlan-TCN' THEN -1 ELSE @tcn_id END  
  ,GETDATE()  
  ,@user_id  
  ,GETDATE()  
  ,@user_id  
  ,@agencyId
  ,@cg_note_id)  
    
  SET @new_caregoal_id = SCOPE_IDENTITY();
  SET @cg_addtoall_source_id = @new_caregoal_id;  
   
  UPDATE @InterventionTempTable SET goal_id = @new_caregoal_id WHERE goal_id = @cg_goal_id AND ([Action] = 'Add' OR @cg_Action = 'AddFromProfile' OR @cg_Action = 'AddFromProfileTCN' OR @cg_Action = 'AddFromVisitNote')

  UPDATE @CareGoalCommentTempTable 
  SET goal_group_id = CASE WHEN (@cg_Action = 'ADD' OR (@cg_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') NOT IN('CarePlanOrder', 'ResumptionOfCare') )) THEN (CASE WHEN COALESCE(@cg_existing_goal_group_id,0) <> 0 THEN  @cg_existing_goal_group_id ELSE  @new_caregoal_id  END) /*@new_caregoal_id*/ ELSE @cg_goal_group_id END 
  WHERE goal_group_id = @cg_goal_id AND ([Action] = 'Add' OR @cg_Action = 'AddFromProfile' OR @cg_Action = 'AddFromProfileTCN' OR @cg_Action = 'AddFromVisitNote')
  

    --BEGIN Mark A. 05/13/2024 Enhancement
  IF(@page_source = 'POC' AND @cg_Action = 'Add')
  BEGIN

	DECLARE @poc_replicate_problem_group_id BIGINT, @poc_replicate_new_problem_id BIGINT, @poc_replicate_problem_template_id BIGINT, @poc_replicate_bodysystem_id BIGINT;
	
	SELECT @poc_replicate_problem_group_id = NULL, @poc_replicate_problem_template_id = NULL, @poc_replicate_bodysystem_id = NULL
	SELECT TOP 1 @poc_replicate_problem_group_id = problem_group_id, @poc_replicate_problem_template_id = problem_template_id, @poc_replicate_bodysystem_id = bodysystem_id FROM CarePlan_Problem WHERE problem_id = @cg_problem_id	
	
	
	DECLARE D_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates
	OPEN D_Document_Cursor
	FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @d_doc_date >= @poc_date AND ((@d_doc_type = 'POC' AND @d_doc_key != @poc_id) or (@d_doc_type != 'POC'))
		BEGIN
		
			
			SET @poc_replicate_new_problem_id = NULL
			SELECT TOP 1 @poc_replicate_new_problem_id = problem_id FROM CarePlan_Problem WHERE COALESCE(is_deleted, 0) = 0 AND problem_template_id = @poc_replicate_problem_template_id AND bodysystem_id = @poc_replicate_bodysystem_id AND problem_group_id = @poc_replicate_problem_group_id AND (( page_source = 'PTO' AND @d_doc_type = 'PTO' AND pto_id = @d_doc_key ) OR ( page_source = 'OASIS' AND @d_doc_type = 'OASIS' AND oasis_id = @d_doc_key ) OR ( page_source = 'POC' AND @d_doc_type = 'POC' AND poc_id = @d_doc_key ) OR ( page_source = 'TCN' AND @d_doc_type = 'TCN' AND tcn_id = @d_doc_key ) OR ( page_source = 'VisitPlan-TCN' AND @d_doc_type = 'VisitPlan-TCN' AND cg_note_id = @d_doc_key )) 
			
			IF COALESCE(@poc_replicate_new_problem_id, 0) <> 0
			BEGIN

				INSERT INTO CarePlan_Goal  
				(
				caregoal_template_id,
				problem_id,
				goal_desc,
				goal_status,
				goal_source,
				goal_group_id,
				page_source,
				target_date,
				goal_setfor,
				resolution_date,
				comment,
				m0020_pat_id,
				patient_intake_id,
				episode_id,
				pto_id,
				oasis_id,
				poc_id,
				tcn_id,
				created_date,
				created_by,
				updated_date,
				updated_by,
				agency_id,
				cg_note_id
				)  

				SELECT
				@cg_caregoal_template_id,
				@poc_replicate_new_problem_id,
				@cg_goal_desc,
				@cg_goal_status,
				@page_source,   
				@new_caregoal_id,
				@d_doc_type,
				@cg_target_date,
				@cg_goal_setfor,
				@cg_resolution_date,
				@cg_comment,
				@patient_id,
				@intake_id,
				@episode_id,
				CASE WHEN @d_doc_type = 'PTO' THEN @d_doc_key ELSE -1 END,
				CASE WHEN @d_doc_type = 'OASIS' THEN @d_doc_key ELSE -1 END,
				CASE WHEN @d_doc_type = 'POC' THEN @d_doc_key ELSE -1 END,
				CASE WHEN @d_doc_type = 'TCN' THEN @d_doc_key ELSE -1 END,
				GETDATE(),
				'pocupdate',
				GETDATE(),
				'pocupdate',
				@agencyId,
				CASE WHEN @d_doc_type = 'VisitPlan-TCN' THEN @d_doc_key ELSE -1 END

			
			END



		END

		FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	END
	CLOSE D_Document_Cursor
	DEALLOCATE D_Document_Cursor

	UPDATE CarePlan_CareGoal_Comment SET goal_group_id = @new_caregoal_id WHERE goal_group_id = @cg_existing_goal_group_id
	UPDATE @CareGoalCommentTempTable SET goal_group_id = @new_caregoal_id WHERE goal_group_id = @cg_existing_goal_group_id

 END



  --END Mark A. 05/13/2024




  
   IF(NOT @cg_Action = 'AddFromLateAdmissionOrder')  
   BEGIN  
    
    IF(@cg_Action = 'ADD' OR (@cg_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') NOT IN('CarePlanOrder', 'ResumptionOfCare') ))  
    BEGIN  
    UPDATE CarePlan_Goal SET goal_group_id  = CASE WHEN COALESCE(@cg_existing_goal_group_id,0) <> 0 AND @page_source <> 'POC' THEN  @cg_existing_goal_group_id ELSE  @new_caregoal_id  END WHERE goal_id = @new_caregoal_id  
    END
	
	IF(@page_source = 'PTO' AND @cg_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') = 'Recertification')
	BEGIN
		UPDATE CarePlan_Goal SET goal_source = 'PTO' WHERE goal_id = @new_caregoal_id
	END
  
    IF(NOT COALESCE(@PTOType, '') = 'CarePlanOrder' AND NOT COALESCE(@cg_Action,'') = 'AddFromVisitNote')  
    BEGIN  
  
    DECLARE @cg_prob_group_id AS BIGINT  
  
    SELECT @cg_prob_group_id = problem_group_id FROM Careplan_Problem WHERE problem_id = @cg_problem_id AND episode_id = @episode_id  
  
     IF(@page_source = 'TCN')  
     BEGIN  
     UPDATE CarePlan_Goal SET  
     resolution_date = @cg_resolution_date  
     ,updated_date = DATEADD(ss,1,GETDATE())  
     ,updated_by = @user_id  
     WHERE goal_group_id = @cg_goal_group_id AND page_source = 'TCN'  
     AND tcn_id IN(SELECT tcn_id FROM @ToBeUpdatedTCNList)  
     END  
      
     IF(@page_source = 'PTO')  
     BEGIN  
     declare @oasis_probid int;  
     SELECT @oasis_probid = problem_id FROM CarePlan_Problem WHERE problem_group_id = @cg_prob_group_id AND page_source = 'OASIS' AND oasis_id = @oasis_id AND COALESCE(is_deleted,0) = 0;  
  
     IF @oasis_probid is not null  
     BEGIN  
      --OASIS  
      INSERT INTO CarePlan_Goal  
     (caregoal_template_id  
     ,problem_id  
     ,goal_desc  
     ,goal_status  
     ,goal_source  
     ,goal_group_id  
     ,page_source  
     ,target_date  
     ,goal_setfor  
     ,resolution_date  
     ,comment  
     ,m0020_pat_id  
     ,patient_intake_id  
     ,episode_id  
     ,pto_id  
     ,oasis_id  
     ,poc_id  
     ,created_date  
     ,created_by  
     ,updated_date  
     ,updated_by  
     ,agency_id)  
     VALUES(  
      @cg_caregoal_template_id  
     ,@oasis_probid  
     ,@cg_goal_desc  
     ,@cg_goal_status  
     ,CASE WHEN @cg_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') = 'ResumptionOfCare' THEN @cg_goal_source ELSE (CASE WHEN COALESCE(@cg_existing_goal_source, '') <> '' THEN @cg_existing_goal_source ELSE  @page_source END) END  
     ,CASE WHEN COALESCE(@cg_existing_goal_group_id,0) <> 0 THEN  @cg_existing_goal_group_id ELSE  @new_caregoal_id  END  
     ,'OASIS'  
     ,@cg_target_date  
     ,@cg_goal_setfor  
     ,@cg_resolution_date  
     ,@cg_comment  
     ,@patient_id  
     ,@intake_id  
     ,@episode_id  
     ,@pto_id  
     ,@oasis_id  
     ,@poc_id  
     ,GETDATE()  
     ,@user_id  
     ,GETDATE()  
     ,@user_id  
     ,@agencyId)  
     END  
       
     END  
       
     declare @poc_probid int;  
     SELECT @poc_probid = problem_id FROM CarePlan_Problem WHERE problem_group_id = @cg_prob_group_id AND page_source = 'POC' AND poc_id = @poc_id AND COALESCE(is_deleted,0) = 0;  
  
     IF(@page_source <> 'POC' AND @page_source <> 'TCN' AND @poc_probid is not null AND @poc_id <> -1)  
     BEGIN  
    
      --POC  
      INSERT INTO CarePlan_Goal  
     (caregoal_template_id  
     ,problem_id  
     ,goal_desc  
     ,goal_status  
     ,goal_source  
     ,goal_group_id  
     ,page_source  
     ,target_date  
     ,goal_setfor  
     ,resolution_date  
     ,comment  
     ,m0020_pat_id  
     ,patient_intake_id  
     ,episode_id  
     ,pto_id  
     ,oasis_id  
     ,poc_id  
     ,created_date  
     ,created_by  
     ,updated_date  
     ,updated_by  
     ,agency_id)  
     VALUES(  
      @cg_caregoal_template_id  
     ,@poc_probid  
     ,@cg_goal_desc  
     ,@cg_goal_status  
     ,CASE WHEN @page_source = 'PTO' AND @cg_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') = 'ResumptionOfCare' THEN @cg_goal_source ELSE (CASE WHEN COALESCE(@cg_existing_goal_source, '') <> '' THEN @cg_existing_goal_source ELSE  @page_source END) END 
     ,CASE WHEN COALESCE(@cg_existing_goal_group_id,0) <> 0 THEN  @cg_existing_goal_group_id ELSE  @new_caregoal_id  END  
     ,'POC'  
     ,@cg_target_date  
     ,@cg_goal_setfor  
     ,@cg_resolution_date  
     ,@cg_comment  
     ,@patient_id  
     ,@intake_id  
     ,@episode_id  
     ,@pto_id  
     ,@oasis_id  
     ,@poc_id  
     ,GETDATE()  
     ,@user_id  
     ,GETDATE()  
     ,@user_id  
     ,@agencyId)  
      
    END  
   END  
  END  
   ELSE  
   BEGIN  
    UPDATE @InterventionTempTable SET goal_id = @new_caregoal_id WHERE goal_id = @cg_goal_group_id AND [Action] = 'AddFromLateAdmissionOrder'  
     
   UPDATE CarePlan_Goal SET  
   goal_status = @cg_goal_status  
   ,goal_desc = @cg_goal_desc  
   ,target_date = @cg_target_date  
   ,goal_setfor = @cg_goal_setfor  
   ,resolution_date = @cg_resolution_date  
   ,comment = @cg_comment  
   ,updated_date = GETDATE()  
   ,updated_by = @user_id  
   --,pto_id = @pto_id  
   ,created_date = @current_pto_call_date  
   --,goal_source = 'PTO'  
   WHERE goal_group_id = @cg_goal_group_id AND goal_source = 'OASIS'  
   END

  --Start Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024

	IF @page_source IN ('VisitPlan-TCN','VisitPlan-PTO') AND (COALESCE(@tcn_id,0) NOT IN (-1,0) OR COALESCE(@pto_id,0) NOT IN (-1,0))
	BEGIN
		INSERT INTO CarePlan_Goal(
			caregoal_template_id,  
			problem_id,  
			goal_desc,  
			goal_status,  
			goal_source,  
			goal_group_id,  
			page_source,  
			target_date,  
			goal_setfor,  
			resolution_date,  
			comment,  
			m0020_pat_id,  
			patient_intake_id,  
			episode_id,  
			pto_id,  
			oasis_id,  
			poc_id,  
			tcn_id,  
			created_date,  
			created_by,  
			updated_date,  
			updated_by,  
			agency_id,
			cg_note_id
		)  
		
		SELECT
			@cg_caregoal_template_id,  
			cgcr.problem_id_db_identity,  
			@cg_goal_desc,  
			@cg_goal_status,  
			CASE WHEN COALESCE(@cg_existing_goal_source, '') <> '' THEN @cg_existing_goal_source ELSE  @cg_goal_source END,   
			CASE WHEN COALESCE(@cg_existing_goal_group_id,0) <> 0 THEN  @cg_existing_goal_group_id ELSE  @new_caregoal_id  END,  
			CASE WHEN @page_source = 'VisitPlan-TCN' THEN 'TCN' ELSE 'PTO' END,  
			@cg_target_date,  
			@cg_goal_setfor,  
			@cg_resolution_date,  
			@cg_comment,  
			@patient_id,  
			@intake_id,  
			@episode_id,  
			@pto_id,  
			@oasis_id,  
			@poc_id,  
			@tcn_id,  
			GETDATE(),  
			@user_id,  
			GETDATE(),  
			@user_id,  
			@agencyId,
			-1
		FROM
			@CareGoalCopyRefs cgcr

		WHERE cgcr.from_goal_id = @cg_goal_id

		SET @new_caregoal_id = SCOPE_IDENTITY();

		UPDATE @CareGoalCopyRefs SET db_identity = @new_caregoal_id WHERE from_goal_id = @cg_goal_id

		UPDATE icr SET icr.goal_id_db_identity = @new_caregoal_id FROM @InterventionCopyRefs icr WHERE icr.from_goal_id = @cg_goal_id

	END

  --End Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024


	--Start Mark A. 10/09/2024 Check if the add option is 'Add to all referencing documents', 'Add and replace in all referencing document' or 'Add to this document only'



	IF @cg_Action = 'Add' AND @page_source <> 'POC' AND ISNULL(@cg_resolution_date,'') IN ('','0001-01-01')
	BEGIN
		DECLARE @existing_goal_group_id BIGINT, @existing_goal_id BIGINT, @existing_goal_problem_id BIGINT


		IF @page_source = 'PTO'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM PTO WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND pto_id = @pto_id
			SELECT @current_document_key = @pto_id
		END


		IF @page_source = 'OASIS'
		BEGIN
			SELECT  @current_document_date = CASE WHEN o.m0100_assmt_reason = '01' THEN CAST(o.m0030_start_care_dt AS DATE) WHEN o.m0100_assmt_reason = '03' THEN CAST(o.m0032_roc_dt AS DATE) ELSE CAST(pto.call_date AS DATE) END FROM Oasis o JOIN PTO pto ON pto.pto_id = o.pto_id   WHERE o.episode_id = @episode_id AND COALESCE(o.isdeleted,0) = 0 AND o.m0100_assmt_reason IN('01','03','04') AND o.OasisID = @oasis_id
			SELECT @current_document_key = @oasis_id
		END


		IF @page_source = 'TCN'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM TelCommunicationNote WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND tcn_id = @tcn_id
			SELECT @current_document_key = @tcn_id
		END


		IF @page_source  IN ('VisitPlan-TCN','VisitPlan-PTO')
		BEGIN
			SELECT @current_document_date = COALESCE(v.Actual_Visit_Date, vp.Scheduled_Visit_Date) FROM CaregiverNote cgn LEFT JOIN Visits v ON v.Visit_Id = cgn.visit_id LEFT JOIN VisitPlan vp ON vp.visit_plan_id = cgn.visit_plan_id  WHERE COALESCE(cgn.is_deleted,0) = 0 AND cgn.cg_note_id = @cg_note_id
			SELECT @current_document_key = @cg_note_id
		END



		DECLARE U_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates 
		WHERE
		(
			(@page_source = doc_type AND @current_document_key != [key])
			OR
			(@page_source != doc_type AND @current_document_key = [key])
			OR
			(@page_source != doc_type AND @current_document_key != [key])
		)


		AND doc_date >= @current_document_date
		OPEN U_Document_Cursor
		FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key
		WHILE @@FETCH_STATUS = 0
		BEGIN

			SELECT @existing_goal_group_id = NULL, @existing_goal_id = NULL, @existing_goal_problem_id = NULL
			SELECT TOP 1 @existing_goal_group_id = goal_group_id, @existing_goal_id = goal_id FROM dbo.Func_GetAllCarePlanCareGoalByEpisodeId(@episode_id, CASE WHEN @u_doc_type = 'PTO' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'OASIS' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'POC' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'TCN' THEN @u_key ELSE 0 END, @u_doc_type, CASE WHEN @u_doc_type = 'VisitPlan-TCN' THEN @u_key ELSE -1 END)  WHERE ISNULL(resolution_date,'') IN ('','0001-01-01') AND caregoal_template_id = @cg_caregoal_template_id AND problem_id IN (SELECT problem_id FROM CarePlan_Problem WHERE episode_id = @episode_id AND COALESCE(is_deleted,0) = 0 AND problem_group_id = (SELECT cp.problem_group_id FROM CarePlan_Problem cp WHERE cp.episode_id = @episode_id AND COALESCE(cp.is_deleted,0) = 0 AND cp.problem_id = @cg_problem_id))
			SELECT @existing_goal_problem_id = problem_id FROM dbo.Func_GetAllCarePlanProblemByEpisodeId(@episode_id, CASE WHEN @u_doc_type = 'PTO' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'OASIS' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'POC' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'TCN' THEN @u_key ELSE 0 END, @u_doc_type, CASE WHEN @u_doc_type = 'VisitPlan-TCN' THEN @u_key ELSE -1 END)  WHERE problem_group_id = (SELECT cp.problem_group_id FROM CarePlan_Problem cp WHERE cp.episode_id = @episode_id AND COALESCE(cp.is_deleted,0) = 0 AND cp.problem_id = @cg_problem_id)

			IF COALESCE(@existing_goal_problem_id,0) <> 0 AND (( @cg_add_option = 1 AND COALESCE(@existing_goal_group_id,0) = 0 ) OR ( @cg_add_option = 2 AND COALESCE(@existing_goal_group_id,0) = 0)) 

			BEGIN

				INSERT INTO CarePlan_Goal (caregoal_template_id, problem_id, goal_desc, goal_status, goal_source, goal_group_id, page_source, comment, target_date, goal_setfor, resolution_date, m0020_pat_id, patient_intake_id, episode_id, pto_id, oasis_id, poc_id, created_date, created_by, updated_date, updated_by, agency_id, is_deleted, tcn_id, isDisabled, cg_note_id)
				SELECT TOP 1 @cg_caregoal_template_id, @existing_goal_problem_id, @cg_goal_desc, @cg_goal_status, goal_source, goal_group_id, @u_doc_type, @cg_comment, @cg_target_date, @cg_goal_setfor, @cg_resolution_date, m0020_pat_id, patient_intake_id, episode_id, CASE WHEN @u_doc_type = 'PTO' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'OASIS' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'POC' THEN @u_key ELSE -1 END, GETDATE(), 'addtoall', GETDATE(), 'addtoall', agency_id, NULL, CASE WHEN @u_doc_type = 'TCN' THEN @u_key ELSE -1 END, isDisabled, CASE WHEN @u_doc_type = 'VisitPlan-TCN' THEN @u_key ELSE -1 END FROM CarePlan_Goal  WHERE goal_id = @cg_addtoall_source_id

			END


			IF COALESCE(@existing_goal_problem_id,0) <> 0 AND @cg_add_option = 2 AND COALESCE(@existing_goal_id,0) <> 0 AND @cg_existing_goal_group_id = @existing_goal_group_id
			BEGIN
				UPDATE CarePlan_Goal SET goal_desc = @cg_goal_desc, goal_status = @cg_goal_status, target_date = @cg_target_date, goal_setfor = @cg_goal_setfor, resolution_date = @cg_resolution_date, updated_date = GETDATE(), updated_by = 'updatetoall' WHERE goal_id = @existing_goal_id
			END

			FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key

		END

		CLOSE U_Document_Cursor

		DEALLOCATE U_Document_Cursor


		--Update source and group id if 'Add and Replace'
		IF (@cg_add_option = 2 AND COALESCE(@cg_existing_goal_group_id,0) <> 0)
		BEGIN
			UPDATE CarePlan_Goal SET goal_source = @cg_goal_source, goal_group_id = @new_caregoal_id WHERE goal_group_id = @cg_existing_goal_group_id
			UPDATE CarePlan_CareGoal_Comment SET goal_group_id = @new_caregoal_id WHERE goal_group_id = @cg_existing_goal_group_id
			UPDATE @CareGoalCommentTempTable SET goal_group_id = @new_caregoal_id WHERE goal_group_id = @cg_existing_goal_group_id
		END


	END

	--End Mark A. 10/09/2024 Check if the add option is 'Add to all referencing documents', 'Add and replace in all referencing document' or 'Add to this document only'

   
 END  
  
 IF @cg_Action = 'Edit'  
 BEGIN  
  
  UPDATE CarePlan_Goal SET  
  goal_status = @cg_goal_status  
  ,goal_desc = @cg_goal_desc  
  ,target_date = @cg_target_date  
  ,goal_setfor = @cg_goal_setfor  
  ,resolution_date = @cg_resolution_date  
  ,comment = @cg_comment  
  ,updated_date = GETDATE()  
  ,updated_by = @user_id  
  WHERE goal_id = @cg_goal_id
  
  --BEGIN Mark A. 05/13/2024 Enhancement
  IF(@page_source = 'POC')
  BEGIN

	DECLARE D_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates
	OPEN D_Document_Cursor
	FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @d_doc_date >= @poc_date AND ((@d_doc_type = 'POC' AND @d_doc_key != @poc_id) or (@d_doc_type != 'POC'))
		BEGIN
		
			SET @poc_replicate_problem_group_id = NULL
			SELECT TOP 1 @poc_replicate_problem_group_id = problem_group_id FROM @ProblemTempTable WHERE problem_id = @cg_problem_id
			
			SET @poc_replicate_new_problem_id = NULL
			SELECT TOP 1 @poc_replicate_new_problem_id = problem_id FROM CarePlan_Problem WHERE COALESCE(is_deleted, 0) = 0 AND problem_group_id = @poc_replicate_problem_group_id AND (( page_source = 'PTO' AND @d_doc_type = 'PTO' AND pto_id = @d_doc_key ) OR ( page_source = 'OASIS' AND @d_doc_type = 'OASIS' AND oasis_id = @d_doc_key ) OR ( page_source = 'POC' AND @d_doc_type = 'POC' AND poc_id = @d_doc_key ) OR ( page_source = 'TCN' AND @d_doc_type = 'TCN' AND tcn_id = @d_doc_key ) OR ( page_source = 'VisitPlan-TCN' AND @d_doc_type = 'VisitPlan-TCN' AND cg_note_id = @d_doc_key )) 
			
			IF COALESCE(@poc_replicate_new_problem_id, 0) <> 0
			BEGIN

				INSERT INTO CarePlan_Goal  
				(
				caregoal_template_id,
				problem_id,
				goal_desc,
				goal_status,
				goal_source,
				goal_group_id,
				page_source,
				target_date,
				goal_setfor,
				resolution_date,
				comment,
				m0020_pat_id,
				patient_intake_id,
				episode_id,
				pto_id,
				oasis_id,
				poc_id,
				tcn_id,
				created_date,
				created_by,
				updated_date,
				updated_by,
				agency_id,
				cg_note_id
				)  

				SELECT
				@cg_caregoal_template_id,
				@poc_replicate_new_problem_id,
				@cg_goal_desc,
				@cg_goal_status,
				@cg_goal_source,
				@cg_goal_group_id,
				@d_doc_type,
				@cg_target_date,
				@cg_goal_setfor,
				@cg_resolution_date,
				@cg_comment,
				@patient_id,
				@intake_id,
				@episode_id,
				CASE WHEN @d_doc_type = 'PTO' THEN @d_doc_key ELSE -1 END,
				CASE WHEN @d_doc_type = 'OASIS' THEN @d_doc_key ELSE -1 END,
				CASE WHEN @d_doc_type = 'POC' THEN @d_doc_key ELSE -1 END,
				CASE WHEN @d_doc_type = 'TCN' THEN @d_doc_key ELSE -1 END,
				GETDATE(),
				'pocupdate',
				GETDATE(),
				'pocupdate',
				@agencyId,
				CASE WHEN @d_doc_type = 'VisitPlan-TCN' THEN @d_doc_key ELSE -1 END

			
			END



		END

		FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	END
	CLOSE D_Document_Cursor
	DEALLOCATE D_Document_Cursor

 END


   --Start Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024

	IF @page_source IN ('VisitPlan-TCN','VisitPlan-PTO') AND (COALESCE(@tcn_id,0) NOT IN (-1,0) OR COALESCE(@pto_id,0) NOT IN (-1,0))
	BEGIN
		INSERT INTO CarePlan_Goal(
			caregoal_template_id,  
			problem_id,  
			goal_desc,  
			goal_status,  
			goal_source,  
			goal_group_id,  
			page_source,  
			target_date,  
			goal_setfor,  
			resolution_date,  
			comment,  
			m0020_pat_id,  
			patient_intake_id,  
			episode_id,  
			pto_id,  
			oasis_id,  
			poc_id,  
			tcn_id,  
			created_date,  
			created_by,  
			updated_date,  
			updated_by,  
			agency_id,
			cg_note_id
		)  
		
		SELECT
			@cg_caregoal_template_id,  
			cgcr.problem_id_db_identity,  
			@cg_goal_desc,  
			@cg_goal_status,  
			@cg_goal_source,   
			@cg_goal_group_id,  
			CASE WHEN @page_source = 'VisitPlan-TCN' THEN 'TCN' ELSE 'PTO' END,  
			@cg_target_date,  
			@cg_goal_setfor,  
			@cg_resolution_date,  
			@cg_comment,  
			@patient_id,  
			@intake_id,  
			@episode_id,  
			@pto_id,  
			@oasis_id,  
			@poc_id,  
			@tcn_id,  
			GETDATE(),  
			@user_id,  
			GETDATE(),  
			@user_id,  
			@agencyId,
			-1
		FROM
			@CareGoalCopyRefs cgcr

		WHERE cgcr.from_goal_id = @cg_goal_id

		SET @new_caregoal_id = SCOPE_IDENTITY();

		UPDATE @CareGoalCopyRefs SET db_identity = @new_caregoal_id WHERE from_goal_id = @cg_goal_id

		UPDATE icr SET icr.goal_id_db_identity = @new_caregoal_id FROM @InterventionCopyRefs icr WHERE icr.from_goal_id = @cg_goal_id

	END

  --End Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024



  --END Mark A. 05/13/2024

  
  IF(NOT COALESCE(@PTOType, '') = 'CarePlanOrder')  
  BEGIN  
  
   IF(@page_source = 'TCN')  
   BEGIN  
   UPDATE CarePlan_Goal SET  
   resolution_date = @cg_resolution_date  
   ,updated_date = DATEADD(ss,1,GETDATE())  
   ,updated_by = @user_id  
   WHERE goal_group_id = @cg_goal_group_id AND page_source = 'TCN'  
   AND tcn_id IN(SELECT tcn_id FROM @ToBeUpdatedTCNList)  
   END  
  
   IF(@page_source = 'PTO')  
   BEGIN  
   --OASIS  
   UPDATE CarePlan_Goal SET  
   goal_status = @cg_goal_status  
   ,goal_desc = @cg_goal_desc  
   ,target_date = @cg_target_date  
   ,goal_setfor = @cg_goal_setfor  
   ,resolution_date = @cg_resolution_date  
   ,comment = @cg_comment  
   ,updated_date = GETDATE()  
   ,updated_by = @user_id  
   WHERE goal_group_id = @cg_goal_group_id AND page_source = 'OASIS'  AND oasis_id = @oasis_id
  
   END  
  
      IF(@page_source <> 'POC' AND @page_source <> 'TCN' AND @page_source <> 'VisitPlan-TCN' AND @page_source <> 'VisitPlan-PTO')  
   BEGIN  
/*   IF(@page_source = 'OASIS')   
   BEGIN  
    SET @cg_goal_id = (SELECT goal_group_id FROM CarePlan_Goal WHERE goal_id = @cg_goal_id AND page_source = 'OASIS')  
   END */
  
    --POC  
    UPDATE CarePlan_Goal SET  
    goal_status = @cg_goal_status  
    ,goal_desc = @cg_goal_desc  
    ,target_date = @cg_target_date  
    ,goal_setfor = @cg_goal_setfor  
    ,resolution_date = @cg_resolution_date  
   ,comment = @cg_comment  
   ,updated_date = GETDATE()  
   ,updated_by = @user_id  
   WHERE goal_group_id = @cg_goal_group_id AND page_source = 'POC' AND poc_id = @poc_id 
  END  
  END

	SET @compound_edit_option = 0
	SELECT TOP 1 @compound_edit_option = edit_option FROM @ProblemTempTable WHERE problem_id = @cg_problem_id
	
	IF (@compound_edit_option = 1 OR ISNULL(@cg_resolution_date,'') NOT IN ('','0001-01-01')) AND ISNULL(@page_source,'') <> 'POC'
	BEGIN
	
		SELECT @current_document_date = NULL, @current_document_key = NULL, @existing_problem_group_id = NULL, @existing_problem_id = NULL
	
		IF @page_source = 'PTO'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM PTO WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND pto_id = @pto_id
			SELECT @current_document_key = @pto_id
		END
		
		IF @page_source = 'OASIS'
		BEGIN
			SELECT  @current_document_date = CASE WHEN o.m0100_assmt_reason = '01' THEN CAST(o.m0030_start_care_dt AS DATE) WHEN o.m0100_assmt_reason = '03' THEN CAST(o.m0032_roc_dt AS DATE) ELSE CAST(pto.call_date AS DATE) END FROM Oasis o JOIN PTO pto ON pto.pto_id = o.pto_id   WHERE o.episode_id = @episode_id AND COALESCE(o.isdeleted,0) = 0 AND o.m0100_assmt_reason IN('01','03','04') AND o.OasisID = @oasis_id
			SELECT @current_document_key = @oasis_id
		END
		
		
		IF @page_source = 'TCN'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM TelCommunicationNote WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND tcn_id = @tcn_id
			SELECT @current_document_key = @tcn_id
		END
		
		IF @page_source  IN ('VisitPlan-TCN','VisitPlan-PTO')
		BEGIN
			SELECT @current_document_date = COALESCE(v.Actual_Visit_Date, vp.Scheduled_Visit_Date) FROM CaregiverNote cgn LEFT JOIN Visits v ON v.Visit_Id = cgn.visit_id LEFT JOIN VisitPlan vp ON vp.visit_plan_id = cgn.visit_plan_id  WHERE COALESCE(cgn.is_deleted,0) = 0 AND cgn.cg_note_id = @cg_note_id
			SELECT @current_document_key = @cg_note_id
		END
		
		
		DECLARE U_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates 
		WHERE
		(
			(@page_source = doc_type AND @current_document_key != [key])
			OR
			(@page_source != doc_type AND @current_document_key = [key])
			OR
			(@page_source != doc_type AND @current_document_key != [key])
		)


		AND doc_date >= @current_document_date
		OPEN U_Document_Cursor
		FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key
		WHILE @@FETCH_STATUS = 0
		BEGIN

			UPDATE CarePlan_Goal SET  
			goal_status = @cg_goal_status,  
			goal_desc = @cg_goal_desc,  
			target_date = @cg_target_date,  
			goal_setfor = @cg_goal_setfor,  
			resolution_date = CASE WHEN ISNULL(resolution_date,'') NOT IN ('','0001-01-01') THEN resolution_date ELSE @cg_resolution_date END,  
			comment = @cg_comment,  
			updated_date = GETDATE(),  
			updated_by = @user_id
			WHERE goal_group_id = @cg_goal_group_id
			AND (
				(@u_doc_type = 'PTO' AND pto_id = @u_key AND page_source = 'PTO')
				OR
				(@u_doc_type = 'POC' AND poc_id = @u_key AND page_source = 'POC')
				OR
				(@u_doc_type = 'OASIS' AND oasis_id = @u_key AND page_source = 'OASIS')
				OR
				(@u_doc_type = 'TCN' AND tcn_id = @u_key AND page_source = 'TCN')
				OR
				(@u_doc_type IN ('VisitPlan-TCN','VisitPlan-PTO') AND cg_note_id = @u_key AND page_source IN ('VisitPlan-TCN','VisitPlan-PTO'))

			)
			
		
			FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key
			
		END
		CLOSE U_Document_Cursor
		DEALLOCATE U_Document_Cursor
		
		
		
		
	END


  
 END  
  
 IF @cg_Action = 'Delete'  
 BEGIN

	IF(@page_source IN ('VisitPlan-TCN', 'VisitPlan-PTO', 'TCN') OR (@page_source = 'PTO' AND @PTOType != 'AdmissionOrder'))
	BEGIN
		UPDATE CarePlan_Goal SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE goal_id = @cg_goal_id

		UPDATE CarePlan_Intervention SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE goal_id = @cg_goal_id
	END


	IF(@page_source = 'PTO' AND NOT COALESCE(@PTOType, '') = 'CarePlanOrder' )  
	BEGIN  
		UPDATE CarePlan_Goal SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE (goal_group_id = @cg_goal_group_id  AND (
				(page_source = 'PTO' AND pto_id = @pto_id)
				OR
				(page_source = 'OASIS' AND oasis_id = @oasis_id)
				OR
				(page_source = 'POC' AND poc_id = @poc_id)
			)) OR goal_id = @cg_goal_id  
     
		UPDATE CarePlan_Intervention SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE goal_id IN(SELECT _cg.goal_id FROM CarePlan_Goal _cg WHERE _cg.goal_group_id = @cg_goal_group_id  AND (
				(_cg.page_source = 'PTO' AND _cg.pto_id = @pto_id)
				OR
				(_cg.page_source = 'OASIS' AND _cg.oasis_id = @oasis_id)
				OR
				(_cg.page_source = 'POC' AND _cg.poc_id = @poc_id)
			))  
     
	END  
  
	IF(@page_source = 'OASIS')  
	BEGIN  
		UPDATE CarePlan_Goal SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE goal_group_id = @cg_goal_group_id AND (
				(page_source = 'OASIS' AND oasis_id = @oasis_id)
				OR
				(page_source = 'POC' AND poc_id = @poc_id)
			)  
     
		UPDATE CarePlan_Intervention SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE goal_id IN(SELECT goal_id FROM CarePlan_Goal WHERE goal_group_id = @cg_goal_group_id 
		AND (
				(page_source = 'OASIS' AND oasis_id = @oasis_id)
				OR
				(page_source = 'POC' AND poc_id = @poc_id)
			))  
	END  
  
  IF(@page_source = 'POC')  
   BEGIN    
     
   UPDATE CarePlan_Goal SET  
    is_deleted = 1  
    ,updated_date = GETDATE()  
    ,updated_by = @user_id  
    WHERE goal_id = @cg_goal_id AND page_source IN('POC')  
     
     UPDATE CarePlan_Intervention SET  
     is_deleted = 1  
     ,updated_date = GETDATE()  
     ,updated_by = @user_id  
     WHERE goal_id IN(SELECT goal_id FROM CarePlan_Goal WHERE goal_id = @cg_goal_id AND page_source IN('POC'))  
  END
 END
 
   --BEGIN Mark A. 05/13/2024 Enhancement
IF @cg_Action = 'View'
BEGIN

	IF(@page_source = 'POC')
	BEGIN

	DECLARE D_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates
	OPEN D_Document_Cursor
	FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @d_doc_date >= @poc_date AND ((@d_doc_type = 'POC' AND @d_doc_key != @poc_id) or (@d_doc_type != 'POC'))
		BEGIN
		
			SET @poc_replicate_problem_group_id = NULL
			SELECT TOP 1 @poc_replicate_problem_group_id = problem_group_id FROM @ProblemTempTable WHERE problem_id = @cg_problem_id
			
			SET @poc_replicate_new_problem_id = NULL
			SELECT TOP 1 @poc_replicate_new_problem_id = problem_id FROM CarePlan_Problem WHERE COALESCE(is_deleted, 0) = 0 AND problem_group_id = @poc_replicate_problem_group_id AND (( page_source = 'PTO' AND @d_doc_type = 'PTO' AND pto_id = @d_doc_key ) OR ( page_source = 'OASIS' AND @d_doc_type = 'OASIS' AND oasis_id = @d_doc_key ) OR ( page_source = 'POC' AND @d_doc_type = 'POC' AND poc_id = @d_doc_key ) OR ( page_source = 'TCN' AND @d_doc_type = 'TCN' AND tcn_id = @d_doc_key ) OR ( page_source = 'VisitPlan-TCN' AND @d_doc_type = 'VisitPlan-TCN' AND cg_note_id = @d_doc_key )) 
			
			IF COALESCE(@poc_replicate_new_problem_id, 0) <> 0
			BEGIN

				INSERT INTO CarePlan_Goal  
				(
				caregoal_template_id,
				problem_id,
				goal_desc,
				goal_status,
				goal_source,
				goal_group_id,
				page_source,
				target_date,
				goal_setfor,
				resolution_date,
				comment,
				m0020_pat_id,
				patient_intake_id,
				episode_id,
				pto_id,
				oasis_id,
				poc_id,
				tcn_id,
				created_date,
				created_by,
				updated_date,
				updated_by,
				agency_id,
				cg_note_id
				)  

				SELECT
				@cg_caregoal_template_id,
				@poc_replicate_new_problem_id,
				@cg_goal_desc,
				@cg_goal_status,
				@cg_goal_source,
				@cg_goal_group_id,
				@d_doc_type,
				@cg_target_date,
				@cg_goal_setfor,
				@cg_resolution_date,
				@cg_comment,
				@patient_id,
				@intake_id,
				@episode_id,
				CASE WHEN @d_doc_type = 'PTO' THEN @d_doc_key ELSE -1 END,
				CASE WHEN @d_doc_type = 'OASIS' THEN @d_doc_key ELSE -1 END,
				CASE WHEN @d_doc_type = 'POC' THEN @d_doc_key ELSE -1 END,
				CASE WHEN @d_doc_type = 'TCN' THEN @d_doc_key ELSE -1 END,
				GETDATE(),
				'pocupdate',
				GETDATE(),
				'pocupdate',
				@agencyId,
				CASE WHEN @d_doc_type = 'VisitPlan-TCN' THEN @d_doc_key ELSE -1 END

			
			END



		END

		FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
	END
	CLOSE D_Document_Cursor
	DEALLOCATE D_Document_Cursor

 END


   --Start Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024

	IF @page_source IN ('VisitPlan-TCN','VisitPlan-PTO') AND (COALESCE(@tcn_id,0) NOT IN (-1,0) OR COALESCE(@pto_id,0) NOT IN (-1,0))
	BEGIN
		INSERT INTO CarePlan_Goal(
			caregoal_template_id,  
			problem_id,  
			goal_desc,  
			goal_status,  
			goal_source,  
			goal_group_id,  
			page_source,  
			target_date,  
			goal_setfor,  
			resolution_date,  
			comment,  
			m0020_pat_id,  
			patient_intake_id,  
			episode_id,  
			pto_id,  
			oasis_id,  
			poc_id,  
			tcn_id,  
			created_date,  
			created_by,  
			updated_date,  
			updated_by,  
			agency_id,
			cg_note_id
		)  
		
		SELECT
			@cg_caregoal_template_id,  
			cgcr.problem_id_db_identity,  
			@cg_goal_desc,  
			@cg_goal_status,  
			@cg_goal_source,   
			@cg_goal_group_id,  
			CASE WHEN @page_source = 'VisitPlan-TCN' THEN 'TCN' ELSE 'PTO' END,  
			@cg_target_date,  
			@cg_goal_setfor,  
			@cg_resolution_date,  
			@cg_comment,  
			@patient_id,  
			@intake_id,  
			@episode_id,  
			@pto_id,  
			@oasis_id,  
			@poc_id,  
			@tcn_id,  
			GETDATE(),  
			@user_id,  
			GETDATE(),  
			@user_id,  
			@agencyId,
			-1
		FROM
			@CareGoalCopyRefs cgcr

		WHERE cgcr.from_goal_id = @cg_goal_id

		SET @new_caregoal_id = SCOPE_IDENTITY();

		UPDATE @CareGoalCopyRefs SET db_identity = @new_caregoal_id WHERE from_goal_id = @cg_goal_id

		UPDATE icr SET icr.goal_id_db_identity = @new_caregoal_id FROM @InterventionCopyRefs icr WHERE icr.from_goal_id = @cg_goal_id

	END

  --End Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024


  
 END




 --END Mark A. 05/13/2024
  
 FETCH NEXT FROM CareGoalCursor     
 INTO    
  @cg_Action  
 ,@cg_goal_id   
 ,@cg_caregoal_template_id   
 ,@cg_problem_id   
 ,@cg_goal_desc   
 ,@cg_goal_status   
 ,@cg_goal_source   
 ,@cg_goal_group_id   
 ,@cg_page_source   
 ,@cg_target_date  
 ,@cg_goal_setfor  
 ,@cg_resolution_date  
 ,@cg_comment   
 ,@cg_episode_id   
 ,@cg_pto_id   
 ,@cg_oasis_id   
 ,@cg_poc_id
 ,@cg_add_option
 ,@cg_edit_option
  
 END  
  
 CLOSE CareGoalCursor;    
 DEALLOCATE CareGoalCursor;    
 --Care Goal Process End-------------------------------------  
   
 --Intervention Process Start----------------------------------  
 DECLARE InterventionCursor CURSOR FOR  
 SELECT   
 [Action],  
 intervention_id,  
 intervention_template_id,  
 goal_id,  
 intervention_desc,  
 intervention_status,  
 intervention_source,  
 intervention_group_id,  
 goal_outcome,   
 initiated_by,   
 initiated_date,   
 resolved_by,   
 resolved_date,   
 page_source,  
 episode_id,  
 pto_id,  
 oasis_id,  
 poc_id,
 add_option,
 edit_option
 FROM @InterventionTempTable  
  
 OPEN InterventionCursor  
  
 FETCH NEXT FROM InterventionCursor  
 INTO    
 @in_Action,  
 @in_intervention_id,  
 @in_intervention_template_id,  
 @in_goal_id,  
 @in_intervention_desc,  
 @in_intervention_status,  
 @in_intervention_source,  
 @in_intervention_group_id,  
 @in_goal_outcome,   
 @in_initiated_by,   
 @in_initiated_date,   
 @in_resolved_by,   
 @in_resolved_date,   
 @in_page_source,  
 @in_episode_id,  
 @in_pto_id,  
 @in_oasis_id,  
 @in_poc_id,
 @in_add_option,
 @in_edit_option
  
 WHILE @@FETCH_STATUS = 0    
 BEGIN   
  
 IF @in_Action = 'Add' OR @in_Action = 'AddFromLateAdmissionOrder' OR @in_Action = 'AddFromProfile' OR @in_Action = 'AddFromProfileTCN' OR @in_Action = 'AddFromVisitNote'  
 BEGIN  
  
  DECLARE @new_intervention_id BIGINT;  
  
  SET @page_source = CASE WHEN @in_Action = 'AddFromLateAdmissionOrder' OR @in_Action = 'AddFromProfile' THEN 'PTO' WHEN @pbm_Action = 'AddFromProfileTCN' THEN 'TCN' ELSE @page_source END
  

	DECLARE @in_existing_intervention_group_id BIGINT, @in_existing_intervention_source VARCHAR(100), @in_addtoall_source_id BIGINT
	SET @in_existing_intervention_group_id = NULL
	SET @in_existing_intervention_source = NULL
	SET @in_addtoall_source_id = NULL
	SELECT TOP 1 @in_existing_intervention_group_id  = ci.intervention_group_id, @in_existing_intervention_source = intervention_source FROM @ExistingInterventionTempTable ci JOIN @ExistingTempGoal cg ON cg.goal_id = ci.goal_id WHERE ci.intervention_template_id = @in_intervention_template_id AND ci.intervention_group_id NOT IN (SELECT _ci.intervention_group_id FROM @ExistingInterventionTempTable _ci WHERE _ci.intervention_group_id = ci.intervention_group_id AND ISNULL(_ci.goal_outcome,0) = 1) AND cg.caregoal_template_id = (SELECT _cg.caregoal_template_id FROM CarePlan_Goal _cg WHERE COALESCE(_cg.is_deleted,0) = 0 AND _cg.goal_id = @in_goal_id) AND cg.goal_group_id = (SELECT _cg.goal_group_id FROM CarePlan_Goal _cg WHERE COALESCE(is_deleted,0) = 0 AND _cg.goal_id = @in_goal_id)


    
  INSERT INTO CarePlan_Intervention  
  (  
  intervention_template_id  
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
  ,m0020_pat_id  
  ,patient_intake_id  
  ,episode_id  
  ,pto_id  
  ,oasis_id  
  ,poc_id  
  ,tcn_id  
  ,created_date  
  ,created_by  
  ,updated_date  
  ,updated_by  
  ,agency_id
  ,cg_note_id
  )  
  VALUES(  
   @in_intervention_template_id  
  ,@in_goal_id  
  ,@in_intervention_desc  
  ,@in_intervention_status  
  ,CASE WHEN COALESCE(@in_existing_intervention_source, '') <> '' AND @page_source <> 'POC' THEN @in_existing_intervention_source ELSE  @in_intervention_source END   
  ,CASE WHEN COALESCE(@in_existing_intervention_group_id, 0) <> 0 AND @page_source <> 'POC' THEN @in_existing_intervention_group_id ELSE @in_intervention_group_id END  
  ,@in_goal_outcome   
  ,@in_initiated_by   
  ,@in_initiated_date   
  ,@in_resolved_by   
  ,@in_resolved_date   
  ,CASE WHEN @page_source = 'VisitPlan-PTO' THEN 'VisitPlan-TCN' ELSE @page_source END  
  ,@patient_id  
  ,@intake_id  
  ,@episode_id  
  ,CASE WHEN @page_source = 'VisitPlan-PTO' THEN -1 ELSE @pto_id END  
  ,@oasis_id  
  ,@poc_id  
  ,CASE WHEN @page_source = 'VisitPlan-TCN' THEN -1 ELSE @tcn_id END  
  ,GETDATE()  
  ,@user_id  
  ,GETDATE()  
  ,@user_id  
  ,@agencyId
  ,@cg_note_id)  
  
  SET @new_intervention_id = SCOPE_IDENTITY();
  SET @in_addtoall_source_id = @new_intervention_id;  
  
  UPDATE @InterventionCommentTempTable 
  SET intervention_id = CASE WHEN (@in_Action = 'ADD' OR (@in_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') NOT IN ('CarePlanOrder', 'ResumptionOfCare') )) THEN (CASE WHEN COALESCE(@in_existing_intervention_group_id, 0) <> 0 THEN @in_existing_intervention_group_id ELSE @new_intervention_id END)  ELSE @in_intervention_group_id END 
  WHERE intervention_id = @in_intervention_id AND ([Action] = 'Add' OR @in_Action = 'AddFromProfile' OR @in_Action = 'AddFromProfileTCN' OR @in_Action = 'AddFromVisitNote')
  

      --BEGIN Mark A. 05/13/2024 Enhancement
  IF(@page_source = 'POC' AND @in_Action = 'Add')
  BEGIN

		DECLARE @poc_replicate_goal_group_id BIGINT, @poc_replicate_new_goal_id BIGINT, @poc_replicate_caregoal_template_id BIGINT;
		SELECT @poc_replicate_goal_group_id = NULL, @poc_replicate_caregoal_template_id = NULL


		SELECT TOP 1 @poc_replicate_caregoal_template_id = caregoal_template_id, @poc_replicate_goal_group_id = goal_group_id FROM CarePlan_Goal WHERE goal_id = @in_goal_id

		DECLARE D_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates
		OPEN D_Document_Cursor
		FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
		WHILE @@FETCH_STATUS = 0
		BEGIN

			IF @d_doc_date >= @poc_date AND ((@d_doc_type = 'POC' AND @d_doc_key != @poc_id) or (@d_doc_type != 'POC'))
			BEGIN
	

		
				SET @poc_replicate_new_goal_id = NULL
				SELECT TOP 1 @poc_replicate_new_goal_id = goal_id FROM CarePlan_Goal WHERE COALESCE(is_deleted, 0) = 0 AND caregoal_template_id = @poc_replicate_caregoal_template_id AND goal_group_id = @poc_replicate_goal_group_id AND (( page_source = 'PTO' AND @d_doc_type = 'PTO' AND pto_id = @d_doc_key ) OR ( page_source = 'OASIS' AND @d_doc_type = 'OASIS' AND oasis_id = @d_doc_key ) OR ( page_source = 'POC' AND @d_doc_type = 'POC' AND poc_id = @d_doc_key ) OR ( page_source = 'TCN' AND @d_doc_type = 'TCN' AND tcn_id = @d_doc_key ) OR ( page_source = 'VisitPlan-TCN' AND @d_doc_type = 'VisitPlan-TCN' AND cg_note_id = @d_doc_key )) 
		
				IF COALESCE(@poc_replicate_new_goal_id, 0) <> 0
				BEGIN
					INSERT INTO CarePlan_Intervention(intervention_template_id,goal_id,intervention_desc,intervention_status ,intervention_source,intervention_group_id,goal_outcome,initiated_by,initiated_date,resolved_by,resolved_date,page_source,m0020_pat_id,patient_intake_id,episode_id,pto_id,oasis_id,poc_id,tcn_id,created_date,created_by,updated_date,updated_by,agency_id,cg_note_id) SELECT @in_intervention_template_id,@poc_replicate_new_goal_id,@in_intervention_desc,@in_intervention_status ,@page_source,@new_intervention_id,@in_goal_outcome,@in_initiated_by,@in_initiated_date,@in_resolved_by,@in_resolved_date,@d_doc_type,@patient_id,@intake_id,@episode_id,CASE WHEN @d_doc_type = 'PTO' THEN @d_doc_key ELSE -1 END,CASE WHEN @d_doc_type = 'OASIS' THEN @d_doc_key ELSE -1 END,CASE WHEN @d_doc_type = 'POC' THEN @d_doc_key ELSE -1 END,CASE WHEN @d_doc_type = 'TCN' THEN @d_doc_key ELSE -1 END,GETDATE(),'pocupdate',GETDATE(),'pocupdate',@agencyId,CASE WHEN @d_doc_type = 'VisitPlan-TCN' THEN @d_doc_key ELSE -1 END	
				END

			END

			FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
		END
		CLOSE D_Document_Cursor
		DEALLOCATE D_Document_Cursor

		UPDATE CarePlan_Intervention_Comment SET intervention_id = @new_intervention_id WHERE intervention_id = @in_existing_intervention_group_id
		UPDATE @InterventionCommentTempTable SET intervention_id = @new_intervention_id WHERE intervention_id = @in_existing_intervention_group_id

 END



  --END Mark A. 05/13/2024



  
   IF(NOT @in_Action = 'AddFromLateAdmissionOrder')  
   BEGIN  
  
    IF(@in_Action = 'ADD' OR (@in_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') NOT IN ('CarePlanOrder', 'ResumptionOfCare') ))  
    BEGIN  
    UPDATE CarePlan_Intervention SET intervention_group_id  = CASE WHEN COALESCE(@in_existing_intervention_group_id, 0) <> 0 AND @page_source <> 'POC' THEN @in_existing_intervention_group_id ELSE @new_intervention_id END WHERE intervention_id = @new_intervention_id  
    END
	
	IF(@page_source = 'PTO' AND @in_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') = 'Recertification')
	BEGIN
		UPDATE CarePlan_Intervention SET intervention_source = 'PTO' WHERE intervention_id = @new_intervention_id
	END
  
    IF(NOT COALESCE(@PTOType, '') = 'CarePlanOrder' AND NOT COALESCE(@in_Action,'') = 'AddFromVisitNote')  
    BEGIN  
      
    DECLARE @in_goal_group_id AS BIGINT  
  
    SELECT @in_goal_group_id = goal_group_id FROM Careplan_Goal WHERE goal_id = @in_goal_id AND episode_id = @episode_id  
  
    IF(@page_source = 'TCN')  
     BEGIN  
      UPDATE CarePlan_Intervention SET  
     resolved_by  = @in_resolved_by  
     ,resolved_date  = @in_resolved_date  
     ,updated_date = DATEADD(ss,1,GETDATE())  
     ,updated_by = @user_id  
     WHERE intervention_group_id = @in_intervention_group_id AND page_source = 'TCN'  
     AND tcn_id IN(SELECT tcn_id FROM @ToBeUpdatedTCNList)  
     END  
  
     declare @oasis_gid int;  
     SELECT @oasis_gid = goal_id FROM CarePlan_Goal WHERE goal_group_id = @in_goal_group_id AND page_source = 'OASIS' AND oasis_id = @oasis_id AND COALESCE(is_deleted,0) = 0;  
     IF(@page_source = 'PTO' and @oasis_gid is not null)  
     BEGIN  
     --OASIS  
      INSERT INTO CarePlan_Intervention  
     (  
     intervention_template_id  
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
     ,m0020_pat_id  
     ,patient_intake_id  
     ,episode_id  
     ,pto_id  
     ,oasis_id  
     ,poc_id  
     ,created_date  
     ,created_by  
     ,updated_date  
     ,updated_by  
     ,agency_id)  
     VALUES(  
      @in_intervention_template_id  
     ,@oasis_gid  
     ,@in_intervention_desc  
     ,@in_intervention_status  
     ,CASE WHEN @in_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') = 'ResumptionOfCare' THEN @in_intervention_source ELSE (CASE WHEN COALESCE(@in_existing_intervention_source, '') <> '' THEN @in_existing_intervention_source ELSE  @page_source END) END --@in_intervention_source  
     ,CASE WHEN COALESCE(@in_existing_intervention_group_id, 0) <> 0 THEN @in_existing_intervention_group_id ELSE @new_intervention_id END   
     ,@in_goal_outcome   
     ,@in_initiated_by   
     ,@in_initiated_date   
     ,@in_resolved_by   
     ,@in_resolved_date   
     ,'OASIS'  
     ,@patient_id  
     ,@intake_id  
     ,@episode_id  
     ,@pto_id  
     ,@oasis_id  
     ,@poc_id  
     ,GETDATE()  
     ,@user_id  
     ,GETDATE()  
     ,@user_id  
     ,@agencyId)  
     END  
  
     declare @poc_gid int;  
     SELECT @poc_gid = goal_id FROM CarePlan_Goal WHERE goal_group_id = @in_goal_group_id AND page_source = 'POC' AND poc_id = @poc_id AND COALESCE(is_deleted,0) = 0;  
  
     IF(@page_source <> 'POC' AND @page_source <> 'TCN' and @poc_gid is not null AND @poc_id <> -1)  
     BEGIN  
    
      --POC  
      INSERT INTO CarePlan_Intervention  
     (  
     intervention_template_id  
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
     ,m0020_pat_id  
     ,patient_intake_id  
     ,episode_id  
     ,pto_id  
     ,oasis_id  
     ,poc_id  
     ,created_date  
     ,created_by  
     ,updated_date  
     ,updated_by  
     ,agency_id)  
     VALUES(  
      @in_intervention_template_id  
     ,@poc_gid  
     ,@in_intervention_desc  
     ,@in_intervention_status  
     ,CASE WHEN @page_source = 'PTO' AND @in_Action = 'AddFromProfile' AND COALESCE(@PTOType, '') = 'ResumptionOfCare' THEN @in_intervention_source ELSE (CASE WHEN COALESCE(@in_existing_intervention_source, '') <> '' THEN @in_existing_intervention_source ELSE  @page_source END) END  
     ,CASE WHEN COALESCE(@in_existing_intervention_group_id, 0) <> 0 THEN @in_existing_intervention_group_id ELSE @new_intervention_id END   
     ,@in_goal_outcome   
     ,@in_initiated_by   
     ,@in_initiated_date   
     ,@in_resolved_by   
     ,@in_resolved_date   
     ,'POC'  
     ,@patient_id  
     ,@intake_id  
     ,@episode_id  
     ,@pto_id  
     ,@oasis_id  
     ,@poc_id  
     ,GETDATE()  
     ,@user_id  
     ,GETDATE()  
     ,@user_id  
     ,@agencyId)  
    END  
   END  
  END  
  ELSE  
  BEGIN  
     
   UPDATE CarePlan_Intervention SET  
   intervention_status = @in_intervention_status  
   ,intervention_desc = @in_intervention_desc  
   ,goal_outcome  = @in_goal_outcome  
   ,initiated_by  = @in_initiated_by  
   ,initiated_date  = @in_initiated_date  
   ,resolved_by  = @in_resolved_by  
   ,resolved_date  = @in_resolved_date  
   ,updated_date = GETDATE()  
   ,updated_by = @user_id  
   --,pto_id = @pto_id  
   ,created_date = @current_pto_call_date  
   --,intervention_source = 'PTO'  
   WHERE intervention_group_id = @in_intervention_group_id AND intervention_source = 'OASIS'  
  END
  
  --Start Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024

	IF @page_source IN ('VisitPlan-TCN','VisitPlan-PTO') AND (COALESCE(@tcn_id,0) NOT IN (-1,0) OR COALESCE(@pto_id,0) NOT IN (-1,0))
	BEGIN

		INSERT INTO CarePlan_Intervention (  
			intervention_template_id,  
			goal_id,  
			intervention_desc,  
			intervention_status,  
			intervention_source,  
			intervention_group_id,  
			goal_outcome,   
			initiated_by,   
			initiated_date,   
			resolved_by,   
			resolved_date,   
			page_source,  
			m0020_pat_id,  
			patient_intake_id,  
			episode_id,  
			pto_id,  
			oasis_id,  
			poc_id,  
			tcn_id,  
			created_date,  
			created_by,  
			updated_date,  
			updated_by,  
			agency_id,
			cg_note_id
		)  
  
		SELECT
			@in_intervention_template_id,  
			icr.goal_id_db_identity,  
			@in_intervention_desc,  
			@in_intervention_status,  
			CASE WHEN COALESCE(@in_existing_intervention_source, '') <> '' THEN @in_existing_intervention_source ELSE  @in_intervention_source END,   
			CASE WHEN COALESCE(@in_existing_intervention_group_id, 0) <> 0 THEN @in_existing_intervention_group_id ELSE @new_intervention_id END,  
			@in_goal_outcome,  
			@in_initiated_by,   
			@in_initiated_date,   
			@in_resolved_by,   
			@in_resolved_date,   
			CASE WHEN @page_source = 'VisitPlan-TCN' THEN 'TCN' ELSE 'PTO' END,  
			@patient_id,  
			@intake_id,  
			@episode_id,  
			@pto_id,  
			@oasis_id,  
			@poc_id,  
			@tcn_id,  
			GETDATE(),  
			@user_id,  
			GETDATE(),  
			@user_id,  
			@agencyId,
			-1
		
		FROM

		@InterventionCopyRefs icr

		WHERE 

		icr.from_intervention_id = @in_intervention_id
  
	END

  --End Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024



	--Start Mark A. 10/09/2024 Check if the add option is 'Add to all referencing documents', 'Add and replace in all referencing document' or 'Add to this document only'

	IF @in_Action = 'Add' AND @page_source <> 'POC' AND ISNULL(@in_goal_outcome,0) <> 1
	BEGIN
		DECLARE @existing_intervention_group_id BIGINT, @existing_intervention_id BIGINT, @existing_intervention_goal_id BIGINT


		IF @page_source = 'PTO'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM PTO WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND pto_id = @pto_id
			SELECT @current_document_key = @pto_id
		END


		IF @page_source = 'OASIS'
		BEGIN
			SELECT  @current_document_date = CASE WHEN o.m0100_assmt_reason = '01' THEN CAST(o.m0030_start_care_dt AS DATE) WHEN o.m0100_assmt_reason = '03' THEN CAST(o.m0032_roc_dt AS DATE) ELSE CAST(pto.call_date AS DATE) END FROM Oasis o JOIN PTO pto ON pto.pto_id = o.pto_id   WHERE o.episode_id = @episode_id AND COALESCE(o.isdeleted,0) = 0 AND o.m0100_assmt_reason IN('01','03','04') AND o.OasisID = @oasis_id
			SELECT @current_document_key = @oasis_id
		END


		IF @page_source = 'TCN'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM TelCommunicationNote WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND tcn_id = @tcn_id
			SELECT @current_document_key = @tcn_id
		END


		IF @page_source  IN ('VisitPlan-TCN','VisitPlan-PTO')
		BEGIN
			SELECT @current_document_date = COALESCE(v.Actual_Visit_Date, vp.Scheduled_Visit_Date) FROM CaregiverNote cgn LEFT JOIN Visits v ON v.Visit_Id = cgn.visit_id LEFT JOIN VisitPlan vp ON vp.visit_plan_id = cgn.visit_plan_id  WHERE COALESCE(cgn.is_deleted,0) = 0 AND cgn.cg_note_id = @cg_note_id
			SELECT @current_document_key = @cg_note_id
		END


		DECLARE U_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates 
		WHERE
		(
			(@page_source = doc_type AND @current_document_key != [key])
			OR
			(@page_source != doc_type AND @current_document_key = [key])
			OR
			(@page_source != doc_type AND @current_document_key != [key])
		)

		AND doc_date >= @current_document_date

		OPEN U_Document_Cursor
		FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key
		WHILE @@FETCH_STATUS = 0
		BEGIN

			SELECT @existing_intervention_group_id = NULL, @existing_intervention_id = NULL, @existing_intervention_goal_id = NULL

			SELECT TOP 1 @existing_intervention_group_id = i.intervention_group_id, @existing_intervention_id = i.intervention_id FROM dbo.Func_GetAllCarePlanInterventionByEpisodeId(@episode_id, CASE WHEN @u_doc_type = 'PTO' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'OASIS' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'POC' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'TCN' THEN @u_key ELSE 0 END, @u_doc_type, CASE WHEN @u_doc_type = 'VisitPlan-TCN' THEN @u_key ELSE -1 END) i JOIN CarePlan_Goal cg ON i.goal_id = cg.goal_id  WHERE i.intervention_template_id = @in_intervention_template_id AND ISNULL(i.goal_outcome,0) <> 1  AND cg.goal_group_id = (SELECT _cg.goal_group_id FROM CarePlan_Goal _cg WHERE _cg.episode_id = @episode_id AND COALESCE(_cg.is_deleted,0) = 0 AND _cg.goal_id = @in_goal_id)
			
			SELECT @existing_intervention_goal_id = goal_id FROM dbo.Func_GetAllCarePlanCareGoalByEpisodeId(@episode_id, CASE WHEN @u_doc_type = 'PTO' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'OASIS' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'POC' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'TCN' THEN @u_key ELSE 0 END, @u_doc_type, CASE WHEN @u_doc_type = 'VisitPlan-TCN' THEN @u_key ELSE -1 END)  WHERE goal_group_id = (SELECT cg.goal_group_id FROM CarePlan_Goal cg WHERE cg.episode_id = @episode_id AND COALESCE(cg.is_deleted,0) = 0 AND cg.goal_id = @in_goal_id)
			IF COALESCE(@existing_intervention_goal_id,0) <> 0 AND (( @in_add_option = 1 AND COALESCE(@existing_intervention_group_id,0) = 0 ) OR ( @in_add_option = 2 AND COALESCE(@existing_intervention_group_id,0) = 0)) 
			BEGIN

				INSERT INTO CarePlan_Intervention(intervention_template_id,goal_id,intervention_desc,intervention_status,intervention_source,intervention_group_id,goal_outcome,initiated_by,initiated_date,resolved_by,resolved_date,page_source,m0020_pat_id,patient_intake_id,episode_id,pto_id,oasis_id,poc_id,tcn_id,created_date,created_by,updated_date ,updated_by,agency_id ,cg_note_id)
				SELECT TOP 1 @in_intervention_template_id, @existing_intervention_goal_id, @in_intervention_desc, @in_intervention_status, intervention_source, intervention_group_id, @in_goal_outcome,@in_initiated_by,@in_initiated_date,@in_resolved_by,@in_resolved_date,@u_doc_type, i.m0020_pat_id,i.patient_intake_id,i.episode_id, CASE WHEN @u_doc_type = 'PTO' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'OASIS' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'POC' THEN @u_key ELSE -1 END, CASE WHEN @u_doc_type = 'TCN' THEN @u_key ELSE -1 END, GETDATE(), 'addtoall', GETDATE() ,'addtoall', i.agency_id ,CASE WHEN @u_doc_type = 'VisitPlan-TCN' THEN @u_key ELSE -1 END FROM CarePlan_Intervention i JOIN CarePlan_Goal cg ON cg.goal_id = i.goal_id WHERE intervention_id = @in_addtoall_source_id

			END

			IF COALESCE(@existing_intervention_goal_id,0) <> 0 AND @in_add_option = 2 AND COALESCE(@existing_intervention_id,0) <> 0 AND @in_existing_intervention_group_id = @existing_intervention_group_id

			BEGIN
				UPDATE CarePlan_Intervention SET intervention_desc = @in_intervention_desc, intervention_status = @in_intervention_status, intervention_source = @in_intervention_source, goal_outcome = @in_goal_outcome, initiated_by = @in_initiated_by, initiated_date = @in_initiated_date, resolved_by = @in_resolved_by, resolved_date = @in_resolved_date, updated_date = GETDATE() ,updated_by = 'updatetoall' WHERE intervention_id = @existing_intervention_id
			END

			FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key

		END

		CLOSE U_Document_Cursor
		DEALLOCATE U_Document_Cursor
	END


	--Update source and group id if 'Add and Replace'
	IF (@in_add_option = 2 AND COALESCE(@in_existing_intervention_group_id,0) <> 0)
	BEGIN
		UPDATE CarePlan_Intervention SET intervention_source = @in_intervention_source, intervention_group_id = @new_intervention_id WHERE intervention_group_id = @in_existing_intervention_group_id
		UPDATE CarePlan_Intervention_Comment SET intervention_id = @new_intervention_id WHERE intervention_id = @in_existing_intervention_group_id
		UPDATE @InterventionCommentTempTable SET intervention_id = @new_intervention_id WHERE intervention_id = @in_existing_intervention_group_id
	END
	




	--End Mark A. 10/09/2024 Check if the add option is 'Add to all referencing documents', 'Add and replace in all referencing document' or 'Add to this document only'










 END  
  
 IF @in_Action = 'Edit'  
 BEGIN  
    
  UPDATE CarePlan_Intervention SET  
  intervention_status = @in_intervention_status  
  ,intervention_desc = @in_intervention_desc  
  ,goal_outcome  = @in_goal_outcome  
  ,initiated_by  = @in_initiated_by  
  ,initiated_date  = @in_initiated_date  
  ,resolved_by  = @in_resolved_by  
  ,resolved_date  = @in_resolved_date  
  ,updated_date = GETDATE()  
  ,updated_by = @user_id  
  WHERE intervention_id = @in_intervention_id
  
  --BEGIN Mark A. 05/13/2024 Enhancement
	IF(@page_source = 'POC')
	BEGIN

		DECLARE D_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates
		OPEN D_Document_Cursor
		FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
		WHILE @@FETCH_STATUS = 0
		BEGIN

			IF @d_doc_date >= @poc_date AND ((@d_doc_type = 'POC' AND @d_doc_key != @poc_id) or (@d_doc_type != 'POC'))
			BEGIN
	
				SET @poc_replicate_goal_group_id = NULL
				SELECT TOP 1 @poc_replicate_goal_group_id = goal_group_id FROM CarePlan_Goal WHERE goal_id = @in_goal_id
		
				SET @poc_replicate_new_goal_id = NULL
				SELECT TOP 1 @poc_replicate_new_goal_id = goal_id FROM CarePlan_Goal WHERE COALESCE(is_deleted, 0) = 0 AND goal_group_id = @poc_replicate_goal_group_id AND (( page_source = 'PTO' AND @d_doc_type = 'PTO' AND pto_id = @d_doc_key ) OR ( page_source = 'OASIS' AND @d_doc_type = 'OASIS' AND oasis_id = @d_doc_key ) OR ( page_source = 'POC' AND @d_doc_type = 'POC' AND poc_id = @d_doc_key ) OR ( page_source = 'TCN' AND @d_doc_type = 'TCN' AND tcn_id = @d_doc_key ) OR ( page_source = 'VisitPlan-TCN' AND @d_doc_type = 'VisitPlan-TCN' AND cg_note_id = @d_doc_key )) 
		
				IF COALESCE(@poc_replicate_new_goal_id, 0) <> 0
				BEGIN
					INSERT INTO CarePlan_Intervention(intervention_template_id,goal_id,intervention_desc,intervention_status ,intervention_source,intervention_group_id,goal_outcome,initiated_by,initiated_date,resolved_by,resolved_date,page_source,m0020_pat_id,patient_intake_id,episode_id,pto_id,oasis_id,poc_id,tcn_id,created_date,created_by,updated_date,updated_by,agency_id,cg_note_id) SELECT @in_intervention_template_id,@poc_replicate_new_goal_id,@in_intervention_desc,@in_intervention_status ,@in_intervention_source,@in_intervention_group_id,@in_goal_outcome,@in_initiated_by,@in_initiated_date,@in_resolved_by,@in_resolved_date,@d_doc_type,@patient_id,@intake_id,@episode_id,CASE WHEN @d_doc_type = 'PTO' THEN @d_doc_key ELSE -1 END,CASE WHEN @d_doc_type = 'OASIS' THEN @d_doc_key ELSE -1 END,CASE WHEN @d_doc_type = 'POC' THEN @d_doc_key ELSE -1 END,CASE WHEN @d_doc_type = 'TCN' THEN @d_doc_key ELSE -1 END,GETDATE(),'pocupdate',GETDATE(),'pocupdate',@agencyId,CASE WHEN @d_doc_type = 'VisitPlan-TCN' THEN @d_doc_key ELSE -1 END	
				END

			END

			FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
		END
		CLOSE D_Document_Cursor
		DEALLOCATE D_Document_Cursor

	END


   --Start Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024

	IF @page_source IN ('VisitPlan-TCN','VisitPlan-PTO') AND (COALESCE(@tcn_id,0) NOT IN (-1,0) OR COALESCE(@pto_id,0) NOT IN (-1,0))
	BEGIN

		INSERT INTO CarePlan_Intervention (  
			intervention_template_id,  
			goal_id,  
			intervention_desc,  
			intervention_status,  
			intervention_source,  
			intervention_group_id,  
			goal_outcome,   
			initiated_by,   
			initiated_date,   
			resolved_by,   
			resolved_date,   
			page_source,  
			m0020_pat_id,  
			patient_intake_id,  
			episode_id,  
			pto_id,  
			oasis_id,  
			poc_id,  
			tcn_id,  
			created_date,  
			created_by,  
			updated_date,  
			updated_by,  
			agency_id,
			cg_note_id
		)  
  
		SELECT
			@in_intervention_template_id,  
			icr.goal_id_db_identity,  
			@in_intervention_desc,  
			@in_intervention_status,  
			@in_intervention_source,   
			@in_intervention_group_id,  
			@in_goal_outcome,  
			@in_initiated_by,   
			@in_initiated_date,   
			@in_resolved_by,   
			@in_resolved_date,   
			CASE WHEN @page_source = 'VisitPlan-TCN' THEN 'TCN' ELSE 'PTO' END,  
			@patient_id,  
			@intake_id,  
			@episode_id,  
			@pto_id,  
			@oasis_id,  
			@poc_id,  
			@tcn_id,  
			GETDATE(),  
			@user_id,  
			GETDATE(),  
			@user_id,  
			@agencyId,
			-1
		
		FROM

		@InterventionCopyRefs icr

		WHERE 

		icr.from_intervention_id = @in_intervention_id
  
	END

  --End Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024



  --END Mark A. 05/13/2024
  
  IF(NOT COALESCE(@PTOType, '') = 'CarePlanOrder')  
  BEGIN  
  
   IF(@page_source = 'TCN')  
   BEGIN  
    UPDATE CarePlan_Intervention SET  
   resolved_by  = @in_resolved_by  
   ,resolved_date  = @in_resolved_date  
   ,updated_date = DATEADD(ss,1,GETDATE())  
   ,updated_by = @user_id  
   WHERE intervention_group_id = @in_intervention_group_id AND page_source = 'TCN'  
   AND tcn_id IN(SELECT tcn_id FROM @ToBeUpdatedTCNList)  
   END  
  
   IF(@page_source = 'PTO')  
   BEGIN  
   --OASIS  
    UPDATE CarePlan_Intervention SET  
   intervention_status = @in_intervention_status  
   ,intervention_desc = @in_intervention_desc  
   ,goal_outcome  = @in_goal_outcome  
   ,initiated_by  = @in_initiated_by  
   ,initiated_date  = @in_initiated_date  
   ,resolved_by  = @in_resolved_by  
   ,resolved_date  = @in_resolved_date  
   ,updated_date = GETDATE()  
   ,updated_by = @user_id  
   WHERE intervention_group_id = @in_intervention_group_id AND page_source = 'OASIS' AND oasis_id = @oasis_id  
  
   END  
  
   IF(@page_source <> 'POC' AND @page_source <> 'TCN' AND @page_source <> 'VisitPlan-TCN' AND @page_source <> 'VisitPlan-PTO')  
   BEGIN  
/*    IF(@page_source = 'OASIS')   
   BEGIN  
    SET @in_intervention_id = (SELECT intervention_group_id FROM CarePlan_Intervention WHERE intervention_id = @in_intervention_id AND page_source = 'OASIS')  
   END */ 
    --POC  
    UPDATE CarePlan_Intervention SET  
   intervention_status = @in_intervention_status  
   ,intervention_desc = @in_intervention_desc  
   ,goal_outcome  = @in_goal_outcome  
   ,initiated_by  = @in_initiated_by  
   ,initiated_date  = @in_initiated_date  
   ,resolved_by  = @in_resolved_by  
   ,resolved_date  = @in_resolved_date  
   ,updated_date = GETDATE()  
   ,updated_by = @user_id  
   WHERE intervention_group_id = @in_intervention_group_id AND page_source = 'POC' AND poc_id = @poc_id
  END  
  END 

	SET @compound_edit_option = 0
	SELECT TOP 1 @compound_edit_option = ptt.edit_option FROM @ProblemTempTable ptt JOIN @CareGoalTempTable cgtt ON cgtt.problem_id = ptt.problem_id WHERE cgtt.goal_id = @in_goal_id
	
	IF (@compound_edit_option = 1 OR ISNULL(@in_goal_outcome,0) = 1) AND ISNULL(@page_source,'') <> 'POC'
	BEGIN
	
		SELECT @current_document_date = NULL, @current_document_key = NULL, @existing_problem_group_id = NULL, @existing_problem_id = NULL
		
		IF @page_source = 'PTO'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM PTO WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND pto_id = @pto_id
			SELECT @current_document_key = @pto_id
		END
		
		IF @page_source = 'OASIS'
		BEGIN
			SELECT  @current_document_date = CASE WHEN o.m0100_assmt_reason = '01' THEN CAST(o.m0030_start_care_dt AS DATE) WHEN o.m0100_assmt_reason = '03' THEN CAST(o.m0032_roc_dt AS DATE) ELSE CAST(pto.call_date AS DATE) END FROM Oasis o JOIN PTO pto ON pto.pto_id = o.pto_id   WHERE o.episode_id = @episode_id AND COALESCE(o.isdeleted,0) = 0 AND o.m0100_assmt_reason IN('01','03','04') AND o.OasisID = @oasis_id
			SELECT @current_document_key = @oasis_id
		END
		
		
		IF @page_source = 'TCN'
		BEGIN
			SELECT @current_document_date = call_date +  CAST(call_time AS TIME) FROM TelCommunicationNote WHERE episode_id = @episode_id AND COALESCE(isDeleted,0) = 0 AND tcn_id = @tcn_id
			SELECT @current_document_key = @tcn_id
		END
		
		IF @page_source  IN ('VisitPlan-TCN','VisitPlan-PTO')
		BEGIN
			SELECT @current_document_date = COALESCE(v.Actual_Visit_Date, vp.Scheduled_Visit_Date) FROM CaregiverNote cgn LEFT JOIN Visits v ON v.Visit_Id = cgn.visit_id LEFT JOIN VisitPlan vp ON vp.visit_plan_id = cgn.visit_plan_id  WHERE COALESCE(cgn.is_deleted,0) = 0 AND cgn.cg_note_id = @cg_note_id
			SELECT @current_document_key = @cg_note_id
		END
		
		
		
		DECLARE U_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates 
		WHERE
		(
			(@page_source = doc_type AND @current_document_key != [key])
			OR
			(@page_source != doc_type AND @current_document_key = [key])
			OR
			(@page_source != doc_type AND @current_document_key != [key])
		)


		AND doc_date >= @current_document_date
		OPEN U_Document_Cursor
		FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
		
			UPDATE CarePlan_Intervention SET  
			intervention_status = @in_intervention_status,  
			intervention_desc = @in_intervention_desc,  
			goal_outcome  = @in_goal_outcome,  
			initiated_by  = @in_initiated_by,  
			initiated_date  = @in_initiated_date,  
			resolved_by  = @in_resolved_by,  
			resolved_date  = @in_resolved_date,  
			updated_date = GETDATE(),  
			updated_by = @user_id  
			WHERE intervention_group_id = @in_intervention_group_id
			AND (
				(@u_doc_type = 'PTO' AND pto_id = @u_key AND page_source = 'PTO')
				OR
				(@u_doc_type = 'POC' AND poc_id = @u_key AND page_source = 'POC')
				OR
				(@u_doc_type = 'OASIS' AND oasis_id = @u_key AND page_source = 'OASIS')
				OR
				(@u_doc_type = 'TCN' AND tcn_id = @u_key AND page_source = 'TCN')
				OR
				(@u_doc_type IN ('VisitPlan-TCN','VisitPlan-PTO') AND cg_note_id = @u_key AND page_source IN ('VisitPlan-TCN','VisitPlan-PTO'))

			)
			
		
			FETCH NEXT FROM U_Document_Cursor INTO @u_doc_date, @u_doc_type, @u_key
		END
		CLOSE U_Document_Cursor
		DEALLOCATE U_Document_Cursor
		
		
		
		
		
		
	END



  
 END  
  
	IF @in_Action = 'Delete'  
	BEGIN

		IF(@page_source IN ('VisitPlan-TCN', 'VisitPlan-PTO', 'TCN') OR (@page_source = 'PTO' AND @PTOType != 'AdmissionOrder'))
		BEGIN
			UPDATE CarePlan_Intervention SET  
			is_deleted = 1  
			,updated_date = GETDATE()  
			,updated_by = @user_id  
			WHERE intervention_id = @in_intervention_id
		END

    
		IF(@page_source = 'PTO' AND NOT COALESCE(@PTOType, '') = 'CarePlanOrder')  
		BEGIN  
  
			UPDATE CarePlan_Intervention SET  
			is_deleted = 1  
			,updated_date = GETDATE()  
			,updated_by = @user_id  
			WHERE (intervention_group_id = @in_intervention_group_id AND (
				(page_source = 'PTO' AND pto_id = @pto_id)
				OR
				(page_source = 'OASIS' AND oasis_id = @oasis_id)
				OR
				(page_source = 'POC' AND poc_id = @poc_id)
			)) OR intervention_id = @in_intervention_id  
     
		END  
  
		IF(@page_source = 'OASIS')  
		BEGIN  
  
		   UPDATE CarePlan_Intervention SET  
		   is_deleted = 1  
		   ,updated_date = GETDATE()  
		   ,updated_by = @user_id  
		   WHERE intervention_group_id = @in_intervention_group_id AND (
				(page_source = 'OASIS' AND oasis_id = @oasis_id)
				OR
				(page_source = 'POC' AND poc_id = @poc_id)
			)  
  
		END  
  
		IF(@page_source = 'POC')  
		BEGIN    
  
		UPDATE CarePlan_Intervention SET  
		is_deleted = 1  
		,updated_date = GETDATE()  
		,updated_by = @user_id  
		WHERE intervention_id = @in_intervention_id AND page_source IN('POC')  
		END 
  
 END
 
 --BEGIN MARK A. Enhancement 05/15/2024

 IF @in_Action = 'View'
 BEGIN
	IF(@page_source = 'POC')
	BEGIN

		DECLARE D_Document_Cursor CURSOR FOR SELECT * FROM @CarePlanDocumentsForUpdates
		OPEN D_Document_Cursor
		FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
		WHILE @@FETCH_STATUS = 0
		BEGIN

			IF @d_doc_date >= @poc_date AND ((@d_doc_type = 'POC' AND @d_doc_key != @poc_id) or (@d_doc_type != 'POC'))
			BEGIN
	
				SET @poc_replicate_goal_group_id = NULL
				SELECT TOP 1 @poc_replicate_goal_group_id = goal_group_id FROM CarePlan_Goal WHERE goal_id = @in_goal_id
		
				SET @poc_replicate_new_goal_id = NULL
				SELECT TOP 1 @poc_replicate_new_goal_id = goal_id FROM CarePlan_Goal WHERE COALESCE(is_deleted, 0) = 0 AND goal_group_id = @poc_replicate_goal_group_id AND (( page_source = 'PTO' AND @d_doc_type = 'PTO' AND pto_id = @d_doc_key ) OR ( page_source = 'OASIS' AND @d_doc_type = 'OASIS' AND oasis_id = @d_doc_key ) OR ( page_source = 'POC' AND @d_doc_type = 'POC' AND poc_id = @d_doc_key ) OR ( page_source = 'TCN' AND @d_doc_type = 'TCN' AND tcn_id = @d_doc_key ) OR ( page_source = 'VisitPlan-TCN' AND @d_doc_type = 'VisitPlan-TCN' AND cg_note_id = @d_doc_key )) 
		
				IF COALESCE(@poc_replicate_new_goal_id, 0) <> 0
				BEGIN
					INSERT INTO CarePlan_Intervention(intervention_template_id,goal_id,intervention_desc,intervention_status ,intervention_source,intervention_group_id,goal_outcome,initiated_by,initiated_date,resolved_by,resolved_date,page_source,m0020_pat_id,patient_intake_id,episode_id,pto_id,oasis_id,poc_id,tcn_id,created_date,created_by,updated_date,updated_by,agency_id,cg_note_id) SELECT @in_intervention_template_id,@poc_replicate_new_goal_id,@in_intervention_desc,@in_intervention_status ,@in_intervention_source,@in_intervention_group_id,@in_goal_outcome,@in_initiated_by,@in_initiated_date,@in_resolved_by,@in_resolved_date,@d_doc_type,@patient_id,@intake_id,@episode_id,CASE WHEN @d_doc_type = 'PTO' THEN @d_doc_key ELSE -1 END,CASE WHEN @d_doc_type = 'OASIS' THEN @d_doc_key ELSE -1 END,CASE WHEN @d_doc_type = 'POC' THEN @d_doc_key ELSE -1 END,CASE WHEN @d_doc_type = 'TCN' THEN @d_doc_key ELSE -1 END,GETDATE(),'pocupdate',GETDATE(),'pocupdate',@agencyId,CASE WHEN @d_doc_type = 'VisitPlan-TCN' THEN @d_doc_key ELSE -1 END	
				END

			END

			FETCH NEXT FROM D_Document_Cursor INTO @d_doc_date, @d_doc_type, @d_doc_key
		END
		CLOSE D_Document_Cursor
		DEALLOCATE D_Document_Cursor

	END

    --Start Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024

	IF @page_source IN ('VisitPlan-TCN','VisitPlan-PTO') AND (COALESCE(@tcn_id,0) NOT IN (-1,0) OR COALESCE(@pto_id,0) NOT IN (-1,0))
	BEGIN

		INSERT INTO CarePlan_Intervention (  
			intervention_template_id,  
			goal_id,  
			intervention_desc,  
			intervention_status,  
			intervention_source,  
			intervention_group_id,  
			goal_outcome,   
			initiated_by,   
			initiated_date,   
			resolved_by,   
			resolved_date,   
			page_source,  
			m0020_pat_id,  
			patient_intake_id,  
			episode_id,  
			pto_id,  
			oasis_id,  
			poc_id,  
			tcn_id,  
			created_date,  
			created_by,  
			updated_date,  
			updated_by,  
			agency_id,
			cg_note_id
		)  
  
		SELECT
			@in_intervention_template_id,  
			icr.goal_id_db_identity,  
			@in_intervention_desc,  
			@in_intervention_status,  
			@in_intervention_source,   
			@in_intervention_group_id,  
			@in_goal_outcome,  
			@in_initiated_by,   
			@in_initiated_date,   
			@in_resolved_by,   
			@in_resolved_date,   
			CASE WHEN @page_source = 'VisitPlan-TCN' THEN 'TCN' ELSE 'PTO' END,  
			@patient_id,  
			@intake_id,  
			@episode_id,  
			@pto_id,  
			@oasis_id,  
			@poc_id,  
			@tcn_id,  
			GETDATE(),  
			@user_id,  
			GETDATE(),  
			@user_id,  
			@agencyId,
			-1
		
		FROM

		@InterventionCopyRefs icr

		WHERE 

		icr.from_intervention_id = @in_intervention_id
  
	END

  --End Copy Data To TCN/PTO if save as comm.note/pto - Mark A. 05/17/2024


 END


 --END MARK A. Enhancement 05/15/2024


  
 FETCH NEXT FROM InterventionCursor     
 INTO     
 @in_Action,  
 @in_intervention_id,  
 @in_intervention_template_id,  
 @in_goal_id,  
 @in_intervention_desc,  
 @in_intervention_status,  
 @in_intervention_source,  
 @in_intervention_group_id,  
 @in_goal_outcome,   
 @in_initiated_by,   
 @in_initiated_date,   
 @in_resolved_by,   
 @in_resolved_date,   
 @in_page_source,  
 @in_episode_id,  
 @in_pto_id,  
 @in_oasis_id,  
 @in_poc_id,
 @in_add_option,
 @in_edit_option
  
 END  
  
 CLOSE InterventionCursor;    
 DEALLOCATE InterventionCursor;    
 --Intervention Process End-------------------------------------  
   
 --Intervention Comment Process Start----------------------------------  
 DECLARE InterventionCommentCursor CURSOR FOR  
 SELECT   
 [Action],  
 comment_id,  
 intervention_id,  
 comment,  
 comment_source,  
 parent_comment_id,  
 page_source,  
 episode_id,  
 pto_id,  
 oasis_id,  
 poc_id FROM @InterventionCommentTempTable  
  
 OPEN InterventionCommentCursor  
  
 FETCH NEXT FROM InterventionCommentCursor  
 INTO    
 @com_Action,  
 @com_comment_id,  
 @com_intervention_id,  
 @com_comment,  
 @com_comment_source,  
 @com_parent_comment_id,  
 @com_page_source,  
 @com_episode_id,  
 @com_pto_id,  
 @com_oasis_id,  
 @com_poc_id  
  
 WHILE @@FETCH_STATUS = 0    
 BEGIN   
  
 IF @com_Action = 'Add' OR @com_Action = 'AddFromLateAdmissionOrder' OR @com_Action = 'AddFromProfile' OR @com_Action = 'AddFromProfileTCN' OR @com_Action = 'AddFromVisitNote'  
 BEGIN  
  
  INSERT INTO CarePlan_Intervention_Comment  
  (  
  intervention_id  
  ,comment  
  ,comment_source  
  ,parent_comment_id  
  ,page_source  
  ,episode_id  
  ,pto_id  
  ,oasis_id  
  ,poc_id  
  ,created_date  
  ,created_by  
  ,updated_date  
  ,updated_by  
  ,agency_id,
  visit_date,
  cg_note_id
  )  
  VALUES(  
   @com_intervention_id  
  ,@com_comment  
  ,@com_comment_source  
  ,@com_parent_comment_id  
  ,CASE WHEN @com_Action = 'AddFromLateAdmissionOrder' OR @com_Action = 'AddFromProfile' THEN 'PTO' WHEN @com_Action = 'AddFromProfileTCN' THEN 'TCN' ELSE @com_page_source END  
  ,@episode_id  
  ,@pto_id  
  ,@oasis_id  
  ,@poc_id  
  ,GETDATE()  
  ,@user_id  
  ,GETDATE()  
  ,@user_id  
  ,@agencyId,
  @visit_date,
  @cg_note_id
  )  
  
 END  
  
 --IF @com_Action = 'Delete'  
 --BEGIN  
    
 -- IF(@page_source = 'PTO')  
 --  BEGIN  
  
 --  UPDATE CarePlan_Intervention_Comment SET  
 --  is_deleted = 1  
 --  ,updated_date = GETDATE()  
 --  ,updated_by = @user_id  
 --  WHERE parent_comment_id = @com_comment_id  
     
 --  END  
  
 --  IF(@page_source = 'OASIS')  
 --  BEGIN  
  
 --  SET @com_comment_id = (SELECT parent_comment_id FROM CarePlan_Intervention_Comment WHERE comment_id = @com_comment_id AND page_source = 'OASIS')  
  
 --  UPDATE CarePlan_Intervention_Comment SET  
 --  is_deleted = 1  
 --  ,updated_date = GETDATE()  
 --  ,updated_by = @user_id  
 --  WHERE parent_comment_id = @com_comment_id AND page_source IN('OASIS', 'POC')  
  
 -- END  
  
 -- IF(@page_source = 'POC')  
 --  BEGIN  
  
 --   SET @com_comment_id = (SELECT parent_comment_id FROM CarePlan_Intervention_Comment WHERE comment_id = @com_comment_id AND page_source = 'POC')  
  
 --  UPDATE CarePlan_Intervention_Comment SET  
 --  is_deleted = 1  
 --  ,updated_date = GETDATE()  
 --  ,updated_by = @user_id  
 --  WHERE parent_comment_id = @com_comment_id AND page_source IN('POC')  
 -- END  
  
 --END  
  
 FETCH NEXT FROM InterventionCommentCursor     
 INTO     
 @com_Action,  
 @com_comment_id,  
 @com_intervention_id,  
 @com_comment,  
 @com_comment_source,  
 @com_parent_comment_id,  
 @com_page_source,  
 @com_episode_id,  
 @com_pto_id,  
 @com_oasis_id,  
 @com_poc_id  
  
 END  
  
 CLOSE InterventionCommentCursor;    
 DEALLOCATE InterventionCommentCursor;    
 --Intervention Comment Process End-------------------------------------
 


  --Care Goal Comment Process Start----------------------------------  
 DECLARE CareGoalCommentCursor CURSOR FOR  
 SELECT   
 [Action],  
 comment_id,  
 goal_group_id,  
 comment,  
 comment_source,  
 parent_comment_id,  
 page_source,  
 episode_id,  
 pto_id,  
 oasis_id,  
 poc_id FROM @CareGoalCommentTempTable  
  
 OPEN CareGoalCommentCursor  
  
 FETCH NEXT FROM CareGoalCommentCursor  
 INTO    
 @gcom_Action,  
 @gcom_comment_id,  
 @gcom_goal_group_id,  
 @gcom_comment,  
 @gcom_comment_source,  
 @gcom_parent_comment_id,  
 @gcom_page_source,  
 @gcom_episode_id,  
 @gcom_pto_id,  
 @gcom_oasis_id,  
 @gcom_poc_id  
  
 WHILE @@FETCH_STATUS = 0    
 BEGIN   
  
 IF @gcom_Action = 'Add' OR @gcom_Action = 'AddFromLateAdmissionOrder' OR @gcom_Action = 'AddFromProfile' OR @gcom_Action = 'AddFromProfileTCN' OR @gcom_Action = 'AddFromVisitNote'  
 BEGIN
    
  INSERT INTO CarePlan_CareGoal_Comment  
  (  
  goal_group_id  
  ,comment  
  ,comment_source  
  ,parent_comment_id  
  ,page_source  
  ,episode_id  
  ,pto_id  
  ,oasis_id  
  ,poc_id  
  ,created_date  
  ,created_by  
  ,updated_date  
  ,updated_by  
  ,agency_id,
  visit_date,
  cg_note_id
  )  
  VALUES(  
   @gcom_goal_group_id  
  ,@gcom_comment  
  ,@gcom_comment_source  
  ,@gcom_parent_comment_id  
  ,CASE WHEN @gcom_Action = 'AddFromLateAdmissionOrder' OR @gcom_Action = 'AddFromProfile' THEN 'PTO' WHEN @gcom_Action = 'AddFromProfileTCN' THEN 'TCN' ELSE @gcom_page_source END  
  ,@episode_id  
  ,@pto_id  
  ,@oasis_id  
  ,@poc_id  
  ,GETDATE()  
  ,@user_id  
  ,GETDATE()  
  ,@user_id  
  ,@agencyId,
  @visit_date,
  @cg_note_id
  )  
  
 END  
  
  
 FETCH NEXT FROM CareGoalCommentCursor     
 INTO     
 @gcom_Action,  
 @gcom_comment_id,  
 @gcom_goal_group_id,  
 @gcom_comment,  
 @gcom_comment_source,  
 @gcom_parent_comment_id,  
 @gcom_page_source,  
 @gcom_episode_id,  
 @gcom_pto_id,  
 @gcom_oasis_id,  
 @gcom_poc_id  
  
 END  
  
 CLOSE CareGoalCommentCursor;    
 DEALLOCATE CareGoalCommentCursor;    
 --Care Goal Comment Process End-------------------------------------
  
 IF @@TranCount>0  
 COMMIT TRANSACTION  
  
 END TRY  
 BEGIN CATCH  
  ROLLBACK TRANSACTION  
  SET @msg = ERROR_MESSAGE()  
  RAISERROR(@msg, 16, 1)  
  RETURN  
 END CATCH  
  
END  
  
  
GO

