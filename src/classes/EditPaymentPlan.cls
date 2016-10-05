/*
* @author Sirono
* @version 1.0.1
* @Date: 05-25-2016
* @description
* Mohan Kumar 08-12-2016: Convert the amount in cents before sending it to Sirono
* 08-19-2016: Sirono - Tracker # 127324171 CCard Validations
* 
*/

public with sharing class EditPaymentPlan {
    public String username { get; set; }
    public String password { get; set; }
    public String guarantorId { get; set; }
    public String paymentPlanId { get; set; }
    public String paymentPlanRecordId { get; set; }
    public String guarantorName { get; set; }
    public String chargeGroupId { get; set; }
    public String planType { get; set; }
    public String planValue { get; set; }
    public String amount { get; set; }
    public String promiseAmount { get; set; }
    public String executeOnDay { get; set; }
    public String executeOnDayExisting { get; set; }
    public String cardHolderName { get; set; }
    public String expirationYear { get; set; }
    public String expirationMonth { get; set; }
    public String creditCardNumber { get; set; }
    public String cvv { get; set; }
    public String state { get; set; }
    public String zip { get; set; }
    public String address { get; set; }
    public String city { get; set; }
    public String numberInstallments { get; set; }
    public String payableAmount { get; set; }
    public String nextPaymentDate { get; set; }
    public String installmentsPaid { get; set; }
    public String installmentsTotal { get; set; }
    public String paymentPlanType { get; set; }
    public String guarantorRecordId { get; set; }
    public Boolean chargeGroupsSelected { get; set; }
    public List<ChargeGroupWrapper> chargeGroupList { get; set; }
    public decimal totalAmount { get; set; }
    public String responseBody = '';
    public Contact gc;
    //adding values to picklist
    public List<SelectOption> expYearOptions {
        get {
            if (expYearOptions == null) {
                expYearOptions = PayStaffWSUtill.expYearOptions;
            }
            return expYearOptions;
        }
        protected set;
    }

    //adding values to picklist
    public List<SelectOption> expMonthOptions {
        get {
            if (expMonthOptions == null) {
                expMonthOptions = PayStaffWSUtill.expMonthOptions;
            }
            return expMonthOptions;
        }
        protected set;
    }

    //Constructor initializing variables
    public EditPaymentPlan() {
        username = PayStaffWSUtill.un;
        password = PayStaffWSUtill.pw;
        guarantorRecordId = null;
        chargeGroupsSelected = false;
        paymentPlanId = null;
        paymentPlanRecordId = null;
        chargeGroupList = new List<ChargeGroupWrapper>();
        guarantorName = '';
        executeOnDayExisting = '';
        planType = 'auto';
        totalAmount = 0;
        if (Apexpages.currentPage().getParameters().containsKey('paymentPlanId')) {
            paymentPlanRecordId = Apexpages.currentPage().getParameters().get('paymentPlanId');
            for (test__c p : [
                    Select Id, Name, Number_of_Installments__c, Payable_Amount__c, Next_Payment_Date__c,
                            Plan_Type__c, Remaining_Number_of_Installments__c, Execute_on_Day__c, Sirono_ID__c
                    FROM test__c
                    Where id = :paymentPlanRecordId
            ]) {
                System.debug('23' + p);
                paymentPlanId = String.valueOf(p.Sirono_ID__c);
                numberInstallments = String.valueOf(p.Number_of_Installments__c);
                if (p.Payable_Amount__c != null) {
                    payableAmount = String.valueOf(p.Payable_Amount__c);
                } else {
                    payableAmount = '0';
                }
                nextPaymentDate = String.valueOf(p.Next_Payment_Date__c);
                installmentsTotal = numberInstallments;
                if (p.Remaining_Number_of_Installments__c != null && installmentsTotal != null) {
                    installmentsPaid = String.valueOf(
                            Integer.valueOf(installmentsTotal) - Integer.valueOf(p.Remaining_Number_of_Installments__c)
                    );
                } else {
                    installmentsPaid = '0';
                }
                if (p.Execute_on_Day__c != null && p.Execute_on_Day__c != 0) {
                    executeOnDayExisting = String.valueOf(p.Execute_on_Day__c);
                } else {
                    executeOnDayExisting = '1';
                }
                if (p.Plan_Type__c != null && p.Plan_Type__c.trim().equalsIgnoreCase('Manual')) {
                    planType = 'promise';
                }
            }
        }

        if (Apexpages.currentPage().getParameters().containsKey('guarantorId')) {
            guarantorRecordId = Apexpages.currentPage().getParameters().get('guarantorId');
            gc = PayStaffWSUtill.fetchGuarantorContact(guarantorRecordId);
            guarantorName = PayStaffWSUtill.fetchGuarantorName(gc);
            guarantorId = PayStaffWSUtill.fetchGuarantorId(gc);
            //chargeGroupList = PayStaffWSUtill.fetchChargeGroupList(gc);
            for (ChargeGroupWrapper cgw : PayStaffWSUtill.fetchChargeGroupList(gc)) {
                if (cgw.cg.Active__c && cgw.cg.Balance__c != 0 && cgw.cg.Account_Sub_Status__c == 'Payment Plan') {
                    cgw.isSelected = true;
                    chargeGroupList.add(cgw);
                    totalAmount += cgw.cg.Balance__c;
                }
            }
            chargeGroupId = PayStaffWSUtill.fetchChargeGroupIds(chargeGroupList);

        }
        planValue = '32772';
    }

    /*//Controller Methods invoked from VisualForce
    public Pagereference doNext() {
        chargeGroupsSelected = false;
        chargeGroupId = PayStaffWSUtill.fetchChargeGroupIds(chargeGroupList);
        if (!isEmpty(chargeGroupId)) {
            chargeGroupsSelected = true;
        }/*else{
            chargeGroupsSelected = false;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, 
                                    'Please select atleast one Charge Group'));
        }
        return null;
    }*/

    private Boolean isEmpty(String str) {
        return (str == null || str.trim().equals(''));
    }

    //Controller Methods invoked from VisualForce
    public Pagereference cancel() {
        Pagereference pg = null;
        if (!isEmpty(paymentPlanRecordId)) {
            pg = new Pagereference('/' + paymentPlanRecordId);
        } else if (!isEmpty(guarantorRecordId)) {
            pg = new Pagereference('/' + guarantorRecordId);
        } else {
            pg = new Pagereference('/home/home.jsp');
        }
        if (pg != null) {
            pg.setRedirect(true);
        }
        return pg;
    }
    /*
     * 08-19-2016: Sirono - Tracker # 127324171
     * Method for check the validation.
     */
    public void doSubmit() {
        try {
            //doEditPaymentPlan('', '');
            boolean blnIsError = false;
            if (!planType.trim().equalsIgnoreCase('promise')) {
                blnIsError = checkCardValidation();
            }

            boolean blnIsAmountError = checkAmountValidation();

            if (blnIsError == false && !blnIsAmountError) {
                String jwtToken = PayStaffWSUtill.getJWTToken(username, password);
                String csrfToken = PayStaffWSUtill.getCSRFToken();
                if (csrfToken != null && jwtToken != null) {
                    doEditPaymentPlan(csrfToken, jwtToken);
                }
            } else {
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
     * 08-19-2016: Sirono - Tracker # 127324171
     * Method for check the amount validation.
     */
    Public boolean checkAmountValidation() {
        boolean blnIsError = false;

        if ((planType.trim().equalsIgnoreCase('promise') &&
                (isEmpty(promiseAmount) || (promiseAmount.isNumeric() && decimal.valueof(promiseAmount) == 0))) ||
                (!planType.trim().equalsIgnoreCase('promise') &&
                        (isEmpty(amount) || (amount.isNumeric() && decimal.valueof(amount) == 0))
                )) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, 'Amount must be greater than zero.'));
            blnIsError = true;
        } else {
            if ((planType.trim().equalsIgnoreCase('promise') && decimal.valueof(promiseAmount) < 0)
                    || (!planType.trim().equalsIgnoreCase('promise') && decimal.valueof(amount) < 0)
                    ) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                        'Amount must be greater than zero.'));
                blnIsError = true;
            }

            if ((planType.trim().equalsIgnoreCase('promise') && decimal.valueof(promiseAmount) > decimal.valueof(payableAmount))
                    || (!planType.trim().equalsIgnoreCase('promise') && decimal.valueof(amount) > decimal.valueof(payableAmount))
                    ) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, 'Amount cannot exceed balance.'));
                blnIsError = true;
            }
        }
        return blnIsError;
    }

    // 09-13-2016: Viraj Rana - Tracker #130117819:   Credit Card Error Messaging Method to check the Card validation. 
    Public boolean checkCardValidation() {
        boolean blnIsError = false;
        if (creditCardNumber.length() < 12 || creditCardNumber.Length() > 19) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'Credit card number must be 12-19 digits.'));
            blnIsError = true;
        }
        if (isEmpty(creditCardNumber)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'Card Number is a required field.'));
            blnIsError = true;
        }
        if (Integer.valueof(expirationYear) < system.today().year() ||
                (Integer.valueof(expirationYear) == system.today().year() &&
                        Integer.valueof(expirationMonth) < system.today().Month())) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'Expiration date must be in the future.'));
            blnIsError = true;
        }
        if (!isEmpty(zip) && zip.length() != 5) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'Zip code must be 5 digits.'));
            blnIsError = true;
        }
        if (!isEmpty(zip) && !zip.isNumeric()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'Zip code can only contain numeric values.'));
            blnIsError = true;
        }
        if (isEmpty(cardHolderName)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'Name is a required field.'));
            blnIsError = true;
        }

        if (isEmpty(cvv)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'CVV is a required field.'));
            blnIsError = true;
        }

        if (isEmpty(address)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'Billing Address is a required field.'));
            blnIsError = true;
        }

        if (!isEmpty(cvv) && (cvv.length() < 3 || cvv.length() > 4)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'CVV must be 4 digits for American Express and 3 digits for other card types.'));
            blnIsError = true;
        }

        if (isEmpty(zip)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'Zip Code is a required field.'));
            blnIsError = true;
        }

        if (isEmpty(chargeGroupId)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'Charge Group is a required field.'));
            blnIsError = true;
        }
        return blnIsError;
    }


    //Send an request to end point 
    private void doEditPaymentPlan(String csrfToken, String jwtToken) {
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        String requestData = '{"csrfmiddlewaretoken":"' + csrfToken + '",';
        if (planType != null && planType.trim().equalsIgnoreCase('auto')) {
            planValue = '32772';
            requestData += '"plan_type":"' + planType + '",' +
                    '"url": "' + (SironoSettingsUtil.getServerEndpoint() + '/paystaff/api/paymentplan/' + paymentPlanId + '/') + '",' +
                    '"active":true,' +
                    '"installment_amount":' + PayStaffWSUtill.convertToCents(amount) + ',' +
                    '"number_installments":' + numberInstallments + ',' +
                    '"plan_value":' + planValue + ',' +
                    '"payable_amount":' + PayStaffWSUtill.convertToCents(payableAmount) + ',' +
                    '"execute_on_day":' + executeOnDay + ',' +
                    '"guarantor":"' + SironoSettingsUtil.getServerEndpoint() + '/paystaff/api/guarantors/' + guarantorId + '/",' +
                    '"next_payment_date": "' + nextPaymentDate + '",' +
                    '"installments_paid": ' + installmentsPaid + ',' +
                    '"installments_total": ' + installmentsTotal + ',' +
                    '"chargegroups": ' + PayStaffWSUtill.buildChargeGroupsURL(chargeGroupId) + ',' +
                    '"credit_card":{' +
                    '"method":"credit",' +
                    '"cardholder_name":"' + cardholderName + '",' +
                    '"expiration_year":"' + expirationYear + '",' +
                    '"expiration_month":"' + expirationMonth + '",' +
                    '"number":"' + creditCardNumber + '",' +
                    '"cvv":"' + cvv + '",' +
                    '"state":"' + state + '",' +
                    '"zipcode":"' + zip + '",' +
                    '"address_1":"' + address + '",' +
                    '"city":"' + city + '"' +
                    '}' + '}';
            req.setMethod('PUT');
        } else if (planType != null && planType.trim().equalsIgnoreCase('promise')) {
            planValue = '1700';
            /*requestData += '"plan_type":"' + planType + '",' +
            '"url": "' + (SironoSettingsUtil.getServerEndpoint()+'/paystaff/api/paymentplan/'+paymentPlanId+'/') + '",' +
            '"active":true,' +
            '"installment_amount":' + promiseAmount + ',' +
            '"number_installments":' + numberInstallments + ',' +
            '"plan_value":' + planValue + ',' +
            '"payable_amount":' + payableAmount + ',' +
            '"execute_on_day":' + executeOnDayExisting + ',' +
            '"guarantor":"' + SironoSettingsUtil.getServerEndpoint() + '/paystaff/api/guarantors/' + guarantorId + '/",' + 
            '"next_payment_date": "'+nextPaymentDate+'",' +
            '"installments_paid": '+installmentsPaid+',' +
            '"installments_total": '+installmentsTotal+',' +
            '"has_error": false,'+
            '"charges_added_since_start": null,'+
            '"error_date": null,'+
            '"chargegroups": ' + PayStaffWSUtill.buildChargeGroupsURL(chargeGroupId)+',' +
            '"delinquent": false,' +
            '"delinquent_date": null,' +
            '"encounters": [],' +
            '"authorized_amount": 0' +
            '}';*/
            requestData += '"installment_amount":' + PayStaffWSUtill.convertToCents(promiseAmount) + ',' +
                    '"guarantor":"' + SironoSettingsUtil.getServerEndpoint() + '/paystaff/api/guarantors/' + guarantorId + '/"' +
                    '}';
            req.setMethod('POST');
            req.setHeader('X-HTTP-Method-Override', 'PATCH');
        }
        Http http = new Http();
        String responseBody;
        req.setEndpoint(SironoSettingsUtil.getServerEndpoint() + '/paystaff/api/paymentplan/' + paymentPlanId + '/');
        //req.setMethod('PUT');
        req.setHeader('Authorization', 'JWT ' + jwtToken);
        req.setHeader('Content-type', 'application/json');
        System.debug('=================== PAYLOAD IS ' + requestData);
        req.setBody(requestData);

        try {
            res = http.send(req);
            responseBody = res.getBody();
            if (Test.IsRunningTest()) {
                TestUtility.generateException();
            }
            //responseBody  = testResponse();
            //System.debug('responseBody' + responseBody);

        } catch (Exception e) {
            // Debug error response
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'PROCESS PAYMENT EXCEPTION RESPONSE : ' + res.toString() +
                            '  RESPONSE BODY::' + responseBody +
                            ' EXCEPTION:: ' + e.getMessage()));
        }

        if (res.getStatusCode() != null && res.getStatusCode() == 200) {
            System.debug('RESPONSE : ' + res.toString() + '  RESPONSE BODY::' + responseBody);
            parseResponse(responseBody);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.INFO, 'Saved Successfully!'));
        } else {
            if (test.isRunningTest()) {
                responseBody = TestUtility.errorBody;
            }

            if (responseBody.Contains('non_field_errors') && responseBody.Contains('Validation exception')) {
                JSONParser parser = JSON.createParser(responseBody);
                WrapperErrorArray wrpPaymentPlanobj = (WrapperErrorArray) parser.readValueAs(WrapperErrorArray .class);
                if (wrpPaymentPlanobj != null && wrpPaymentPlanobj.errors.size() > 0) {
                    List<WrapperErrorArray.Errors> lstError = wrpPaymentPlanobj.errors;
                    for (WrapperErrorArray.Errors obj : lstError) {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, String.valueof(obj.non_field_errors)));
                    }
                }
            } else if (responseBody.Contains('non_field_errors') && responseBody.Contains('Payments Exception')) {
                JSONParser parser = JSON.createParser(responseBody);
                WrapperError wrpPaymentPlanobj = (WrapperError) parser.readValueAs(WrapperError.class);
                if (wrpPaymentPlanobj != null && wrpPaymentPlanobj.errors.non_field_errors.size() > 0) {
                    for (String strMessage : wrpPaymentPlanobj.errors.non_field_errors) {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, String.valueof(strMessage)));
                    }
                }
            } else if (responseBody.Contains('kind') && !responseBody.Contains('chargegroups')) {
                JSONParser parser = JSON.createParser(responseBody);
                WrapperListError wrpobj = (WrapperListError) parser.readValueAs(WrapperListError.class);
                if (wrpobj != null && wrpobj.errors.size() > 0) {
                    for (String strMessage : wrpobj.errors) {
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, String.valueof(strMessage)));
                    }
                }
            } else if (responseBody.Contains('kind') && responseBody.Contains('chargegroups')) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                        'RESPONSE : ' + res.toString() + '  RESPONSE BODY::' + responseBody));
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                        'RESPONSE : ' + res.toString() + '  RESPONSE BODY::' + responseBody));
            }
        }
    }
    
    /*
    * #130125231 : Enable "Fill Name and Address on File" functionality.
    * fill the address,city,state,zip variable with the guarantor information.
    */

    public void fillNameAndAddress() {
        cardHolderName = gc.name;
        address = gc.MailingStreet;
        city = gc.MailingCity;
        state = gc.MailingState;
        zip = gc.MailingPostalCode;
    }
    
    /*
    * 09-16-2016: Viraj Rana 
    *  Call this method to test
    */
    Public void doTesting() {
        String str = PaymentPlanJSONParsing.testResponse();
        parseResponse(str);
    }
    
    /*
    * 08-17-2016: Sirono - Tracker # 127940071
    *  parse the Response and create a payment plan record.
    */
    Public void parseResponse(String jsonStr) {

        PaymentPlanJSONParsing.PaymentPlanWrapper objPaymentPlanWrapper;
        objPaymentPlanWrapper = PaymentPlanJSONParsing.createPaymentPlanRecord(jsonStr, guarantorRecordId,
                null, chargeGroupId);
        test__c paymentPlanObj = objPaymentPlanWrapper.paymentPlanRecord;
        upsert paymentPlanObj;
    }
}