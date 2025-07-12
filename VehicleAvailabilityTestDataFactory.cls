@IsTest
public class VehicleAvailabilityTestDataFactory {
    
    public static List<Vehicle_Model__c> createVehicleModels() {
        List<Vehicle_Model__c> models = new List<Vehicle_Model__c>{
            new Vehicle_Model__c(
                Model_Name__c = 'Ford Mustang Electric',
                Hourly_Rate__c = 50.00,
                Car_Image__c = '<img src="mustang.jpg"/>'
            ),
            new Vehicle_Model__c(
                Model_Name__c = 'Tesla Model S',
                Hourly_Rate__c = 75.00,
                Car_Image__c = '<img src="tesla.jpg"/>'
            ),
            new Vehicle_Model__c(
                Model_Name__c = 'BMW i4',
                Hourly_Rate__c = 60.00,
                Car_Image__c = '<img src="bmw.jpg"/>'
            )
        };
        insert models;
        return models;
    }
    
    public static List<SObject> createLocations() {
        List<SObject> locations = new List<SObject>();
        
        // Create Location records using SObject approach
        SObject austin = Schema.getGlobalDescribe().get('Location').newSObject();
        austin.put('Name', 'Austin');
        locations.add(austin);
        
        SObject dallas = Schema.getGlobalDescribe().get('Location').newSObject();
        dallas.put('Name', 'Dallas');
        locations.add(dallas);
        
        SObject houston = Schema.getGlobalDescribe().get('Location').newSObject();
        houston.put('Name', 'Houston');
        locations.add(houston);
        
        insert locations;
        return locations;
    }
    
    public static List<Vehicle__c> createVehicles(List<Vehicle_Model__c> models, List<SObject> locations) {
        List<Vehicle__c> vehicles = new List<Vehicle__c>();
        
        // Create multiple vehicles for each model-location combination
        for (Vehicle_Model__c model : models) {
            for (SObject location : locations) {
                for (Integer i = 1; i <= 3; i++) {
                    Vehicle__c vehicle = new Vehicle__c();
                    vehicle.Vehicle_Model__c = model.Id;
                    vehicle.Location__c = (Id) location.get('Id');
                    vehicles.add(vehicle);
                }
            }
        }
        
        insert vehicles;
        return vehicles;
    }
    
    public static List<Contact> createContacts() {
        List<Contact> contacts = new List<Contact>{
            new Contact(
                FirstName = 'John',
                LastName = 'Doe',
                Email = 'john.doe@test.com',
                Phone = '555-0101'
            ),
            new Contact(
                FirstName = 'Jane',
                LastName = 'Smith',
                Email = 'jane.smith@test.com',
                Phone = '555-0102'
            ),
            new Contact(
                FirstName = 'Bob',
                LastName = 'Johnson',
                Email = 'bob.johnson@test.com',
                Phone = '555-0103'
            ),
            new Contact(
                FirstName = 'Alice',
                LastName = 'Williams',
                Email = 'alice.williams@test.com',
                Phone = '555-0104'
            ),
            new Contact(
                FirstName = 'Charlie',
                LastName = 'Brown',
                Email = 'charlie.brown@test.com',
                Phone = '555-0105'
            )
        };
        insert contacts;
        return contacts;
    }
    
    public static List<Lease__c> createLeases(List<Vehicle__c> vehicles, List<Contact> contacts) {
        List<Lease__c> leases = new List<Lease__c>();
        
        // Create various lease scenarios with 7-day durations
        Date today = Date.today();
        
        // Current lease (should affect availability) - today to 7 days from today
        leases.add(new Lease__c(
            Vehicle__c = vehicles[1].Id,
            Contact__c = contacts[1].Id,
            Start_Date__c = today.addDays(1),
            End_Date__c = today.addDays(8),
            Status__c = 'Confirmed',
            Time_for_Temporary_Block__c = 10
        ));
        
        // Future lease (should affect availability) - 5 days from today to 12 days from today
        leases.add(new Lease__c(
            Vehicle__c = vehicles[2].Id,
            Contact__c = contacts[2].Id,
            Start_Date__c = today.addDays(5),
            End_Date__c = today.addDays(12),
            Status__c = 'Temporary Block',
            Time_for_Temporary_Block__c = 10
        ));
        
        // Overlapping leases for same vehicle (should create conflicts)
        // First lease: 2 days from today to 9 days from today
        leases.add(new Lease__c(
            Vehicle__c = vehicles[3].Id,
            Contact__c = contacts[3].Id,
            Start_Date__c = today.addDays(2),
            End_Date__c = today.addDays(9),
            Status__c = 'Reserved',
            Time_for_Temporary_Block__c = 10
        ));
        
        // Second lease: 3 days from today to 10 days from today (overlaps with first)
        leases.add(new Lease__c(
            Vehicle__c = vehicles[3].Id,
            Contact__c = contacts[4].Id,
            Start_Date__c = today.addDays(3),
            End_Date__c = today.addDays(10),
            Status__c = 'Confirmed',
            Time_for_Temporary_Block__c = 10
        ));
        
        // Additional lease for testing: 10 days from today to 17 days from today
        leases.add(new Lease__c(
            Vehicle__c = vehicles[4].Id,
            Contact__c = contacts[0].Id,
            Start_Date__c = today.addDays(10),
            End_Date__c = today.addDays(17),
            Status__c = 'Confirmed',
            Time_for_Temporary_Block__c = 10
        ));
        
        insert leases;
        return leases;
    }
    
    // Helper method to create complete test dataset
    public static Map<String, Object> createCompleteTestDataset() {
        List<Vehicle_Model__c> models = createVehicleModels();
        List<SObject> locations = createLocations();
        List<Vehicle__c> vehicles = createVehicles(models, locations);
        List<Contact> contacts = createContacts();
        List<Lease__c> leases = createLeases(vehicles, contacts);
        
        return new Map<String, Object>{
            'models' => models,
            'locations' => locations,
            'vehicles' => vehicles,
            'contacts' => contacts,
            'leases' => leases
        };
    }
}