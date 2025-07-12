public class LeaseTriggerHandler {
    
    // Trigger context variables
    private Boolean isExecuting = false;
    private Integer batchSize = 0;
    
    // Constructor
    public LeaseTriggerHandler(Boolean isExecuting, Integer size) {
        this.isExecuting = isExecuting;
        this.batchSize = size;
    }
    
    // Main trigger handler method
    public void run() {
        if (Trigger.isBefore) {
            if (Trigger.isInsert) {
                handleBeforeInsert();
            }
        }
    }
    
    // Before Insert Handler
    private void handleBeforeInsert() {
        validateLeaseDates((List<Lease__c>)Trigger.new);
        checkForDoubleBookings((List<Lease__c>)Trigger.new, null);
    }
    
    
    // Validate lease dates
    private void validateLeaseDates(List<Lease__c> leases) {
        Date today = Date.today();
        
        for (Lease__c lease : leases) {
            // Check if start date is not in the past
            if (lease.Start_Date__c < today) {
                lease.addError('Start Date cannot be in the past. Please select a future date.');
            }
            
            // Check if end date is after start date
            if (lease.End_Date__c <= lease.Start_Date__c) {
                lease.addError('End Date must be after Start Date.');
            }
            
            // Check if lease duration is at least 7 days
            Integer daysDifference = lease.Start_Date__c.daysBetween(lease.End_Date__c);
            if (daysDifference < 7) {
                lease.addError('Lease duration must be at least 7 days.');
            }
        }
    }
    
    // Check for double bookings
    private void checkForDoubleBookings(List<Lease__c> leases, Map<Id, Lease__c> oldLeasesMap) {
        // Collect all vehicle IDs and their corresponding leases
        Set<Id> vehicleIds = new Set<Id>();
        Map<Id, List<Lease__c>> vehicleLeasesMap = new Map<Id, List<Lease__c>>();
        
        for (Lease__c lease : leases) {
            if (lease.Vehicle__c != null) {
                vehicleIds.add(lease.Vehicle__c);
                
                if (!vehicleLeasesMap.containsKey(lease.Vehicle__c)) {
                    vehicleLeasesMap.put(lease.Vehicle__c, new List<Lease__c>());
                }
                vehicleLeasesMap.get(lease.Vehicle__c).add(lease);
            }
        }
        
        if (vehicleIds.isEmpty()) {
            return;
        }
        
        // Build the query dynamically based on trigger context
        String query = 'SELECT Id, Vehicle__c, Start_Date__c, End_Date__c, Status__c ' +
                      'FROM Lease__c ' +
                      'WHERE Vehicle__c IN :vehicleIds ' +
                      'AND Status__c IN (\'Confirmed\', \'Reserved\', \'Temporary Block\')';
        
        // Add exclusion for current records only if this is an update operation
        if (Trigger.isUpdate && Trigger.newMap != null) {
            query += ' AND Id NOT IN :Trigger.newMap.keySet()';
        }
        
        List<Lease__c> existingLeases = Database.query(query);
        
        // Group existing leases by vehicle
        Map<Id, List<Lease__c>> existingLeasesByVehicle = new Map<Id, List<Lease__c>>();
        for (Lease__c existingLease : existingLeases) {
            if (!existingLeasesByVehicle.containsKey(existingLease.Vehicle__c)) {
                existingLeasesByVehicle.put(existingLease.Vehicle__c, new List<Lease__c>());
            }
            existingLeasesByVehicle.get(existingLease.Vehicle__c).add(existingLease);
        }
        
        // Check for conflicts for each new lease
        for (Lease__c newLease : leases) {
            if (newLease.Vehicle__c == null) {
                continue;
            }
            
            // Get existing leases for this vehicle
            List<Lease__c> vehicleExistingLeases = existingLeasesByVehicle.get(newLease.Vehicle__c);
            if (vehicleExistingLeases == null) {
                continue;
            }
            
            // Check for date conflicts with existing leases for the same vehicle
            for (Lease__c existingLease : vehicleExistingLeases) {
                if (hasDateConflict(newLease, existingLease)) {
                    String errorMessage = String.format(
                        'Vehicle is already booked from {0} to {1}. Please select different dates.',
                        new List<String>{
                            existingLease.Start_Date__c.format(),
                            existingLease.End_Date__c.format()
                        }
                    );
                    newLease.addError(errorMessage);
                    break; // Stop checking other conflicts for this lease
                }
            }
        }
    }
    
    // Helper method to check if two leases have date conflicts
    private Boolean hasDateConflict(Lease__c lease1, Lease__c lease2) {
        // Check if the date ranges overlap
        // lease1 starts before lease2 ends AND lease1 ends after lease2 starts
        return (lease1.Start_Date__c <= lease2.End_Date__c && lease1.End_Date__c >= lease2.Start_Date__c);
    }
    
    // Utility method to check if trigger should run
    public Boolean shouldRunTrigger() {
        return !isExecuting || batchSize == 1;
    }
    
    // Method to bypass trigger (for testing or bulk operations)
    public static void bypassTrigger() {
        // Implementation for bypassing trigger logic if needed
    }
    
    // Method to enable trigger after bypass
    public static void enableTrigger() {
        // Implementation for re-enabling trigger logic
    }
}