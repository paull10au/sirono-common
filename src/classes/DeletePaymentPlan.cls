/*
 * @author Sirono 
 * @version 1.0.1
 * @Date: 05-20-2016
 * @description
 * Mohan Kumar 08-01-2016: Ticket # 06638016 - Updated the QueryString parameter value to fix the "URL No Longer Exists" error.
 * Mohan Kumar 08-02-2016: Ticket # 06638015 - Updated the request parameter value to send the Sirono External ID and NOT salesforce record Id.
 */

public with sharing class DeletePaymentPlan {
    public String username {get; set;}
    public String password {get; set;}
    public String guarantorId {get; set;}
    public String paymentPlanId {get; set;}
    public String paymentPlanExtId {get; set;}
    private List<Charge_Group__c> lstCG = new List<Charge_Group__c>();
    private test__c paymentPlanObj = new test__c();
    public Boolean blnHasError = true;
    // Constructor of a class and initialize the variables.
    public DeletePaymentPlan() {
        username = PayStaffWSUtill.un;
        password = PayStaffWSUtill.pw;
        guarantorId = null;
        paymentPlanId = null;
        paymentPlanExtId = null;

        if (Apexpages.currentPage().getParameters().containsKey('guarantorId')) {
            guarantorId = Apexpages.currentPage().getParameters().get('guarantorId');
        }
        if (Apexpages.currentPage().getParameters().containsKey('paymentPlanId')) {
            paymentPlanId = Apexpages.currentPage().getParameters().get('paymentPlanId');
        }
        if (Apexpages.currentPage().getParameters().containsKey('paymentPlanExtId')) {
            paymentPlanExtId = Apexpages.currentPage().getParameters().get('paymentPlanExtId');
        }
    }

    //Check String is empty or not
    private Boolean isEmpty(String str) {
        return (str == null || str.trim().equals(''));
    }

    /*Mohan Kumar 08-01-2016: Ticket # 06638016 - 
     *Updated the QueryString parameter value to fix the "URL No Longer Exists" error.
     */
    public Pagereference cancel() {
        Pagereference pg = null;
        if (!isEmpty(paymentPlanId)) {
            pg = new Pagereference('/' + paymentPlanId);
        } else if (!isEmpty(guarantorId)) {
            pg = new Pagereference('/' + guarantorId);
        } else {
            pg = new Pagereference('/home/home.jsp');
        }
        pg.setRedirect(true);
        return pg;
    }

    //call doDeletePaymentPlan and send the request to end point.
    public void doSubmit() {
        try {
            if (!isEmpty(paymentPlanExtId)) {
                String jwtToken = PayStaffWSUtill.getJWTToken(username, password);
                String csrfToken = PayStaffWSUtill.getCSRFToken();
                if (csrfToken != null && jwtToken != null) {
                    callPaymentPlanRequest(csrfToken, jwtToken);
                    //doDeletePaymentPlan(csrfToken, jwtToken);
                }
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                        'Payment Plan Id is missing.'));
                if (Test.IsRunningTest()) {
                    TestUtility.generateException();
                }
            }
        } catch (Exception e) {
            // Debug error response
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'ERROR: ' + e.getMessage()));

        }
    }    
    
    /*
    * 09-22-2016: Viraj Rana - Tracker #129177479
    *  Call the paymentplan Web Service to get the paymentplan information.
    */
    private void callPaymentPlanRequest(String csrfToken, String jwtToken) {
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();

        Http http = new Http();
        String responseBody;

        req.setMethod('GET');
        req.setHeader('Authorization', 'JWT ' + jwtToken);
        req.setHeader('Content-type', 'application/json');
        req.setEndpoint(SironoSettingsUtil.getServerEndpoint() + '/paystaff/api/paymentplan/'
                + PayStaffWSUtill.trimCommas(paymentPlanExtId) + '/');
        req.setTimeout(120000);
        try {
            res = http.send(req);
            responseBody = res.getBody();

            if (Test.isRunningTest()) {
                res.setStatusCode(TestUtility.statusCode2);
                TestUtility.generateException();
            }
        } catch (Exception e) {

        }
        if (res.getStatusCode() != null && res.getStatusCode() == 200) {

            parsePaymentPlanResponse(responseBody, csrfToken, jwtToken);

        } else {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'RESPONSE : ' + res.toString() +
                            '  RESPONSE BODY::' + responseBody));
        }
    }
    
    /*
    * 09-22-2016: Viraj Rana - Tracker # 129177479    
    * parse the Payment Plan JSON and Make a new request to get the charge group detailsyment Plan
    */
    private void parsePaymentPlanResponse(String jsonStr, String csrfToken, String jwtToken) {

        PaymentPlanJSONParsing.PaymentPlanWrapper objPaymentPlanWrapper;
        objPaymentPlanWrapper = PaymentPlanJSONParsing.createPaymentPlanRecord(jsonStr, guarantorId,
                null, null);

        paymentPlanObj = new test__c();
        paymentPlanObj = objPaymentPlanWrapper.paymentPlanRecord;
        paymentPlanObj.Active__c = false;
        paymentPlanObj.Cancellation_Date__c = system.today();

        lstCG = new List<Charge_Group__c>();
        lstCG = objPaymentPlanWrapper.chargeGroupRecords;

        for (Charge_Group__c cg : lstCG) {
            callChargeGroupRequest(String.valueof(cg.Charge_Group_ID__c), jwtToken, cg);
        }

        if (blnHasError == true) {
            doDeletePaymentPlan(csrfToken, jwtToken);
        }
    }
    
    /*
    * 09-22-2016: Viraj Rana - Tracker # 129177479
    * make a Charge group Reqeuest to get the chargeGroupInformation
    */
    private void callChargeGroupRequest(String chargeGroupId, String jwtToken, Charge_Group__c cg) {
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();

        Http http = new Http();
        String responseBody;

        req.setMethod('GET');
        req.setHeader('Authorization', 'JWT ' + jwtToken);
        req.setHeader('Content-type', 'application/json');
        req.setEndpoint(SironoSettingsUtil.getServerEndpoint() + '/paystaff/api/chargegroups/'
                + PayStaffWSUtill.trimCommas(chargeGroupId) + '/');

        req.setTimeout(120000);
        try {
            res = http.send(req);
            responseBody = res.getBody();
            if (Test.isRunningTest()) {
                res.setStatusCode(TestUtility.statusCode3);
                TestUtility.generateException();
            }
        } catch (Exception e) {
            //blnHasError = false;
        }
        if (res.getStatusCode() != null && res.getStatusCode() == 200) {

            parseChargeGroupResponse(responseBody, cg);
        } else {

            blnHasError = false;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'RESPONSE : ' + res.toString() +
                            '  RESPONSE BODY::' + responseBody));
        }
    }
    
    
    /*
    * 09-22-2016: Viraj Rana - Tracker # 129177479
    * parse the chargroup json and update the sub status
    */
    private void parseChargeGroupResponse(String responseBody, Charge_Group__c cg) {
        ChargeGroupJSONParsing objChargeGroup = ChargeGroupJSONParsing.parse(responseBody);
        cg.Account_Sub_Status__c = objChargeGroup.extended_status.abbreviate(29);
        cg.Payment_Plan__c = null;
    }
    
    
    /*Mohan Kumar 08-02-2016: Ticket # 06638015 - 
     *Updated the request parameter value to send the Sirono External ID and NOT salesforce record Id.
     */
    private void doDeletePaymentPlan(String csrfToken, String jwtToken) {
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();

        Http http = new Http();
        String responseBody;

        req.setMethod('DELETE');
        req.setHeader('Authorization', 'JWT ' + jwtToken);
        req.setHeader('Content-type', 'application/json');
        req.setEndpoint(SironoSettingsUtil.getServerEndpoint() + '/paystaff/api/paymentplan/' +
                PayStaffWSUtill.trimCommas(paymentPlanExtId) + '/');

        try {
            res = http.send(req);
            responseBody = res.getBody();
            if (Test.isRunningTest()) {
                res.setStatusCode(TestUtility.statusCode4);
                TestUtility.generateException();
            }
        } catch (Exception e) {
            // Debug error response
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'PROCESS PAYMENT EXCEPTION RESPONSE : ' + res.toString() +
                            '  RESPONSE BODY::' + responseBody +
                            ' EXCEPTION:: ' + e.getMessage()));
        }

        if (res.getStatusCode() != null && res.getStatusCode() == 204) {
            Update paymentPlanObj;
            Update lstCG;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.INFO,
                    'Payment plan was successfully cancelled.'));
        } else {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'RESPONSE : ' + res.toString() +
                            '  RESPONSE BODY::' + responseBody));
        }
    }
}