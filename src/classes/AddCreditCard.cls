/*
* @author: Sirono
* @version 1.0.1
* @Date: 05-02-2016
*
* 08-19-2016: Sirono - Tracker # 127324171 CCard Validations check
* 08-17-2016: Sirono - Tracker # 127940071  parse the Response and create a payment plan record.
* 
*/

//Mohan Kumar 08-12-2016: Convert the amount in cents before sending it to Sirono
public with sharing class AddCreditCard {
    public String username { get; set; }
    public String password { get; set; }
    public String guarantorId { get; set; }
    public String guarantorName { get; set; }
    public String chargeGroupId { get; set; }
    public String planType { get; set; }
    public String planValue { get; set; }
    public String amount { get; set; }
    public String promiseAmount { get; set; }
    public String executeOnDay { get; set; }
    public String cardHolderName { get; set; }
    public String expirationYear { get; set; }
    public String expirationMonth { get; set; }
    public String creditCardNumber { get; set; }
    public String cvv { get; set; }
    public String state { get; set; }
    public String zip { get; set; }
    public String address { get; set; }
    public String city { get; set; }
    public String guarantorRecordId { get; set; }
    public Boolean chargeGroupsSelected { get; set; }
    public List<ChargeGroupWrapper> chargeGroupList { get; set; }
    public String responseBody = '';
    public decimal dctotalAmount = 0;
    public Contact gc;
    //Adding values to the picklist 
    public List<SelectOption> paymentPlanTypeOptions {
        get {
            if (paymentPlanTypeOptions == null) {
                paymentPlanTypeOptions = new List<SelectOption>();
                paymentPlanTypeOptions.add(new SelectOption('auto', 'Auto Draft'));
                paymentPlanTypeOptions.add(new SelectOption('promise', 'Promise To Pay'));
            }
            return paymentPlanTypeOptions;
        }
        protected set;
    }

    //Adding values to the picklist
    public List<SelectOption> expYearOptions {
        get {
            if (expYearOptions == null) {
                expYearOptions = PayStaffWSUtill.expYearOptions;
            }
            return expYearOptions;
        }
        protected set;
    }

    //Adding values to the picklist
    public List<SelectOption> expMonthOptions {
        get {
            if (expMonthOptions == null) {
                expMonthOptions = PayStaffWSUtill.expMonthOptions;
            }
            return expMonthOptions;
        }
        protected set;
    }

    //Constructor for initializing variables 
    public AddCreditCard() {
        dctotalAmount = 0;
        username = PayStaffWSUtill.un;
        password = PayStaffWSUtill.pw;
        guarantorRecordId = null;
        chargeGroupsSelected = false;
        chargeGroupList = new List<ChargeGroupWrapper>();
        guarantorName = '';
        planType = null;
        if (Apexpages.currentPage().getParameters().containsKey('guarantorId')) {
            guarantorRecordId = Apexpages.currentPage().getParameters().get('guarantorId');
            gc = PayStaffWSUtill.fetchGuarantorContact(guarantorRecordId);
            guarantorName = PayStaffWSUtill.fetchGuarantorName(gc);
            guarantorId = PayStaffWSUtill.fetchGuarantorId(gc);
            //chargeGroupList = PayStaffWSUtill.fetchChargeGroupList(gc);
            for (ChargeGroupWrapper cgw : PayStaffWSUtill.fetchChargeGroupList(gc)) {
                if (cgw.cg.Active__c && cgw.cg.Balance__c != 0) {
                    chargeGroupList.add(cgw);
                }
            }
            chargeGroupId = '';
        }
        planValue = '32772';
        /*guarantorId = '141623';
        chargeGroupId = '1072113, 1064709, 1054046';
        planType = 'auto';
        planValue = '32772';
        amount = '500';
        executeOnDay = '13';
        cardHolderName = 'Joe Schmoe';
        expirationYear = '2016';
        expirationMonth = '09';
        creditCardNumber = '4012888888881881';
        cvv = '345';
        state = 'TX';
        zip = '78701';
        address = '1100 E 6th';
        city = 'Austin';
        */
    }

    //Controller Method invoked from Visualforce page
    public Pagereference doNext() {
        chargeGroupsSelected = false;
        chargeGroupId = PayStaffWSUtill.fetchChargeGroupIds(chargeGroupList);
        if (!isEmpty(chargeGroupId)) {
            chargeGroupsSelected = true;
        }/*else{
            chargeGroupsSelected = false;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, 'Please select atleast one Charge Group'));
        }*/
        return null;
    }

    //Controller Method invoked from Visualforce page
    public Pagereference doNothing() {
        return null;
    }

    private Boolean isEmpty(String str) {
        return (str == null || str.trim().equals(''));
    }

    //Controller Method invoked from Visualforce page
    public Pagereference doCancel() {
        Pagereference pg = null;
        if (!isEmpty(guarantorRecordId)) {
            pg = new Pagereference('/' + guarantorRecordId);
        } else {
            pg = new Pagereference('/home/home.jsp');
        }
        if (pg != null) {
            pg.setRedirect(true);
        }
        return pg;
    }

    //Controller Method invoked from Visualforce page
    public void doSubmit() {
        try {
            
            /*
            * 08-19-2016: Sirono - Tracker # 127324171
            * Method for check the amount validation.
            */

            boolean blnIsError = false;
            if (!planType.trim().equalsIgnoreCase('promise')) {
                blnIsError = checkCardValidation();
            }

            boolean blnIsAmountError = checkAmountValidation();

            if (blnIsError == false && !blnIsAmountError) {
                String jwtToken = PayStaffWSUtill.getJWTToken(username, password);
                String csrfToken = PayStaffWSUtill.getCSRFToken();
                if (csrfToken != null && jwtToken != null) {
                    doAddCreditCard(csrfToken, jwtToken);
                }
            } else {
                if (Test.IsRunningTest()) {
                    TestUtility.generateException();
                }
            }
        } catch (Exception e) {
            // Debug error response
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, 'ERROR: ' + e.getMessage()));
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
            dctotalAmount = 0;
            for (ChargeGroupWrapper cgw : chargeGroupList) {
                if (cgw.cg.Balance__c != null && cgw.IsSelected == true) {
                    dctotalAmount += cgw.cg.Balance__c ;
                }
            }
            if ((planType.trim().equalsIgnoreCase('promise') && decimal.valueof(promiseAmount) < 0)
                    || (!planType.trim().equalsIgnoreCase('promise') && decimal.valueof(amount) < 0)
                    ) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, 'Amount must be greater than zero.'));
                blnIsError = true;
            }
            if ((planType.trim().equalsIgnoreCase('promise') && decimal.valueof(promiseAmount) > dctotalAmount)
                    || (!planType.trim().equalsIgnoreCase('promise') && decimal.valueof(amount) > dctotalAmount)
                    ) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, 'Amount cannot exceed balance.'));
                blnIsError = true;
            }

        }
        return blnIsError;
    }
    
    /*
    * 08-19-2016: Sirono - Tracker # 127324171
    * Method for check the Card validation.
    * 09-13-2016: Viraj Rana - Tracker #130117819:   Credit Card Error Messaging Method to check the Card validation. 
    */
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

        if (!isEmpty(cvv) && (cvv.length() < 3 || cvv.length() > 4)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR,
                    'CVV must be 4 digits for American Express and 3 digits for other card types.'));
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

    // Method for add credit card.
    private void doAddCreditCard(String csrfToken, String jwtToken) {
        //doTesting(); return;

        String requestData = '{"csrfmiddlewaretoken":"' + csrfToken + '",';
        if (planType != null && planType.trim().equalsIgnoreCase('auto')) {
            planValue = '32772';
            requestData += '"plan_type":"' + planType + '",' +
                    '"plan_value":' + planValue + ',' +
                    '"installment_amount":' + PayStaffWSUtill.convertToCents(amount) + ',' +
                    '"execute_on_day":' + executeOnDay + ',' +
                    '"chargegroups": ' + PayStaffWSUtill.buildChargeGroupsURL(chargeGroupId) + ',' +
                    '"guarantor":"' + SironoSettingsUtil.getServerEndpoint() + '/paystaff/api/guarantors/' + guarantorId + '/",' +
                    '"active":true,' +
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
        } else if (planType != null && planType.trim().equalsIgnoreCase('promise')) {
            planValue = '1700';
            requestData += '"plan_type":"' + planType + '",' +
                    '"plan_value":' + planValue + ',' +
                    '"installment_amount":' + PayStaffWSUtill.convertToCents(promiseAmount) + ',' +
                    '"chargegroups": ' + PayStaffWSUtill.buildChargeGroupsURL(chargeGroupId) + ',' +
                    '"guarantor":"' + SironoSettingsUtil.getServerEndpoint() + '/paystaff/api/guarantors/' + guarantorId + '/",' +
                    '"active":true}';
        }

        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        Http http = new Http();
        req.setMethod('POST');
        req.setHeader('Authorization', 'JWT ' + jwtToken);
        req.setHeader('Content-type', 'application/json');
        req.setEndpoint(SironoSettingsUtil.getServerEndpoint() + '/paystaff/api/paymentplan/');
        req.setBody(requestData);

        try {
            System.debug(req.getBody());
            res = http.send(req);
            responseBody = res.getBody();

            if (Test.IsRunningTest()) {
                TestUtility.generateException();
            }

        } catch (Exception e) {
            System.debug(e.getMessage());
            // Debug error response
            //ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.ERROR, 'PROCESS PAYMENT EXCEPTION RESPONSE : '+ res.toString() + '  RESPONSE BODY::' + responseBody + ' EXCEPTION:: ' + e.getMessage()));
        }

        if (res.getStatus() != null && res.getStatus().trim().equalsIgnoreCase('CREATED')
                && res.getStatusCode() != null && res.getStatusCode() == 201) {
            parseResponse(responseBody);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.SEVERITY.INFO, 'Created Successfully!'));
        } else {
            if (test.isRunningTest()) {
                responseBody = TestUtility.Errorbody;
            }
            System.debug(responseBody);
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
        responseBody = PaymentPlanJSONParsing.testResponse();
        parseResponse(responseBody);
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
        paymentPlanObj.Name = String.valueof(paymentPlanObj.Sirono_ID__c);
        upsert paymentPlanObj;

        List<Charge_Group__c> lstCG = new List<Charge_Group__c>();
        lstCG = objPaymentPlanWrapper.chargeGroupRecords;
        for (Charge_Group__c cg : lstCG) {
            cg.Account_Sub_Status__c = 'Payment Plan';
            cg.Payment_Plan__c = paymentPlanObj.Id;
        }
        Update lstCG;
    }
}