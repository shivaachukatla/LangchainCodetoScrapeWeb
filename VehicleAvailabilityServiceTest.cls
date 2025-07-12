@IsTest
public class VehicleAvailabilityServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create complete test dataset with multiple records
        Map<String, Object> testData = VehicleAvailabilityTestDataFactory.createCompleteTestDataset();
    }
    
    // Test 1: Choose search filters - Load vehicle models and locations
    @IsTest
    static void testGetVehicleModelsAndLocations() {
        Test.startTest();
        
        VehicleAvailabilityService.VehicleModelsAndLocationsWrapper result = 
            VehicleAvailabilityService.getVehicleModelsAndLocations();
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(3, result.vehicleModels.size(), 'Should return 3 vehicle models');
        System.assertEquals(3, result.locations.size(), 'Should return 3 locations');
        
        // Verify vehicle model data
        VehicleAvailabilityService.VehicleModelInfo modelInfo = result.vehicleModels[0];
        System.assertEquals('Ford Mustang Electric', modelInfo.vehicleModelName, 'Model name should match');
        System.assertNotEquals(null, modelInfo.carImage, 'Car image should not be null');
        
        // Verify location data
        VehicleAvailabilityService.LocationInfo locationInfo = result.locations[0];
        System.assertEquals('Austin', locationInfo.locationName, 'Location name should match');
    }
    
    // Test 2: Search vehicle availability
    @IsTest
    static void testGetVehicleAvailability() {
        Test.startTest();
        
        DateTime startDate = DateTime.now().addDays(1);
        DateTime endDate = DateTime.now().addDays(8); // 7 days apart
        
        List<Map<String, Object>> result = VehicleAvailabilityService.getVehicleAvailability(
            startDate, endDate, 'Ford Mustang Electric', 'Austin'
        );
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(3, result.size(), 'Should return 3 vehicles for Austin location');
        
        // Verify all vehicles are from the correct model and location
        for (Map<String, Object> vehicle : result) {
            System.assertEquals('Ford Mustang Electric', vehicle.get('VehicleName').toString().substring(0, 20), 'Vehicle should be Ford Mustang Electric');
        }
    }
    
    @IsTest
    static void testGetVehicleAvailabilityWithConflict() {
        Test.startTest();
        
        DateTime startDate = DateTime.now().addDays(1);
        DateTime endDate = DateTime.now().addDays(8); // 7 days apart
        
        List<Map<String, Object>> result = VehicleAvailabilityService.getVehicleAvailability(
            startDate, endDate, 'Tesla Model S', 'Dallas'
        );
        
        Test.stopTest();
        
        // Should return vehicles but some may be unavailable due to conflicts
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(0, result.size(), 'Should return vehicles');
        
        // Check if any vehicles are unavailable
        Boolean hasUnavailableVehicles = false;
        for (Map<String, Object> vehicle : result) {
            if (!(Boolean) vehicle.get('IsAvailable')) {
                hasUnavailableVehicles = true;
                break;
            }
        }
        
        System.assert(hasUnavailableVehicles, 'Should have some unavailable vehicles due to conflicts');
    }
    
    // Test 4: Display selected vehicle along with calendar view
    @IsTest
    static void testGetVehicleAvailabilityForMonth() {
        // Get a vehicle without conflicts
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c WHERE Name LIKE '%VH-001%' LIMIT 1];
        
        Test.startTest();
        
        String monthYear = Date.today().year() + '-' + String.valueOf(Date.today().month()).leftPad(2, '0');
        List<Map<String, Object>> result = VehicleAvailabilityService.getVehicleAvailabilityForMonth(
            vehicle.Id, monthYear
        );
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(0, result.size(), 'Should return availability data for the month');
        
        // Verify each day has availability info
        for (Map<String, Object> dayInfo : result) {
            System.assertNotEquals(null, dayInfo.get('date'), 'Date should not be null');
            System.assertNotEquals(null, dayInfo.get('isAvailable'), 'Availability should not be null');
        }
    }
    
    @IsTest
    static void testGetVehicleAvailabilityForMonthWithMultipleLeases() {
        // Get a vehicle that has multiple leases
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c WHERE Name LIKE '%VH-004%' LIMIT 1];
        
        Test.startTest();
        
        String monthYear = Date.today().year() + '-' + String.valueOf(Date.today().month()).leftPad(2, '0');
        List<Map<String, Object>> result = VehicleAvailabilityService.getVehicleAvailabilityForMonth(
            vehicle.Id, monthYear
        );
        
        Test.stopTest();
        
        // Should have some unavailable dates due to multiple leases
        Boolean hasUnavailableDates = false;
        for (Map<String, Object> dayInfo : result) {
            if (!(Boolean) dayInfo.get('isAvailable')) {
                hasUnavailableDates = true;
                break;
            }
        }
        
        System.assert(hasUnavailableDates, 'Should have unavailable dates due to multiple leases');
    }
    
    // Test 5: Contact search functionality
    @IsTest
    static void testSearchContacts() {
        Test.startTest();
        
        List<Contact> result = VehicleAvailabilityService.searchContacts('John');
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'Should return one contact');
        System.assertEquals('John Doe', result[0].Name, 'Contact name should match');
    }
    
    @IsTest
    static void testSearchContactsWithMultipleResults() {
        Test.startTest();
        
        List<Contact> result = VehicleAvailabilityService.searchContacts('test.com');
        
        Test.stopTest();
        
        // Should return all 5 contacts since they all have @test.com email
        System.assertEquals(5, result.size(), 'Should return all contacts with test.com email');
    }
    
    @IsTest
    static void testSearchContactsWithShortTerm() {
        Test.startTest();
        
        List<Contact> result = VehicleAvailabilityService.searchContacts('Jo');
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(0, result.size(), 'Should return no results for short search term');
    }
    
    @IsTest
    static void testSearchContactsWithEmail() {
        Test.startTest();
        
        List<Contact> result = VehicleAvailabilityService.searchContacts('john.doe@test.com');
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, result.size(), 'Should return contact by email');
        System.assertEquals('john.doe@test.com', result[0].Email, 'Email should match');
    }
    
    // Test 6: Book vehicle
    @IsTest
    static void testCreateLease() {
        // Get test data
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        
        Test.startTest();
        
        Map<String, Object> leaseData = new Map<String, Object>{
            'vehicleId' => vehicle.Id,
            'contactId' => contact.Id,
            'startDate' => Date.today().addDays(15).format(), // Future date
            'endDate' => Date.today().addDays(22).format()    // 7 days later
        };
        
        Map<String, Object> result = VehicleAvailabilityService.createLease(JSON.serialize(leaseData));
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, result.get('success'), 'Lease creation should be successful');
        System.assertNotEquals(null, result.get('leaseId'), 'Lease ID should be returned');
        System.assertNotEquals(null, result.get('leaseNumber'), 'Lease number should be returned');
        
        // Verify lease record was created
        List<Lease__c> leases = [SELECT Id, Status__c FROM Lease__c WHERE Id = :(String)result.get('leaseId')];
        System.assertEquals(1, leases.size(), 'Lease record should be created');
        System.assertEquals('Temporary Block', leases[0].Status__c, 'Status should be Temporary Block');
    }
    
    @IsTest
    static void testCreateLeaseWithConflict() {
        // Get test data
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c WHERE Name LIKE '%VH-002%' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'Jane' LIMIT 1];
        
        Test.startTest();
        
        Map<String, Object> leaseData = new Map<String, Object>{
            'vehicleId' => vehicle.Id,
            'contactId' => contact.Id,
            'startDate' => Date.today().addDays(1).format(), // Conflicts with existing lease
            'endDate' => Date.today().addDays(8).format()    // 7 days later
        };
        
        Map<String, Object> result = VehicleAvailabilityService.createLease(JSON.serialize(leaseData));
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(false, result.get('success'), 'Lease creation should fail due to conflict');
        System.assertNotEquals(null, result.get('message'), 'Error message should be returned');
    }
    
    @IsTest
    static void testCreateLeaseWithPastStartDate() {
        // Get test data
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c WHERE Name LIKE '%VH-001%' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        
        Test.startTest();
        
        Map<String, Object> leaseData = new Map<String, Object>{
            'vehicleId' => vehicle.Id,
            'contactId' => contact.Id,
            'startDate' => Date.today().addDays(-1).format(), // Past date
            'endDate' => Date.today().addDays(6).format()     // 7 days later
        };
        
        Map<String, Object> result = VehicleAvailabilityService.createLease(JSON.serialize(leaseData));
        
        Test.stopTest();
        
        // Assertions - This should fail due to past start date
        System.assertEquals(false, result.get('success'), 'Lease creation should fail with past start date');
        System.assertNotEquals(null, result.get('message'), 'Error message should be returned');
    }
    
    @IsTest
    static void testCreateLeaseWithLessThan7Days() {
        // Get test data
        Vehicle__c vehicle = [SELECT Id FROM Vehicle__c WHERE Name LIKE '%VH-001%' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        
        Test.startTest();
        
        Map<String, Object> leaseData = new Map<String, Object>{
            'vehicleId' => vehicle.Id,
            'contactId' => contact.Id,
            'startDate' => Date.today().addDays(1).format(),
            'endDate' => Date.today().addDays(5).format() // Less than 7 days
        };
        
        Map<String, Object> result = VehicleAvailabilityService.createLease(JSON.serialize(leaseData));
        
        Test.stopTest();
        
        // Assertions - This should fail due to less than 7 days
        System.assertEquals(false, result.get('success'), 'Lease creation should fail with less than 7 days');
        System.assertNotEquals(null, result.get('message'), 'Error message should be returned');
    }
    
    // Exception Tests
    @IsTest
    static void testCreateLeaseWithInvalidData() {
        Test.startTest();
        
        Map<String, Object> result = VehicleAvailabilityService.createLease('invalid json data');
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(false, result.get('success'), 'Should fail with invalid data');
        System.assertNotEquals(null, result.get('message'), 'Error message should be returned');
    }
    
    @IsTest
    static void testCreateLeaseWithMissingFields() {
        Test.startTest();
        
        Map<String, Object> leaseData = new Map<String, Object>{
            'vehicleId' => 'invalid-id'
        };
        
        Map<String, Object> result = VehicleAvailabilityService.createLease(JSON.serialize(leaseData));
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(false, result.get('success'), 'Should fail with missing fields');
        System.assertNotEquals(null, result.get('message'), 'Error message should be returned');
    }
    
    @IsTest
    static void testGetVehicleAvailabilityForMonthWithInvalidVehicleId() {
        Test.startTest();
        
        List<Map<String, Object>> result = VehicleAvailabilityService.getVehicleAvailabilityForMonth(
            'invalid-id', '2024-01'
        );
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Should return empty list for invalid vehicle ID');
        System.assertEquals(0, result.size(), 'Should return no availability data');
    }
    
    @IsTest
    static void testSearchContactsWithNullTerm() {
        Test.startTest();
        
        List<Contact> result = VehicleAvailabilityService.searchContacts(null);
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(0, result.size(), 'Should return no results for null search term');
    }
    
    @IsTest
    static void testGetVehicleAvailabilityWithInvalidModel() {
        Test.startTest();
        
        DateTime startDate = DateTime.now().addDays(1);
        DateTime endDate = DateTime.now().addDays(8); // 7 days apart
        
        List<Map<String, Object>> result = VehicleAvailabilityService.getVehicleAvailability(
            startDate, endDate, 'Invalid Model', 'Austin'
        );
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(0, result.size(), 'Should return no vehicles for invalid model');
    }
    
    @IsTest
    static void testGetVehicleAvailabilityWithInvalidLocation() {
        Test.startTest();
        
        DateTime startDate = DateTime.now().addDays(1);
        DateTime endDate = DateTime.now().addDays(8); // 7 days apart
        
        List<Map<String, Object>> result = VehicleAvailabilityService.getVehicleAvailability(
            startDate, endDate, 'Ford Mustang Electric', 'Invalid Location'
        );
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(0, result.size(), 'Should return no vehicles for invalid location');
    }
}