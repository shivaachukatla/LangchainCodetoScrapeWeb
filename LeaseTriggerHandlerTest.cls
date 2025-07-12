@IsTest
public class LeaseTriggerHandlerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test data using the factory
        Map<String, Object> testData = VehicleAvailabilityTestDataFactory.createCompleteTestDataset();
        
        @SuppressWarnings('unchecked')
        List<Vehicle_Model__c> models = (List<Vehicle_Model__c>) testData.get('models');
        @SuppressWarnings('unchecked')
        List<SObject> locations = (List<SObject>) testData.get('locations');
        @SuppressWarnings('unchecked')
        List<Vehicle__c> vehicles = (List<Vehicle__c>) testData.get('vehicles');
        @SuppressWarnings('unchecked')
        List<Contact> contacts = (List<Contact>) testData.get('contacts');
        @SuppressWarnings('unchecked')
        List<Lease__c> existingLeases = (List<Lease__c>) testData.get('leases');
    }
    
    @IsTest
    static void testBeforeInsertDoubleBookingPrevention_SingleLease() {
        // Get test data
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
        Contact contact1 = contacts[0];
        Contact contact2 = contacts[1];
        
        // Create first lease
        Lease__c firstLease = new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contact1.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(8),
            Status__c = 'Confirmed',
            Time_for_Temporary_Block__c = 10
        );
        insert firstLease;
        
        Test.startTest();
        
        // Try to create overlapping lease - should fail due to double booking
        Lease__c overlappingLease = new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contact2.Id,
            Start_Date__c = Date.today().addDays(5), // Overlaps with first lease
            End_Date__c = Date.today().addDays(12),
            Status__c = 'Temporary Block',
            Time_for_Temporary_Block__c = 10
        );
        
        Boolean exceptionThrown = false;
        String errorMessage = '';
        try {
            insert overlappingLease;
        } catch (DmlException e) {
            exceptionThrown = true;
            errorMessage = e.getMessage();
            System.debug('Double booking error: ' + errorMessage);
        }
        
        Test.stopTest();
        
        // Verify exception was thrown
        System.assert(exceptionThrown, 'Exception should be thrown for double booking in beforeInsert');
        System.assert(errorMessage.contains('Vehicle is already booked'), 
                     'Error message should indicate double booking. Actual message: ' + errorMessage);
        
        // Verify only the first lease exists
        List<Lease__c> allLeases = [SELECT Id FROM Lease__c WHERE Vehicle__c = :vehicle.Id];
        System.assertEquals(1, allLeases.size(), 'Only the first lease should exist after double booking prevention');
    }
    
    @IsTest
    static void testBeforeInsertDoubleBookingPrevention_BulkInsert() {
        // Get test data
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 3];
        List<Vehicle__c> allVehicles = [SELECT Id FROM Vehicle__c LIMIT 2];
        Vehicle__c differentVehicle = allVehicles[1];
        
        // Create first lease
        Lease__c firstLease = new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contacts[0].Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(8),
            Status__c = 'Confirmed',
            Time_for_Temporary_Block__c = 10
        );
        insert firstLease;
        
        Test.startTest();
        
        // Try to create multiple leases, one with conflict
        List<Lease__c> leasesToInsert = new List<Lease__c>();
        
        // Valid lease for different vehicle
        leasesToInsert.add(new Lease__c(
            Vehicle__c = differentVehicle.Id,
            Contact__c = contacts[1].Id,
            Start_Date__c = Date.today().addDays(10),
            End_Date__c = Date.today().addDays(17),
            Status__c = 'Temporary Block',
            Time_for_Temporary_Block__c = 10
        ));
        
        // Conflicting lease for same vehicle
        leasesToInsert.add(new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contacts[2].Id,
            Start_Date__c = Date.today().addDays(5), // Overlaps with first lease
            End_Date__c = Date.today().addDays(12),
            Status__c = 'Temporary Block',
            Time_for_Temporary_Block__c = 10
        ));
        
        Boolean exceptionThrown = false;
        String errorMessage = '';
        try {
            insert leasesToInsert;
        } catch (DmlException e) {
            exceptionThrown = true;
            errorMessage = e.getMessage();
            System.debug('Bulk insert double booking error: ' + errorMessage);
        }
        
        Test.stopTest();
        
        // Verify exception was thrown
        System.assert(exceptionThrown, 'Exception should be thrown for bulk insert with double booking');
        System.assert(errorMessage.contains('Vehicle is already booked'), 
                     'Error message should indicate double booking. Actual message: ' + errorMessage);
        
        // Verify no new leases were created
        List<Lease__c> allLeases = [SELECT Id FROM Lease__c WHERE Vehicle__c = :vehicle.Id];
        System.assertEquals(1, allLeases.size(), 'Only the original lease should exist after bulk insert failure');
    }
    
    @IsTest
    static void testBeforeInsertDoubleBookingPrevention_ExactDateOverlap() {
        // Get test data
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
        Contact contact1 = contacts[0];
        Contact contact2 = contacts[1];
        
        // Create first lease
        Lease__c firstLease = new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contact1.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(8),
            Status__c = 'Reserved',
            Time_for_Temporary_Block__c = 10
        );
        insert firstLease;
        
        Test.startTest();
        
        // Try to create lease with exact same dates
        Lease__c exactOverlapLease = new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contact2.Id,
            Start_Date__c = Date.today().addDays(1), // Exact same start date
            End_Date__c = Date.today().addDays(8),   // Exact same end date
            Status__c = 'Temporary Block',
            Time_for_Temporary_Block__c = 10
        );
        
        Boolean exceptionThrown = false;
        String errorMessage = '';
        try {
            insert exactOverlapLease;
        } catch (DmlException e) {
            exceptionThrown = true;
            errorMessage = e.getMessage();
        }
        
        Test.stopTest();
        
        // Verify exception was thrown
        System.assert(exceptionThrown, 'Exception should be thrown for exact date overlap');
        System.assert(errorMessage.contains('Vehicle is already booked'), 
                     'Error message should indicate double booking. Actual message: ' + errorMessage);
    }
    
    @IsTest
    static void testBeforeInsertDoubleBookingPrevention_PartialOverlap() {
        // Get test data
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
        Contact contact1 = contacts[0];
        Contact contact2 = contacts[1];
        
        // Create first lease
        Lease__c firstLease = new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contact1.Id,
            Start_Date__c = Date.today().addDays(5),
            End_Date__c = Date.today().addDays(12),
            Status__c = 'Temporary Block',
            Time_for_Temporary_Block__c = 10
        );
        insert firstLease;
        
        Test.startTest();
        
        // Try to create lease that starts before but overlaps
        Lease__c partialOverlapLease = new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contact2.Id,
            Start_Date__c = Date.today().addDays(3), // Starts before first lease
            End_Date__c = Date.today().addDays(7),   // Ends during first lease
            Status__c = 'Confirmed',
            Time_for_Temporary_Block__c = 10
        );
        
        Boolean exceptionThrown = false;
        String errorMessage = '';
        try {
            insert partialOverlapLease;
        } catch (DmlException e) {
            exceptionThrown = true;
            errorMessage = e.getMessage();
        }
        
        Test.stopTest();
        
        // Verify exception was thrown
        System.assert(exceptionThrown, 'Exception should be thrown for partial date overlap');
        System.assert(errorMessage.contains('Vehicle is already booked'), 
                     'Error message should indicate double booking. Actual message: ' + errorMessage);
    }
    
    @IsTest
    static void testBeforeInsertDoubleBookingPrevention_NoConflict() {
        // Get test data
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
        Contact contact1 = contacts[0];
        Contact contact2 = contacts[1];
        
        // Create first lease
        Lease__c firstLease = new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contact1.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(8),
            Status__c = 'Confirmed',
            Time_for_Temporary_Block__c = 10
        );
        insert firstLease;
        
        Test.startTest();
        
        // Create second lease with no overlap
        Lease__c noConflictLease = new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contact2.Id,
            Start_Date__c = Date.today().addDays(10), // After first lease ends
            End_Date__c = Date.today().addDays(17),
            Status__c = 'Temporary Block',
            Time_for_Temporary_Block__c = 10
        );
        
        insert noConflictLease;
        
        Test.stopTest();
        
        // Verify both leases exist
        List<Lease__c> allLeases = [SELECT Id FROM Lease__c WHERE Vehicle__c = :vehicle.Id];
        System.assertEquals(2, allLeases.size(), 'Both leases should exist when there is no conflict');
    }
    
    @IsTest
    static void testBeforeInsertDoubleBookingPrevention_DifferentVehicles() {
        // Get test data - use vehicles that don't have existing leases from test setup
        List<Vehicle__c> vehicles = [SELECT Id FROM Vehicle__c LIMIT 2];
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
        
        // Delete any existing leases for these vehicles to start clean
        List<Lease__c> existingLeases = [SELECT Id FROM Lease__c WHERE Vehicle__c IN :vehicles];
        if (!existingLeases.isEmpty()) {
            delete existingLeases;
        }
        
        // Create first lease for first vehicle
        Lease__c firstLease = new Lease__c(
            Vehicle__c = vehicles[0].Id,
            Contact__c = contacts[0].Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(8),
            Status__c = 'Confirmed',
            Time_for_Temporary_Block__c = 10
        );
        insert firstLease;
        
        Test.startTest();
        
        // Create second lease for different vehicle with same dates - should succeed
        Lease__c secondLease = new Lease__c(
            Vehicle__c = vehicles[1].Id,
            Contact__c = contacts[1].Id,
            Start_Date__c = Date.today().addDays(1), // Same dates as first lease
            End_Date__c = Date.today().addDays(8),
            Status__c = 'Temporary Block',
            Time_for_Temporary_Block__c = 10
        );
        
        insert secondLease;
        
        Test.stopTest();
        
        // Verify both leases exist
        List<Lease__c> allLeases = [SELECT Id FROM Lease__c WHERE Id IN (:firstLease.Id, :secondLease.Id)];
        System.assertEquals(2, allLeases.size(), 'Both leases should exist for different vehicles');
    }
    
    @IsTest
    static void testBeforeInsertDoubleBookingPrevention_StatusFiltering() {
        // Get test data
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
        Contact contact1 = contacts[0];
        Contact contact2 = contacts[1];
        
        // Create a lease with status that shouldn't cause conflicts
        Lease__c nonConflictingLease = new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contact1.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(8),
            Status__c = 'Canceled', // Status that shouldn't cause conflicts
            Time_for_Temporary_Block__c = 10
        );
        insert nonConflictingLease;
        
        Test.startTest();
        
        // Try to create overlapping lease - should succeed because first lease is cancelled
        Lease__c overlappingLease = new Lease__c(
            Vehicle__c = vehicle.Id,
            Contact__c = contact2.Id,
            Start_Date__c = Date.today().addDays(5), // Overlaps with cancelled lease
            End_Date__c = Date.today().addDays(12),
            Status__c = 'Temporary Block',
            Time_for_Temporary_Block__c = 10
        );
        
        insert overlappingLease;
        
        Test.stopTest();
        
        // Verify both leases exist
        List<Lease__c> allLeases = [SELECT Id, Status__c FROM Lease__c WHERE Vehicle__c = :vehicle.Id];
        System.assertEquals(2, allLeases.size(), 'Both leases should exist when first lease has non-conflicting status');
    }
}