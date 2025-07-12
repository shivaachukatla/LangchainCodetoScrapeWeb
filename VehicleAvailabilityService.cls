public class VehicleAvailabilityService {
   
    // Wrapper class to hold both vehicle models and locations
    public class VehicleModelsAndLocationsWrapper {
        @AuraEnabled public List<VehicleModelInfo> vehicleModels;
        @AuraEnabled public List<LocationInfo> locations;
        
        public VehicleModelsAndLocationsWrapper(List<VehicleModelInfo> vehicleModels, List<LocationInfo> locations) {
            this.vehicleModels = vehicleModels;
            this.locations = locations;
        }
    }

    // Wrapper class for vehicle model information
    public class VehicleModelInfo {
        @AuraEnabled public String vehicleModelId;
        @AuraEnabled public String vehicleModelName;
        @AuraEnabled public String carImage;
        
        public VehicleModelInfo(String vehicleModelId, String vehicleModelName, String carImage) {
            this.vehicleModelId = vehicleModelId;
            this.vehicleModelName = vehicleModelName;
            this.carImage = carImage;
        }
    }

    // Wrapper class for location information
    public class LocationInfo {
        @AuraEnabled public String locationId;
        @AuraEnabled public String locationName;
        
        public LocationInfo(String locationId, String locationName) {
            this.locationId = locationId;
            this.locationName = locationName;
        }
    }

    // 1. Choose search filters - Load vehicle models and locations
    @AuraEnabled(cacheable=true)
    public static VehicleModelsAndLocationsWrapper getVehicleModelsAndLocations() {
        List<VehicleModelInfo> vehicleModelInfos = new List<VehicleModelInfo>();
        List<LocationInfo> locationInfos = new List<LocationInfo>();

        // Query Vehicle Models and associated Locations
        List<Vehicle_Model__c> vehicleModels = [
            SELECT Id, Model_Name__c, Car_Image__c
            FROM Vehicle_Model__c
        ];

        List<SObject> locations = [
            SELECT Id, Name
            FROM Location
        ];

        // Populate vehicle model information
        for (Vehicle_Model__c model : vehicleModels) {
            vehicleModelInfos.add(new VehicleModelInfo(
                model.Id,
                model.Model_Name__c,
                model.Car_Image__c
            ));
        }
        
        // Populate location information
        for (SObject location : locations) {
            locationInfos.add(new LocationInfo(
                (String)location.get('Id'),
                (String)location.get('Name')
            ));
        }

        return new VehicleModelsAndLocationsWrapper(vehicleModelInfos, locationInfos);
    }

    // 2. Search vehicle availability
    @AuraEnabled
    public static List<Map<String, Object>> getVehicleAvailability(DateTime startDate, DateTime endDate, String modelName, String locationName) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        
        // Debug: Print input parameters
        System.debug('Search Start Date: ' + startDate.date());
        System.debug('Search End Date: ' + endDate.date());
        System.debug('Model Name: ' + modelName);
        System.debug('Location Name: ' + locationName);
        
        List<Vehicle__c> vehicles = [
            SELECT Id, Name, Location__r.Name, Vehicle_Model__r.Model_Name__c, Vehicle_Model__r.Car_Image__c, Vehicle_Model__r.Hourly_Rate__c 
            FROM Vehicle__c 
            WHERE Vehicle_Model__r.Model_Name__c =:modelName 
            AND Location__r.Name = :locationName
        ];
        
        Set<Id> vehicleIds = new Map<Id, Vehicle__c>(vehicles).keySet();
        
        List<Lease__c> conflictingLeases = [
            SELECT Vehicle__c, Start_Date__c, End_Date__c, Status__c
            FROM Lease__c 
            WHERE Vehicle__c IN :vehicleIds
            AND Status__c IN ('Confirmed', 'Reserved','Temporary Block')
            AND (
                (Start_Date__c <= :endDate.date() 
                AND End_Date__c >= :startDate.date())
            )
        ];
        
        Set<Id> unavailableVehicles = new Set<Id>();
        for (Lease__c lease : conflictingLeases) {
            unavailableVehicles.add(lease.Vehicle__c);
        }
        
        // Debug: Print final results
        for (Vehicle__c vehicle : vehicles) {
            Boolean isAvailable = !unavailableVehicles.contains(vehicle.Id);
            System.debug('Vehicle: ' + vehicle.Name + ' - Available: ' + isAvailable);
            
            results.add(new Map<String, Object>{
                'VehicleId' => vehicle.Id,
                'VehicleName' => vehicle.Name,
                'LocationName' => vehicle.Location__r.Name,
                'IsAvailable' => isAvailable,
                'AvailabilityStatus' => isAvailable ? 'Available' : 'Not Available',
                'CarImage' => vehicle.Vehicle_Model__r.Car_Image__c,
                'HourlyRate' => vehicle.Vehicle_Model__r.Hourly_Rate__c
            });
        }
        
        return results;
    }

    // 4. Display selected vehicle along with calendar view
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getVehicleAvailabilityForMonth(String vehicleId, String monthYear) {
        List<Map<String, Object>> availability = new List<Map<String, Object>>();
        
        // Parse monthYear (format: "2024-01")
        String[] parts = monthYear.split('-');
        Integer year = Integer.valueOf(parts[0]);
        Integer month = Integer.valueOf(parts[1]);
        
        Date startDate = Date.newInstance(year, month, 1);
        Date endDate = startDate.addMonths(1).addDays(-1);
        
        // Query existing leases for this vehicle in the month
        List<Lease__c> existingLeases = [
            SELECT Start_Date__c, End_Date__c, Status__c
            FROM Lease__c 
            WHERE Vehicle__c = :vehicleId
            AND Status__c IN ('Confirmed', 'Reserved', 'Temporary Block')
            AND (
                (Start_Date__c <= :endDate AND End_Date__c >= :startDate)
            )
        ];
        system.debug('at 153 '+existingLeases);
        
        // Create availability map for each day
        for (Integer day = 1; day <= endDate.day(); day++) {
            Date currentDate = Date.newInstance(year, month, day);
            Boolean isAvailable = true;
            
            // Check if any lease conflicts with this date
            for (Lease__c lease : existingLeases) {
                if (currentDate >= lease.Start_Date__c && currentDate <= lease.End_Date__c) {
                    isAvailable = false;
                    break;
                }
            }
            
            availability.add(new Map<String, Object>{
                'date' => currentDate,
                'isAvailable' => isAvailable
            });
        }
        
        return availability;
    }

    // 5. Contact search functionality
    @AuraEnabled(cacheable=true)
    public static List<Contact> searchContacts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 4) {
            return new List<Contact>();
        }
        
        String searchPattern = '%' + searchTerm + '%';
        
        return [
            SELECT Id, Name, Email, Phone
            FROM Contact
            WHERE Name LIKE :searchPattern
            OR Email LIKE :searchPattern
            ORDER BY Name
            LIMIT 10
        ];
    }

    // 6. Book vehicle
    @AuraEnabled
    public static Map<String, Object> createLease(String leaseData) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // Parse the lease data
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(leaseData);
            
            String vehicleId = (String) data.get('vehicleId');
            String contactId = (String) data.get('contactId');
            String startDateStr = (String) data.get('startDate');
            String endDateStr = (String) data.get('endDate');
            
            // Parse dates
            Date startDate = Date.valueOf(startDateStr);
            Date endDate = Date.valueOf(endDateStr);
            
            // Check if vehicle is still available (server-side validation)
            List<Lease__c> existingLeases = [
                SELECT Id 
                FROM Lease__c 
                WHERE Vehicle__c = :vehicleId
                AND Status__c IN ('Confirmed', 'Reserved', 'Temporary Block')
                AND (
                    (Start_Date__c <= :endDate AND End_Date__c >= :startDate)
                )
            ];
            
            if (!existingLeases.isEmpty()) {
                result.put('success', false);
                result.put('message', 'Vehicle is no longer available for the selected dates.');
                return result;
            }
            
            // Create the lease record
            Lease__c newLease = new Lease__c(
                Vehicle__c = vehicleId,
                Contact__c = contactId,
                Start_Date__c = startDate,
                End_Date__c = endDate,
                Status__c = 'Temporary Block',
                Time_for_Temporary_Block__c = 10
            );
            
            insert newLease;

            newLease = [SELECT Id, Name FROM Lease__c WHERE Id = :newLease.Id LIMIT 1];
            
            result.put('success', true);
            result.put('message', 'Vehicle booked successfully!');
            result.put('leaseId', newLease.Id);
            result.put('leaseNumber', newLease.Name);
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('message', 'Error creating lease: ' + e.getMessage());
            System.debug('Error creating lease: ' + e.getMessage());
        }
        
        return result;
    }
}