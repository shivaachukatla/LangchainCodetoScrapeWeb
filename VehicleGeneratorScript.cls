public with sharing class VehicleGeneratorScript {
    public static void VehicleGenerator() {
        // Execute in Developer Console Anonymous Window

            System.debug('🚀 Starting Vehicle generation...');

            // Location IDs (5 locations)
            List<String> locationIds = new List<String>{
                '131Ki000000sYE2IAM',
                '131Ki000000sYE3IAM', 
                '131Ki000000sYE4IAM',
                '131Ki000000sYDxIAM',
                '131Ki000000sYDyIAM'
            };

            // Vehicle Model IDs (5 models)
            List<String> vehicleModelIds = new List<String>{
                'a0jKi0000004vz0IAA',
                'a0jKi0000004vz1IAA',
                'a0jKi0000004vz5IAA',
                'a0jKi0000004vzAIAQ',
                'a0jKi0000004vzFIAQ'
            };

            // Generate Vehicle records
            List<Vehicle__c> vehiclesToInsert = new List<Vehicle__c>();
            Integer vinCounter = 1;

            System.debug('📊 Generating vehicles: 5 locations × 5 models × 40 vehicles = 1,000 total');

            // For each location
            for (String locationId : locationIds) {
                // For each vehicle model
                for (String vehicleModelId : vehicleModelIds) {
                    // Create 40 vehicles for this location-model combination
                    for (Integer vehicleNum = 1; vehicleNum <= 40; vehicleNum++) {
                        Vehicle__c vehicle = new Vehicle__c(
                            Location__c = locationId,
                            Vehicle_Model__c = vehicleModelId,
                            Status__c = 'Active',
                            Vin__c = 'VIN' + String.valueOf(vinCounter).leftPad(10, '0')
                        );
                        
                        vehiclesToInsert.add(vehicle);
                        vinCounter++;
                    }
                }
            }

            System.debug('📦 Created ' + vehiclesToInsert.size() + ' vehicle records in memory');

            // Bulk insert all vehicles
            try {
                insert vehiclesToInsert;
                System.debug('✅ Successfully inserted ' + vehiclesToInsert.size() + ' vehicles');
                
                // Quick verification query
                Integer actualCount = [SELECT COUNT() FROM Vehicle__c WHERE Location__c IN :locationIds];
                System.debug('🔍 Verification: Found ' + actualCount + ' total vehicles in specified locations');
                
            } catch (Exception e) {
                System.debug('❌ Error inserting vehicles: ' + e.getMessage());
                System.debug('📋 First failed record location: ' + vehiclesToInsert[0].Location__c);
                System.debug('📋 First failed record model: ' + vehiclesToInsert[0].Vehicle_Model__c);
            }

            System.debug('🎉 Vehicle generation completed!');
            System.debug('📋 VIN range: VIN0000000001 to VIN0000001000');
    }
}