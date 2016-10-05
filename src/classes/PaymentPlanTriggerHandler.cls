/* 
 * @author Sirono
 * @version 1.0.1
 * @date: 06-06-2016
 * @description Handler Class for PaymentPlantrigger
*/
public with sharing class PaymentPlanTriggerHandler {
    //static method invoked after insert event
    public static void afterInsert(List<test__c> newList) {
        checkCallListRemove(newList, null);
        callDelinquentPaymentPlanCaseCreation(newList, null);
        callCCErrorCaseCreation(newList, null);
    }

    //static method invoked after update event
    public static void afterUpdate(List<test__c> newList, Map<Id, test__c> oldMap) {
        checkCallListRemove(newList, oldMap);
        callDelinquentPaymentPlanCaseCreation(newList, oldMap);
        callCCErrorCaseCreation(newList, oldMap);
    }

    //static method invoked before insert event occurs
    public static void beforeInsert(List<test__c> newList) {
        callPopulateNextPaymentDate(newList, null, true);
    }

    //static method invoked after insert event
    public static void beforeUpdate(List<test__c> newList, Map<Id, Test__c> oldMap) {
        callPopulateNextPaymentDate(newList, oldMap, false);
    }

    //private staic method that collects the Guarantor IDs
    private static void checkCallListRemove(List<test__c> newList, Map<Id, test__c> oldMap) {
        Set<Id> contactIds = new Set<Id>();
        for (test__c pp : newList) {
            if (!pp.Active__c && pp.Delinquent_Date__c == null && pp.Guarantor_Name__c != null
                    && (oldMap == null || pp.Delinquent_Date__c != oldMap.get(pp.Id).Delinquent_Date__c
                    || pp.Active__c != oldMap.get(pp.Id).Active__c || pp.Guarantor_Name__c != oldMap.get(pp.Id).Guarantor_Name__c)) {
                contactIds.add(pp.Guarantor_Name__c);
            }
        }

        if (contactIds.size() > 0) {
            callListUtilities.DelinquentPaymentPlanCallListRemoval(contactIds);
        }
    }

    //Mohan Kumar (Sirono) 09-23-2016 : 127404425 Set/Reset the NextPaymentDate when Execute_on_day__c, Skip_Payment_Until__c, or Plan_Type__c fields are changed.
    public static void callPopulateNextPaymentDate(List<test__c> newList, Map<Id, Test__c> oldMap, Boolean isNew) {
        List<Test__c> newListToSetDate = new List<Test__c>();
        for (Test__c pp : newList) {
            if (isNew) {
                newListToSetDate.add(pp);
            } else {
                Test__c oldValue = oldMap.get(pp.Id);
                if (pp.Execute_on_Day__c != oldValue.Execute_on_Day__c || pp.Skip_Payment_Until__c != oldValue.Skip_Payment_Until__c
                        || pp.Plan_Type__c != oldValue.Plan_Type__c || pp.NextPaymentDate__c != oldValue.NextPaymentDate__c) {
                    newListToSetDate.add(pp);
                }
            }
        }
        if (newListToSetDate.size() > 0) {
            PaymentPlanTriggerHandler.populateNextPaymentDate(newListToSetDate, true);
        }
    }

    //private static method that decides the nextPaymentDate
    //Mohan Kumar (Sirono) 09-23-2016 : 127404425 calculates the NextPaymentDate on the Payment Plan reccord.
    //this method is called from different places. When this method is called from other than PaymentPlanTrigger then
    //fromPaymentPlanTrigger parameter contains FALSE and we will need to run the update DML statment to the list.

    public static void populateNextPaymentDate(List<test__c> newList, Boolean fromPaymentPlanTrigger) {
        List<Test__c> newListToUpdate = new List<Test__c>();
        Set<String> setContactId = new Set<String>();
        for (test__c plan:newList) {
            //System.assert(plan.Guarantor_Name__c != null);
            if (plan.Guarantor_Name__c != null) {
                setContactId.add(plan.Guarantor_Name__c);
            }
        }
        Map<Id, Contact> mapContacts = new Map<Id, Contact>([
                Select Id, Invoice_Offset_Date__c
                from Contact
                Where Id IN:setContactId
        ]);

        for (test__c plan:newList) {
            Contact guarantor = new Contact();
            if (plan.Guarantor_Name__c != null && mapContacts.containsKey(plan.Guarantor_Name__c)) {
                guarantor = mapContacts.get(plan.Guarantor_Name__c);
            }

            // Find the reference date. It is either "today" (or the test version) or the Skip Until date.
            Date refDt = System.today();
            if (test.isRunningTest()) {
                refDt = Date.newInstance(TestUtility.currentYear, TestUtility.currentMonth, TestUtility.currentDay);
            }
            if (refDt < plan.Skip_Payment_Until__c) {
                refDt = plan.Skip_Payment_Until__c;
            }

            // Figure out the next payment date relative to the reference date.
            Date nextDt;
            if (plan.Plan_Type__c == 'Automatic') {
                //System.assert(plan.Execute_on_Day__c != null);
                if (plan.Execute_on_Day__c == null) {
                    plan.Execute_on_Day__c = 0;
                }

                // The next payment is due on the Execute Day of the month.
                nextDt = Date.newInstance(refDt.year(), refDt.month(), integer.valueof(plan.Execute_on_Day__c));

                // Keep adding months until the next payment date is past the reference date.
                while (nextDt < refDt) {
                    nextDt = nextDt.addMonths(1);
                }
            } else {
                //System.assert(guarantor.Invoice_Offset_Date__c != null);
                if (guarantor.Invoice_Offset_Date__c == null) {
                    guarantor.Invoice_Offset_Date__c = 0;
                }

                // The next payment is due 21 days beyond the statement date.
                // Start with last month's statement date.
                nextDt = Date.newInstance(refDt.year(), refDt.month() - 1, integer.valueof(guarantor.Invoice_Offset_Date__c) + 21);

                // Keep adding months until the next payment date is past the reference date.
                while (nextDt < refDt) {
                    nextDt = Date.newInstance(nextDt.year(), nextDt.month() + 1, integer.valueof(guarantor.Invoice_Offset_Date__c) + 21);
                }
            }
            plan.NextPaymentDate__c = nextDt;
            if (!fromPaymentPlanTrigger) newListToUpdate.add(plan);
        }
        if (newListToUpdate.size() > 0) update newListToUpdate;
    }

    //Sirono 08-22-2016 : 127401841 Create a Delinquent Payment Plan Case
    Private static void callDelinquentPaymentPlanCaseCreation(List<test__c> newList, Map<Id, test__c> oldMap) {
        Set<Id> contactToCreateCaseIds = new Set<Id>();
        Set<Id> contactToCloseCase = new Set<Id>();
        Set<Id> paymentPlanID = new Set<Id>();
        for (test__c plan : newList) {
            if (trigger.IsInsert && plan.Guarantor_Name__c != null && plan.active__c == true && plan.Delinquent__c == true) {
                contactToCreateCaseIds .add(plan.Guarantor_Name__c);
            } else if (trigger.IsUpdate && plan.Guarantor_Name__c != null && (plan.active__c == true && plan.Delinquent__c == true && (oldMap.get(plan.id).active__c == false || oldMap.get(plan.id).Delinquent__c == false))) {
                contactToCreateCaseIds.add(plan.Guarantor_Name__c);
            }

            if (trigger.IsUpdate && plan.Guarantor_Name__c != null && ((plan.active__c == false && oldMap.get(plan.id).active__c == true) || (plan.Delinquent__c == false && oldMap.get(plan.id).Delinquent__c == true))) {
                contactToCloseCase.add(plan.Guarantor_Name__c);
                paymentPlanID.add(plan.Id);
            }
        }

        if (contactToCreateCaseIds.Size() > 0) {
            CaseUtil.createDelinquentPaymentCase(contactToCreateCaseIds);
        }

        if (contactToCloseCase.Size() > 0) {
            CaseUtil.closeDelinquentPaymentCase(contactToCloseCase, paymentPlanID);
        }
    }

    //Sirono 08-25-2016 : 127517003 Credit Card Error Case Creation and Closure.
    Private static void callCCErrorCaseCreation(List<test__c> newList, Map<Id, test__c> oldMap) {
        Set<Id> contactToCreateCaseIds = new Set<Id>();
        Set<Id> contactToCloseCase = new Set<Id>();
        Set<Id> paymentPlanID = new Set<Id>();

        for (test__c plan : newList) {
            if (trigger.isInsert && plan.Plan_Type__c == 'Automatic' && plan.Has_Error__c == true
                    && plan.Active__c == true && plan.Payable_Amount__c <= -100) {
                contactToCreateCaseIds.add(plan.Guarantor_Name__c);
            } else if (trigger.IsUpdate && plan.Guarantor_Name__c != null
                    && (plan.active__c == true && plan.Has_Error__c == true
                    && plan.Payable_Amount__c <= -100 && plan.Plan_Type__c == 'Automatic' &&
                    (oldMap.get(plan.id).active__c == false || oldMap.get(plan.id).Has_Error__c == false || plan.Payable_Amount__c != oldMap.get(plan.id).Payable_Amount__c || plan.Plan_Type__c != oldMap.get(plan.id).Plan_Type__c
                    ))) {
                contactToCreateCaseIds.add(plan.Guarantor_Name__c);
            }
            if (trigger.IsUpdate && ((plan.Has_Error__c == false && oldMap.get(plan.Id).Has_Error__c != plan.Has_Error__c) || (plan.Active__c == false && oldMap.get(plan.Id).Active__c != plan.Active__c)
                    || (plan.Payable_Amount__c > -100 && oldMap.get(plan.Id).Payable_Amount__c != plan.Payable_Amount__c)
                    || (plan.Plan_Type__c != 'Automatic' && oldMap.get(plan.Id).Plan_Type__c != plan.Plan_Type__c)
            )) {
                contactToCloseCase.add(plan.Guarantor_Name__c);
                paymentPlanID.add(plan.Id);
            }
        }

        if (contactToCreateCaseIds.Size() > 0) {
            CaseUtil.createCCErrorCase(contactToCreateCaseIds);
        }

        if (contactToCloseCase.Size() > 0) {
            CaseUtil.closeCCErrorCase(contactToCloseCase, paymentPlanID);
        }
    }


}