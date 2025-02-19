USE [IDOneSourceHomeHealth]
GO

/****** Object:  StoredProcedure [dbo].[getPTOandChild_revamp]    Script Date: 2/19/2025 9:20:12 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- KBB 07/12/2023 Removed "isDelete" filter for physician address.. to allow old PTO that is associated with deleted address to display. 
-- Mark A. Update to get care plan data specific to the PTO page only - 05/14/2024

--	UPDATED BY: MARK A.
--	UPDATED ON: 05/29/2024
--	DESCRIPTION: ADDED CARE GOAL COMMENTS TO THE RESULT

-- UPDATED BY: Mark A.
-- UPDATED ON: 07/15/2024
-- DESCRIPTION: Date of visit note care plan comments will based on visit date and only comments from prior date will be shown

ALTER PROCEDURE [dbo].[getPTOandChild_revamp]     
 @ptoId bigint,    
 @agencyid varchar(50) = NULL,    
 @userid AS VARCHAR(50)    
AS    
BEGIN    
 SET CONCAT_NULL_YIELDS_NULL OFF;    
    
 DECLARE @latestPTO bigint;    
 DECLARE @episodeid int;    
 DECLARE @patient_id bigint;    
 DECLARE @patient_intake_id bigint;    
 DECLARE @order_type varchar(20);    
 DECLARE @oasisid int;    
 DECLARE @document_id bigint;    
 DECLARE @document_name VARCHAR(MAX);    
 DECLARE @ptoCallDate datetime;    
    
 select      
  @episodeid = a.episode_id,     
  @order_type = a.order_type,     
  @patient_id = a.patient_id,     
  @patient_intake_id = a.patient_intake_id,     
  @document_id = b.doc_id,     
  @document_name = b.doc_name,    
  @ptoCallDate = a.Call_Date    
 from     
  pto a    
 LEFT JOIN     
  HHCDocument b on a.pto_id = b.parent_source_id AND b.doc_type = 'PO'    
 where     
  a.pto_id = @ptoid AND a.AgencyId = ISNULL(@agencyId, a.AgencyId) AND ISNULL(a.IsDeleted, 0) = 0;    
     
 IF NOT EXISTS(Select oasisid from oasis where pto_id = @ptoId AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0)    
 BEGIN    
 --Get Patient Intake Oasis Here     
 Select @oasisid = oasisid from oasis where CORRECTION_NUM not in ('CO', 'XX') and pto_id in ((Select p.pto_id from episode e    
 inner join pto p on e.episode_id = p.episode_id AND p.AgencyId = ISNULL(@agencyId, p.AgencyId) AND ISNULL(p.IsDeleted, 0) = 0    
 where    
 e.episode_id = @episodeid and (p.order_type = 'InitialIntake' OR p.order_type = 'Recertification') AND e.AgencyId = ISNULL(@agencyId, e.AgencyId) AND ISNULL(e.IsDeleted, 0) = 0))    
 AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0    
 END    
 ELSE    
 BEGIN    
 Select @oasisid = oasisid from oasis where pto_id = @ptoId AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0 AND CORRECTION_NUM not in ('CO', 'XX')   
 END    
    
 print @oasisid;    
    
 --Latest PTO should be based on    
 SELECT top 1 @latestPTO = pto_id    
 FROM PTO     
 WHERE patient_intake_id =     
 (SELECT patient_intake_id    
   FROM PTO     
   WHERE pto_id = @ptoid AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0) and order_type <> 'OtherOrder' and episode_id = @episodeid    
   AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0    
 ORDER BY DATEADD(day, 0, DATEDIFF(day, 0, call_date)) + DATEADD(day, 0 - DATEDIFF(day, 0, call_time), call_time) DESC;    
    
 DECLARE @periodId bigint;    
 DECLARE @periodTiming varchar(10);    
 DECLARE @periodSourceType varchar(30);    
 DECLARE @periodInstitutionalCode int;    
    
 IF @order_type = 'Recertification'    
 BEGIN    
 -- ---- CHECK IF RESUMPTION OF CARE IS PRESENT    
 -- ---- IF YES CHECK IF ROC DATE IS WITHIN 14 DAYS AND HAS INSTITUTIONAL CODE    
    
  SELECT TOP 1    
  @periodId = Id,    
  @periodTiming = Timing,    
  @periodSourceType = AdmissionSourceType    
  FROM Period where episodeId = @episodeid order by StartDate    
    
  IF @periodSourceType = 'Institutional'     
  BEGIN    
   SELECT TOP 1 @periodInstitutionalCode = isnull(InstitutionalCode, 61)     
   FROM PERIOD where isnull(IsDeleted, 0) = 0 AND    
   patientintakeId = @patient_intake_id AND episodeId = @episodeId    
   ORDER BY STARTDATE asc    
  END    
 END    
     
 DECLARE @inpatientDischargeDate datetime;    
    
 IF @order_type = 'ResumptionOfCare'    
 BEGIN    
  SELECT @inpatientDischargeDate = o.M1005_INP_DISCHARGE_DT FROM OASIS o where pto_id = @ptoId and isnull(o.IsDeleted, 0) = 0;    
    
  SELECT     
  @periodId = Id,    
  @periodTiming = Timing,    
  @periodSourceType = AdmissionSourceType,    
  @periodInstitutionalCode =  ROCInstitutionalCode    
  FROM PERIOD     
  WHERE episodeId = @episodeId AND @ptoCallDate BETWEEN StartDate AND EndDate    
 END    
    
    
 SELECT @latestPTO as latestPTO, 
 p.first_name + ' ' + p.Middle_Name + ' ' + p.Last_Name as physicianname,    
 case when pa.physician_address_id  is not null   
 then pa.street_1 + ' ' + pa.street_2 + ' ' + pa.city + ' ' + pa.state + ' ' + pa.zip   
 else pa2.street_1 + ' ' + pa2.street_2 + ' ' + pa2.city + ' ' + pa2.state + ' ' + pa2.zip   
 end as physicianaddress,    
 case when pa.physician_address_id  is not null   
 then pa.street_1 + ' ' + pa.street_2  
 else pa2.street_1 + ' ' + pa2.street_2  
 end as physicianstreetaddr,    
 case when pa.physician_address_id  is not null   
 then pa.city + ', ' + pa.state + ' ' + pa.zip   
 else pa2.city + ', ' + pa2.state + ' ' + pa2.zip  
 end as physiciancitystatezip,    
 case when pa.physician_address_id  is not null then pa.phone1 else pa2.phone1 end as workpphone, o.sent_signed_by,    
    --c.first_name + coalesce(' ' + c.middle_initial, '') + ' ' + c.last_name + ', ' + coalesce(rtrim(c.title), rtrim(t.caregivertype_code)) as caregiver_name,    
    --cc.first_name + coalesce(' ' + cc.middle_initial, '') + ' ' + cc.last_name + ', ' + coalesce(rtrim(cc.title), rtrim(tt.caregivertype_code)) as caregiver2_name,    
 --Updated 2/19/2020    
 case    
  when c.caregiver_id is not null then c.first_name + coalesce(' ' + c.middle_initial, '') + ' ' + c.last_name + ', ' + coalesce(rtrim(c.title), rtrim(t.caregivertype_code))    
  else ''    
 end as caregiver_name,    
 case    
  when cc.caregiver_id is not null then cc.first_name + coalesce(' ' + cc.middle_initial, '') + ' ' + cc.last_name + ', ' + coalesce(rtrim(cc.title), rtrim(tt.caregivertype_code))    
  else ''    
 end as caregiver2_name,    
 case    
  when c.is_active = 1 then 'Active'    
  when c.is_active = 0 then 'Inactive'    
  else ''    
 end as caregiver1_status,    
 case    
  when cc.is_active = 1 then 'Active'    
  when cc.is_active = 0 then 'Inactive'    
  else ''    
 end as caregiver2_status,    
 -----    
     
 case    
  when o.sent_signed_by is null then null    
  when cg.caregiver_id is null then u.first_name + ' ' + u.last_name    
  else cg.first_name + coalesce(' ' + cg.middle_initial, '') + ' ' + cg.last_name + ', ' + coalesce(rtrim(cg.title), rtrim(cgt.caregivertype_code))    
 end as sent_signed_by_name, o.rcvd_signed_by,    
 case    
  when o.rcvd_signed_by is null then null    
  else ph.first_name + ' ' + ph.middle_name + ' ' + ph.last_name    
 end as rcvd_signed_by_name, o.staff2_signed_by,    
    case    
  when o.staff2_signed_by is null then null    
  when ccg.caregiver_id is null then u_cc.first_name + ' ' + u_cc.last_name    
  else ccg.first_name + coalesce(' ' + ccg.middle_initial, '') + ' ' + ccg.last_name + ', ' + coalesce(rtrim(ccg.title), rtrim(ccgt.caregivertype_code))    
 end as staff2_signed_by_name,    
    coalesce(u_ce.esig_enabled, 0) as staff_esig_enabled,    
    coalesce(u_pe.esig_enabled, 0) as physician_esig_enabled,    
    coalesce(u_cce.esig_enabled, 0) as staff2_esig_enabled,    
    o.*,    
    p.Physician_id, p.is_active, p.Title, p.Last_Name, p.First_Name, p.Middle_Name, p.Suffix,     
    p.Specialty, p.AddressType_1, p.AddressType_2, p.Address_1, p.Address_2, p.City, p.State,     
    p.ZIP, p.Address_1_2, p.Address_2_2, p.City_2, p.State_2, p.ZIP_2, pa.faxnumber as Fax,    
    p.Pager, p.Phone1, p.Phone2, p.Email, p.Tax_Id_Num, p.Doc_Group, p.Contact_Name,     
    p.Contact_Phone, p.Contact_Fax, p.Contact_Email, p.Medicaid_ProviderNbr, p.UPIN_Nbr,     
    p.License_Num, p.notes, p.npi, p.CREATE_DATE, p.CREATE_USER_ID, p.CREATE_APP_NAME,     
    p.LAST_UPDATE_DATE, p.LAST_UPDATE_USER_ID, p.LAST_UPDATE_APP_NAME, p.Phone1_Ext, p.License_Expiration_Date, oasis_poc_id = poc.pocid, CONVERT(varchar, lr_sent_date, 101) as lr_sent_date, CONVERT(varchar, lr_received_date, 101) as lr_received_date, 
	@episodeid as episode_id, @oasisid as oasis_id    
 , CASE WHEN @order_type = 'ResumptionOfCare' THEN isnull(per.Id, 0)  ELSE isnull(@periodId, 0) END as PeriodId,     
 CASE WHEN @order_type = 'ResumptionOfCare' THEN isnull(per.Timing, '') ELSE isnull(@periodTiming, '') END as Timing,     
 CASE WHEN @order_type = 'ResumptionOfCare' THEN isnull(per.AdmissionSourceType, '') ELSE isnull(@periodSourceType, '') END as SourceType,     
 CASE WHEN @order_type = 'ResumptionOfCare' THEN isnull(per.ROCInstitutionalCode, -1) ELSE  isnull(@periodInstitutionalCode, -1) END as InstitutionalCode    
 FROM PTO o    
    LEFT JOIN Physician p on p.Physician_id = o.Physician_id AND p.AgencyId = ISNULL(@agencyId, p.AgencyId) AND ISNULL(p.IsDeleted, 0) = 0    
    LEFT JOIN PhysicianAddress pa on pa.Physician_id = p.Physician_id and o.physician_address_id = pa.physician_address_id    
    LEFT JOIN PhysicianAddress pa2 on o.physician_address_id = pa2.physician_address_id and pa2.Is_Primary = 1   
    LEFT JOIN caregiver c ON o.caregiver_id = c.caregiver_id AND c.AgencyId = ISNULL(@agencyId, c.AgencyId) AND ISNULL(c.Is_Deleted, 0) = 0    
    LEFT JOIN caregivertype t ON c.caregivertype_id = t.caregivertype_id AND t.AgencyId = ISNULL(@agencyId, t.AgencyId) AND ISNULL(t.IsDeleted, 0) = 0    
    LEFT JOIN caregiver cc ON o.caregiver2_id = cc.caregiver_id AND cc.AgencyId = ISNULL(@agencyId, cc.AgencyId) AND ISNULL(cc.Is_Deleted, 0) = 0    
    LEFT JOIN caregivertype tt ON cc.caregivertype_id = tt.caregivertype_id AND tt.AgencyId = ISNULL(@agencyId, tt.AgencyId) AND ISNULL(tt.IsDeleted, 0) = 0    
    LEFT JOIN hhcuser u ON o.sent_signed_by = u.user_id AND u.AgencyId = ISNULL(@agencyId, u.AgencyId) AND ISNULL(u.IsDeleted, 0) = 0    
    LEFT JOIN caregiver cg ON u.caregiver_id = cg.caregiver_id AND cg.AgencyId = ISNULL(@agencyId, cg.AgencyId) AND ISNULL(cg.Is_Deleted, 0) = 0    
    LEFT JOIN caregivertype cgt on cg.caregivertype_Id =  cgt.caregivertype_id AND cgt.AgencyId = ISNULL(@agencyId, cgt.AgencyId) AND ISNULL(cgt.IsDeleted, 0) = 0    
    LEFT JOIN hhcuser u_p ON o.rcvd_signed_by = u_p.user_id AND u_p.AgencyId = ISNULL(@agencyId, u_p.AgencyId) AND ISNULL(u_p.IsDeleted, 0) = 0    
    LEFT JOIN physician ph ON u_p.caregiver_id = ph.physician_id AND ph.AgencyId = ISNULL(@agencyId, ph.AgencyId) AND ISNULL(ph.IsDeleted, 0) = 0    
    LEFT JOIN hhcuser u_cc ON o.staff2_signed_by = u_cc.user_id AND u_cc.AgencyId = ISNULL(@agencyId, u_cc.AgencyId) AND ISNULL(u_cc.IsDeleted, 0) = 0    
    LEFT JOIN caregiver ccg ON u_cc.caregiver_id = ccg.caregiver_id AND ccg.AgencyId = ISNULL(@agencyId, ccg.AgencyId) AND ISNULL(ccg.Is_Deleted, 0) = 0    
    LEFT JOIN caregivertype ccgt ON ccg.caregivertype_id = ccgt.caregivertype_id AND ccgt.AgencyId = ISNULL(@agencyId, ccgt.AgencyId) AND ISNULL(ccgt.IsDeleted, 0) = 0    
    LEFT JOIN (    
        SELECT caregiver_id, esig_enabled = max(coalesce(esig_enabled, 0))     
        FROM hhcuser WHERE usertype in (2,3) AND is_active = 1  AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0 GROUP BY caregiver_id    
    ) u_ce ON o.caregiver_id = u_ce.caregiver_id    
    LEFT JOIN hhcuser u_pe ON o.physician_id = u_pe.caregiver_id AND u_pe.usertype = 1 AND u_pe.AgencyId = ISNULL(@agencyId, u_pe.AgencyId) AND ISNULL(u_pe.IsDeleted, 0) = 0    
    LEFT JOIN hhcuser u_cce ON o.caregiver2_id = u_cce.caregiver_id AND u_cce.usertype in (2,3) AND u_cce.AgencyId = ISNULL(@agencyId, u_cce.AgencyId) AND ISNULL(u_cce.IsDeleted, 0) = 0    
    LEFT JOIN poc ON o.pto_id = poc.pto_id AND poc.AgencyId = ISNULL(@agencyId, poc.AgencyId) AND ISNULL(poc.IsDeleted, 0) = 0    
 LEFT JOIN PERIOD per on per.episodeId = o.episode_id AND CASE WHEN @order_type = 'ResumptionOfCare' THEN ISNULL(@inpatientDischargeDate,o.call_date) ELSE o.call_date END BETWEEN per.StartDate AND per.EndDate AND isnull(per.isDeleted, 0) = 0    
 WHERE o.pto_id = @ptoid AND o.AgencyId = ISNULL(@agencyId, o.AgencyId) AND ISNULL(o.IsDeleted, 0) = 0    
  --AND ISNULL(pa.isDeleted, 0) = 0    
    
     
 SELECT *     
 FROM PatientIntake 
 WHERE patient_intake_id in     
  (    
   SELECT patient_intake_id    
   FROM PTO     
   WHERE pto_id = @ptoid AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0    
  ) AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0;    
    
 SELECT *     
 FROM POCFrequencyVisit     
 WHERE pto_id = @ptoid and source = 'PTO'    
 and [AgencyId] = @agencyid    
 AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0;   
     
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
   ,a.[isDeleted],
   ISNULL(a.DispensableDrugID, 0) as DispensableDrugID,
   '1' as MedicationSourceID
 FROM POCMedicationsV2 a    
 WHERE a.pto_id = @ptoId AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0    
 ORDER BY a.sortorder;    
     
 SELECT * FROM VisitPlan v    
 WHERE v.episode_id = @episodeid AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0;    
     
 SELECT i.name as InpatFacilityName, o.*, poc.pocid    
 FROM oasis o    
 LEFT JOIN InpatientFacility i on i.inpat_fac_id = o.facilityid AND i.AgencyId = ISNULL(@agencyId, i.AgencyId) AND ISNULL(i.IsDeleted, 0) = 0    
 LEFT JOIN POC poc on poc.oasisid = o.oasisid AND poc.AgencyId = ISNULL(@agencyId, poc.AgencyId) AND ISNULL(poc.IsDeleted, 0) = 0    
 WHERE o.oasisid = @oasisid AND o.AgencyId = ISNULL(@agencyId, o.AgencyId) AND ISNULL(o.IsDeleted, 0) = 0;    
    
 -- SELECT * FROM poc    
 --WHERE pto_id = @ptoid OR pocid IN (SELECT p.pocid    
 --  FROM POCMedications a    
 --  JOIN poc p on a.pocid = p.pocid    
 --  JOIN oasis o on p.oasisid = o.oasisid     
 --  WHERE o.episode_id = @episodeid    
 --);    
    
 --SELECT * FROM poc where 1 = 0;    
    
 IF ((SELECT order_type FROM PTO WHERE PTO_ID= @ptoid AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0) = 'AdmissionOrder')    
 BEGIN    
  SELECT * FROM POC WHERE PTO_ID = (SELECT PTO_ID FROM PTO WHERE patient_intake_id IN(    
  SELECT patient_intake_id FROM PTO WHERE  PTO_ID = @ptoid AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0) AND episode_id = @episodeid AND  order_type = 'InitialIntake'     
  AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0)    
  AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0     
 END    
 ELSE    
 BEGIN    
  SELECT * FROM poc    
  WHERE pto_id = @ptoid AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0;    
 END    
     
 SELECT * FROM pocmedicationcont    
 WHERE pto_id = @ptoid AND AgencyId = ISNULL(@agencyId, AgencyId) AND ISNULL(IsDeleted, 0) = 0;    
    
 SELECT pa.*, coalesce(v.actual_visit_date, vp.scheduled_visit_date, pa.alert_effective_date) as alert_date    
 FROM pto p    
  JOIN patientalert pa ON p.patient_intake_id = pa.patient_intake_id AND pa.AgencyId = ISNULL(@agencyId, pa.AgencyId) AND ISNULL(pa.IsDeleted, 0) = 0    
  LEFT JOIN caregivernote cgn ON pa.source = 'VN' and pa.source_id = cgn.cg_note_id AND cgn.AgencyId = ISNULL(@agencyId, cgn.AgencyId) AND ISNULL(cgn.Is_Deleted, 0) = 0    
  LEFT JOIN visits v ON v.visit_id = cgn.visit_id AND v.AgencyId = ISNULL(@agencyId, v.AgencyId) AND ISNULL(v.IsDeleted, 0) = 0    
        LEFT JOIN visitplan vp ON vp.visit_plan_id = cgn.visit_plan_id AND vp.AgencyId = ISNULL(@agencyId, vp.AgencyId) AND ISNULL(vp.IsDeleted, 0) = 0    
 WHERE p.pto_id = @ptoid    
 AND p.AgencyId = ISNULL(@agencyId, p.AgencyId) AND ISNULL(p.IsDeleted, 0) = 0    
 ORDER by alert_date;    
    
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
   ,a.[group_by_med_id]     
   ,a.[episode_id]    
   ,dbo.getMedicationErrorMessage(a.[pto_id], a.[POCID], @episodeid, a.[drug_gen_id], a.[Medication_Name], @agencyid, 'PTO', a.[group_by_med_id], @userid) AS errmessage,
   ISNULL(a.DispensableDrugID, 0) as DispensableDrugID,
   '1' as MedicationSourceID
 FROM PTOMedications a    
 LEFT JOIN POCMedicationsv2 poc on a.group_by_med_id = poc.group_by_med_id and a.pto_id = poc.pto_id    
 WHERE a.pto_id = @ptoId    
 AND a.AgencyId = ISNULL(@agencyId, a.AgencyId) AND ISNULL(a.IsDeleted, 0) = 0    
 ORDER BY poc.sortorder;    
    
 SELECT * FROM     
 OasisMedications    
 WHERE 1 = 0;    
    
     
 --SELECT * FROM     
 --MedicationProfile    
 --WHERE 1 = 0;    
    
 IF(SELECT COUNT (1) FROM  PatientIntakeLegalRepresentative a LEFT JOIN PatientLegalRepresentative b on a.legalrepresentativeid = b.legalrepresentativeid WHERE episodeId = @episodeid AND ISNULL(a.IsDeleted, 0) = 0) > 0    
  BEGIN    
  SELECT TOP 1    
   b.FirstName + ' ' + b.LastName as LRName,    
   b.ContactNumber as LRPhone,    
   b.EmailAddress as LREmailAddress,    
   CONVERT(varchar, b.EffectiveDate, 101)  as LREffectiveDate,    
   (select count(1) from patientintakelegalrepresentative lr where lr.m0020_pat_id = @patient_id) as CountLR,    
   @patient_intake_id as PatientIntakeID,    
   @document_id as document_id,    
   @document_name as document_name,    
   b.[address] + ' ' + b.city + ' ' + b.[state] + ' ' + b.[zip] as LRAddress     
  FROM     
   PatientIntakeLegalRepresentative a    
  LEFT JOIN    
   PatientLegalRepresentative b on a.legalrepresentativeid = b.legalrepresentativeid    
  WHERE    
   episodeId = @episodeid AND ISNULL(a.IsDeleted, 0) = 0   
  ORDER BY    
   a.IntakeLegalRepresentativeID DESC    
 END    
 ELSE    
 BEGIN    
  SELECT     
   '' as LRName,    
   '' as LRPhone,    
   '' as LREmailAddress,    
   '' as LREffectiveDate,    
   '0' as CountLR,    
   '' as PatientIntakeID,    
   '' as document_id,    
   '' as document_name,    
   '' as LRAddress    
 END    
    
    
 SELECT *    
 FROM Agency     
 WHERE agency_id_login = @agencyId    
    
 --declare @sourceprod varchar(50) = 'PTO';    
 --select @sourceprod = ISNULL(problem_source, @sourceprod) from CarePlan_Problem where pto_id = @ptoid AND COALESCE(is_deleted,0) = 0    
    
 --CarePlan Problem    
 SELECT * FROM dbo.Func_GetAllCarePlanProblemByEpisodeId(@episodeid, @ptoid, -1, -1, -1, 'PTO', DEFAULT)    
    
 --CarePlan Goal    
 SELECT * FROM dbo.Func_GetAllCarePlanCareGoalByEpisodeId(@episodeid, @ptoid, -1, -1, -1, 'PTO', DEFAULT)    
    
 --CarePlan Intervention    
 SELECT * FROM dbo.Func_GetAllCarePlanInterventionByEpisodeId(@episodeid, @ptoid, -1, -1, -1, 'PTO', DEFAULT)    
    
 --CarePlan Intervention Comment    
 SELECT * FROM dbo.Func_GetAllCarePlanInterventionCommentByEpisodeId(@episodeid, @ptoid, -1, -1, 'PTO', NULL)  ORDER BY COALESCE(visit_date, created_timestamp), CASE WHEN visit_date IS NOT NULL THEN created_timestamp END
 
  --CarePlan Care Goal Comment    
 SELECT * FROM dbo.Func_GetAllCarePlanCareGoalCommentByEpisodeId(@episodeid, @ptoid, -1, -1, 'PTO', NULL)  ORDER BY COALESCE(visit_date, created_timestamp), CASE WHEN visit_date IS NOT NULL THEN created_timestamp END
    
 --SELECT [dbo].[getCareplanErrorMessage](@episodeid, @ptoid, -1, -1, 'PTO') AS CareplanErrorMessage    
    
 --CarePlan Problem Oasis    
 SELECT * FROM dbo.Func_GetAllCarePlanProblemByEpisodeId(@episodeid, -1, @oasisid, -1, -1, 'OASIS', DEFAULT)    
    
 --CarePlan Goal    
 SELECT * FROM dbo.Func_GetAllCarePlanCareGoalByEpisodeId(@episodeid, -1, @oasisid, -1, -1, 'OASIS', DEFAULT)    
    
 --CarePlan Intervention    
 SELECT * FROM dbo.Func_GetAllCarePlanInterventionByEpisodeId(@episodeid, -1, @oasisid, -1, -1, 'OASIS', DEFAULT)    
END 
GO

