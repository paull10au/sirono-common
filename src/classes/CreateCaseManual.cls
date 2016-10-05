/*
* @author Sirono
* @version 1.0.1
* @Date: 08-05-2016
* @description Create a Manual case based on the conditions*
*
* 08-05-2016: Sirono - Tracker # 127400857 For Manual Case Creation
*/


public with sharing class CreateCaseManual {
    public String guarantorRecordId { get; set; }
    public Boolean chargeGroupsSelected { get; set; }
    public String guarantorId { get; set; }
    public String guarantorName { get; set; }
    public String chargeGroupId { get; set; }
    public List<ChargeGroupWrapper> chrageGroupList { get; set; }
    public Case caseObj { get; set; }
    public String caseType { get; set; }
    public Boolean caseTypeSelected { get; set; }
    public Contact gc { get; set; }
    public String caseNotes { get; set; }
    public Contact guarantorContact { get; set; }
    public Contact patientContact { get; set; }
    private Charge_Group__c chargeGroup = new Charge_Group__c();

    /*
     * Constructor to get the guarantor and charge group details.
    */
    public CreateCaseManual(ApexPages.StandardController sc) {
        chargeGroupsSelected = false;
        chrageGroupList = new List<ChargeGroupWrapper>();
        guarantorName = '';
        caseObj = new Case();
        caseTypeSelected = false;
        patientContact = new contact();
        guarantorContact = new contact();
        guarantorRecordId = sc.getId();

        if (Apexpages.currentPage().getParameters().containsKey('guarantorId')) {
            guarantorRecordId = Apexpages.currentPage().getParameters().get('guarantorId');
        }
        if (guarantorRecordId != null) {
            Contact objContact = PayStaffWSUtill.fetchContact(guarantorRecordId);
            if (objContact != null) {
                if (objContact.RecordType.DeveloperName == 'Guarantor') {
                    gc = PayStaffWSUtill.fetchGuarantorContactWithCGConstraintsForCase(guarantorRecordId);
                    guarantorId = PayStaffWSUtill.fetchGuarantorId(gc);
                } else if (objContact.RecordType.DeveloperName == 'Patient') {
                    gc = PayStaffWSUtill.fetchPatientContactWithCGConstraintsForCase(guarantorRecordId);
                    guarantorId = PayStaffWSUtill.fetchPatientId(gc);
                }
            }

            guarantorName = PayStaffWSUtill.fetchGuarantorName(gc);

            caseObj.ContactId = gc.Id;

            for (ChargeGroupWrapper cgw : PayStaffWSUtill.fetchChargeGroupList(gc, objContact.RecordType.DeveloperName)) {
                if (cgw.cg.Active__c && cgw.cg.Balance__c != 0) {
                    chrageGroupList.add(cgw);
                }
            }
            chargeGroupId = '';
        }
    }

    /*
    * Cancel the case creation and back to the guarantor record.
    */
    public Pagereference cancel() {
        Pagereference pg = null;
        if (!isEmpty(guarantorRecordId)) {
            pg = new Pagereference('/' + guarantorRecordId);
        } else {
            pg = new Pagereference('/home/home.jsp');
        }
        pg.setRedirect(true);
        return pg;
    }

    /*
    * check charge group is selected or not and show the guarantor details.
    */
    public Pagereference doNext() {
        chargeGroupsSelected = false;

        //validate to see if user have selected Case Type
        chargeGroupId = PayStaffWSUtill.fetchChargeGroupIds(chrageGroupList);

        if (!isEmpty(chargeGroupId)) {
            chargeGroupsSelected = true;
        } else {
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, label.Charge_Groups_Require);
            ApexPages.addMessage(myMsg);
        }
        return null;
    }

    //get the case record type
    private String getCaseRecordTypeId(String rtName) {
        Schema.DescribeSObjectResult optySobj = Schema.SObjectType.Case;
        Map<String, Schema.RecordTypeInfo> rtMapByName = optySobj.getRecordTypeInfosByName();
        return rtMapByName.get(rtName).getRecordTypeId();
    }

    //check pass string is empty or not
    private Boolean isEmpty(String str) {
        return (str == null || str.trim().equals(''));
    }

    //get the Patient and Guarantor information
    public void gotoCaseCreation() {
        if (String.isNotBlank(caseType)) {
            caseTypeSelected = true;
            caseObj.RecordTypeId = getCaseRecordTypeId(caseType);

            //Check Charge Group is Selected
            if (caseType != 'General') {
                doNext();
            } else {
                chargeGroupsSelected = true;
            }

            Set<String> setChargeGroupId = new Set<String>();
            for (ChargeGroupWrapper cg : chrageGroupList) {
                if (cg.isSelected) {
                    setChargeGroupId.add(cg.cg.id);
                }
            }
            List<Charge_Group__c> lstChargeGroup = [
                    Select id, Guarantor_Name__c, Patient_Name__c
                    From Charge_Group__c
                    Where Id in :setChargeGroupId
                    order by CreatedDate desc
            ];
            if (lstChargeGroup.size() > 0) {
                chargeGroup = lstChargeGroup[0];
            }

            if (gc.RecordType.DeveloperName == 'Patient') {
                caseObj.Patient__c = gc.id;
                if (chargeGroup != null) {
                    caseObj.Guarantor_Information__c = chargeGroup.Guarantor_Name__c;
                }
                guarantorContact = PayStaffWSUtill.fetchContact(caseObj.Guarantor_Information__c);
                patientContact = gc;
            } else if (gc.RecordType.DeveloperName == 'Guarantor') {
                caseObj.Guarantor_Information__c = gc.id;
                if (chargeGroup != null) {
                    caseObj.Patient__c = chargeGroup.Patient_Name__c;
                }
                patientContact = PayStaffWSUtill.fetchContact(caseObj.Patient__c);
                guarantorContact = gc;
            }

        } else {
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, label.Case_Type_Require);
            ApexPages.addMessage(myMsg);
        }
    }

    //Create a new case
    public PageReference submit() {
        try {

            //Creating the DMLOptions for "Assign using active assignment rules" checkbox
            if (guarantorContact != null) {
                caseObj.ContactID = guarantorContact.id;
            }
            caseObj.Subject = caseObj.Reason;
            AssignmentRule ar = new AssignmentRule();
            ar = [
                    Select id
                    From AssignmentRule
                    Where SobjectType = 'Case' and Active = true
                    limit 1
            ];

            Database.DMLOptions dmlOpts = new Database.DMLOptions();
            dmlOpts.assignmentRuleHeader.assignmentRuleId = AR.id;
            caseObj.setOptions(dmlOpts);
            upsert caseObj;

            //create case comments
            if (String.isNotBlank(caseNotes)) {
                CaseComment cc = new CaseComment();
                cc.ParentId = caseObj.Id;
                cc.CommentBody = caseNotes;
                upsert cc;
            }

            //add selected Charge Groups to Case
            List<Case_Charge_Group__c> caseCGs = new List<Case_Charge_Group__c>();
            for (ChargeGroupWrapper cg : chrageGroupList) {
                if (cg.isSelected) {
                    Case_Charge_Group__c ccg = new Case_Charge_Group__c();
                    ccg.Case__c = caseObj.Id;
                    ccg.Charge_Group__c = cg.cg.Id;
                    caseCGs.add(ccg);
                }
            }
            upsert caseCGs;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.INFO, 'Created Successfully!'));
            if (test.isRunningTest()) {

                TestUtility.generateException();
            }

        } catch (Exception e) {
            // Debug error response
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, 'ERROR: ' + e.getMessage()));
        }
        return null;
    }

    public void refresh() {
        if (Apexpages.currentPage().getParameters().containsKey('reason')) {
            caseObj.Reason = Apexpages.currentPage().getParameters().get('reason');
        }
    }
    
    /*public PageReference redirect(){

      //Write your logic here and redirect
      PageReference retURL = new PageReference('/' + guarantorRecordId);
      retURL.setRedirect(true);
      return retURL;
     }*/
}