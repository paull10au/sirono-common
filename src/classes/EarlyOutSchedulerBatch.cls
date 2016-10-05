/*
 * @author Sirono
 * @version 1.0.1
 * @Date: 06-02-2016
 * @EarlyOutSchedulerBatch class.
 
 * ADDITION: any {Invoice}.{Invoice Date} + 50 = Today and 
 * {Guarantor}.{Overdue Balance} < 0 and 
 * {Guarantor}.{Overdue Balance} + {Guarantor}.{Delinquent Balance} <= -100 and
 * {Guarantor}.{Overdue Balance} + {Guarantor}.{Delinquent Balance} > -5000 and
 * Count({Guarantor}.{Statement}.{Date} >= {Invoice}.{Invoice Date}) > 0

 * Sirono : 08-30-2016 - #128375287 Update Salesforce Campaign Names

*/
public with sharing class EarlyOutSchedulerBatch implements Database.Batchable<sObject>, Schedulable, Database.Stateful {
    public Campaign callList;
    public Set<Id> existingMembers;

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new EarlyOutSchedulerBatch(), 200);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        //Sirono : 08-30-2016 - #128375287 Update Salesforce Campaign Names
        Map<String, String> mapCampaignMapping = CaseUtil.campaignMapping(new Set<String>{
                'Early-out'
        });
        string earlyOut = mapCampaignMapping.get('Early-out');

        for (Campaign cl : [Select Id, Name From Campaign Where Name = :earlyOut and isActive = true]) {
            callList = cl;
        }
        if (callList != null) {
            existingMembers = new Set<Id>();
            for (CampaignMember cm : [
                    Select Id, ContactId
                    From CampaignMember
                    Where CampaignId = :callList.Id
                    AND ContactId != null
            ]) {
                existingMembers.add(cm.ContactId);
            }

            return Database.getQueryLocator([
                    Select Id, FirstName, LastName
                    From Contact
                    Where RecordType.Name = 'Guarantor'
                    AND ID NOT IN :existingMembers
            ]);
        } else {
            return Database.getQueryLocator([
                    Select Id, FirstName
                    From Contact
                    Where RecordType.Name = 'Guarantor-DO-NOT-EXIST'
            ]);
        }
    }

    //Adding Guarantors based on their overdue balance and creates to new CampaignMember list 
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        List<Contact> guarantors = (List<Contact>) scope;
        Map<Id, Contact> guarantorMap = new Map<Id, Contact>([
                Select Id, (
                        Select Id, Name, Statement_Date__c
                        From Statements__r
                        Order By Statement_Date__c DESC
                        Limit 1
                )
                From Contact
                Where Id IN :guarantors
        ]);
        Date dt = System.today().addDays(-50);
        if (callList != null) {
            List<CampaignMember> memberList = new List<CampaignMember>();
            for (Invoice__c invoice : [
                    Select Id, Name, Guarantor_Name__c, Invoice_Date__c,
                            Guarantor_Name__r.Overdue_Balance__c, Guarantor_Name__r.Delinquent_Balance__c
                    From Invoice__c
                    WHERE Guarantor_Name__c IN :guarantors
                    AND Invoice_Date__c = :dt
            ]) {
                Double bal = invoice.Guarantor_Name__r.Overdue_Balance__c + invoice.Guarantor_Name__r.Delinquent_Balance__c;
                if (invoice.Guarantor_Name__r.Overdue_Balance__c < 0 && bal <= -100 && bal > -5000
                        && guarantorMap.containsKey(invoice.Guarantor_Name__c)
                        && guarantorMap.get(invoice.Guarantor_Name__c).Statements__r != null
                        && guarantorMap.get(invoice.Guarantor_Name__c).Statements__r.size() != 0
                        && guarantorMap.get(invoice.Guarantor_Name__c).Statements__r.get(0).Statement_Date__c > invoice.Invoice_Date__c
                        && !existingMembers.contains(invoice.Guarantor_Name__c)) {
                    existingMembers.add(invoice.Guarantor_Name__c);
                    memberList.add(new CampaignMember(CampaignId = callList.Id,
                            ContactId = invoice.Guarantor_Name__c, Status = 'Sent'));
                }
            }

            if (memberList.size() > 0) {
                insert memberList;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {

    }
}