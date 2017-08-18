/*
 * Copyright (c) 2017-present Sirono LLC, All rights reserved
 */

@IsTest
private class EncounterWrapperTest {
    public static final String GUARANTOR_CONTACT_ONE = 'guarantorContact1';
    public static final String GUARANTOR_CONTACT_TWO = 'guarantorContact2';

    @TestSetup
    public static void setup() {
        // Create Guarantor Contact records.
        Contact guarantorContact1 = TestUtility.generateGuarantorContactByName(GUARANTOR_CONTACT_ONE);
        Contact guarantorContact2 = TestUtility.generateGuarantorContactByName(GUARANTOR_CONTACT_TWO);
        List<Contact> guarantorContactList = new List<Contact> { guarantorContact1, guarantorContact2 };
        insert guarantorContactList;

        // Create Encounter record.
        Encounter__c encounter1 = TestUtility.generateEncounter(guarantorContact1.Id, 500, System.today());
        Encounter__c encounter2 = TestUtility.generateEncounter(guarantorContact2.Id, 1000, System.today());
        List<Encounter__c> encounterList = new List<Encounter__c> { encounter1, encounter2 };
        insert encounterList;

        // Check system asserts.
        System.assertEquals(encounterList[0].Guarantor__c, guarantorContact1.Id, 'Expected ' + encounterList[0].Guarantor__c + ' but we got ' + guarantorContact1.Id);
        System.assertEquals(GUARANTOR_CONTACT_ONE, guarantorContactList[0].LastName, 'Expected guarantor name is ' + GUARANTOR_CONTACT_ONE + ' but we got ' + guarantorContactList[0].LastName);
    }

    /**
     * This method is used to test EncounterWrapper.buildList method with Guarantor Id
     **/
    static testMethod void testBuildList() {
        Test.startTest();
        List<Encounter__c> encounterList = [SELECT Id, Patient_Portion__c FROM Encounter__c WHERE Patient_Portion__c = 500];
        List<EncounterWrapper> encounterWrapperList = EncounterWrapper.buildList(encounterList);
        // Check that EncounterWrapper List is not empty
        System.assertEquals(encounterWrapperList.size(), 1);
        // Check that correct encounter was returned
        System.assertEquals(encounterWrapperList[0].en.Patient_Portion__c, 500);
        // Verify that the object is not selected by default.
        System.assertEquals(false, encounterWrapperList[0].isSelected, 'EncoutnerWrapper objects should default to false.');

        encounterList = [SELECT Id, Patient_Portion__c FROM Encounter__c WHERE Patient_Portion__c = 1500];
        List<EncounterWrapper> encounterEmptyWrapperList = EncounterWrapper.buildList(encounterList);
        // Check that EncounterWrapper List is empty
        System.assertEquals(encounterEmptyWrapperList.size(), 0);

        Test.stopTest();
    }
}