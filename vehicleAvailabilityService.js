import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getVehicleAvailability from '@salesforce/apex/VehicleAvailabilityService.getVehicleAvailability';
import getVehicleModelsWithLocations from '@salesforce/apex/VehicleAvailabilityService.getVehicleModelsAndLocations';
import searchContacts from '@salesforce/apex/VehicleAvailabilityService.searchContacts';
import createLease from '@salesforce/apex/VehicleAvailabilityService.createLease';
import getVehicleAvailabilityForMonth from '@salesforce/apex/VehicleAvailabilityService.getVehicleAvailabilityForMonth';


export default class VehicleSearch extends LightningElement {
    @track vehicles = [];
    @track paginatedVehicles = [];
    @track error;
    @track isLoading = false;
    @track vehicleModels = [];
    @track locations = [];
    @track selectedVehicle = null;
    @track selectedVehicleId = null;
    @track contactSearchTerm = '';
    @track contactSearchResults = [];
    @track selectedContact = null;
    @track showContactResults = false;
    @track isLoadingContacts = false;
    @track isBooking = false;
    @track leaseRecord = null;
    @track showLeaseConfirmation = false;
    @track vehicleAvailabilityData = [];
    @track showCalendarView = false;

    modelName = '';
    locationName = '';
    startDate = '';
    endDate = '';
    currentPage = 1;
    totalPages = 0;
    itemsPerPage = 5;

    searchTimeout;

    connectedCallback() {
        this.loadVehicleData();
        document.addEventListener('click', this.handleClickOutside.bind(this));
    }
    disconnectedCallback() {
        document.removeEventListener('click', this.handleClickOutside.bind(this));
    }

    // 1. Choose search filters
    handleModelChange(event) {
        this.modelName = event.target.value;
    }

    handleLocationChange(event) {
        this.locationName = event.target.value;
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
        console.log('startDate', this.startDate);
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }

    // 2. Search vehicle availability
    handleSearch() {
        this.isLoading = true;
        this.error = null;
        this.handleClearSelection();
    
        const startDateTime = this.startDate ? new Date(this.startDate + 'T00:00:00').toISOString() : null;
        const endDateTime = this.endDate ? new Date(this.endDate + 'T23:59:59').toISOString() : null;

        getVehicleAvailability({
            startDate: startDateTime,
            endDate: endDateTime,
            modelName: this.modelName,
            locationName: this.locationName
        })
            .then((result) => {
            this.vehicles = result
                .filter(vehicle => vehicle.IsAvailable)
                .map(vehicle => ({
                    VehicleId: vehicle.VehicleId,
                    VehicleName: vehicle.VehicleName,
                    LocationName: vehicle.LocationName,
                    AvailabilityStatus: vehicle.AvailabilityStatus,
                    CarImage: vehicle.CarImage,
                    HourlyRate: vehicle.HourlyRate,
                    vehicleStatusClass: vehicle.IsAvailable ? 'Available' : 'Not-Available'
                }));
            
            // Reset pagination
                this.currentPage = 1;
            this.totalPages = Math.ceil(this.vehicles.length / this.itemsPerPage);
                this.updatePaginatedVehicles();
                this.isLoading = false;
            })
            .catch((error) => {
                this.error = error;
                this.isLoading = false;
            });
    }

    updatePaginatedVehicles() {
        const startIndex = (this.currentPage - 1) * this.itemsPerPage;
        const endIndex = startIndex + this.itemsPerPage;
        this.paginatedVehicles = this.vehicles.slice(startIndex, endIndex);
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePaginatedVehicles();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePaginatedVehicles();
        }
    }

    // 3. Select a vehicle from available list
    handleVehicleSelect(event) {
        const vehicleId = event.currentTarget.dataset.vehicleId;
        this.selectedVehicleId = vehicleId;
        this.selectedVehicle = this.vehicles.find(v => v.VehicleId === vehicleId);
        
        // Auto-show calendar when vehicle is selected
        //this.showCalendarView = true;
        this.fetchVehicleAvailability();
        //this.generateCalendar();
    }

    // 4. Display selected vehicle along with calendar view
    fetchVehicleAvailability() {
        if (!this.selectedVehicleId) return;
        
        const today = new Date();
        const monthYear = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
        
        getVehicleAvailabilityForMonth({
            vehicleId: this.selectedVehicleId,
            monthYear: monthYear
        })
        .then(result => {
            this.vehicleAvailabilityData = result;
            this.generateCalendar();
            // Show calendar AFTER data is loaded and calendar is generated
            this.showCalendarView = true;
        })
        .catch(error => {
            console.error('Error fetching vehicle availability:', error);
            this.vehicleAvailabilityData = [];
            this.generateCalendar();
            // Still show calendar even if data fetch fails
            this.showCalendarView = true;
        });
    }

    generateCalendar() {
        const today = new Date();
        const currentMonth = new Date(today.getFullYear(), today.getMonth(), 1);
        const nextMonth = new Date(today.getFullYear(), today.getMonth() + 1, 1);
        const lastDay = new Date(nextMonth.getTime() - 1);
        
        this.calendarDates = [];
        
        // Add empty cells for days before the first day of the month
        const firstDayOfWeek = currentMonth.getDay();
        for (let i = 0; i < firstDayOfWeek; i++) {
            this.calendarDates.push({
                date: null,
                displayDate: '',
                cssClass: 'calendar-date'
            });
        }
        
        // Add all days of the month
        for (let dayNumber = 1; dayNumber <= lastDay.getDate(); dayNumber++) {
            const date = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), dayNumber);
            const isAvailable = this.checkVehicleAvailability(date);
            const isToday = this.isSameDay(date, today);
            
            let cssClass = 'calendar-date';
            
            if (isToday) {
                cssClass += ' today';
            } else if (isAvailable) {
                cssClass += ' available';
            } else {
                cssClass += ' unavailable';
            }
            
            this.calendarDates.push({
                date: date,
                displayDate: dayNumber.toString(), // Use dayNumber instead of day
                cssClass: cssClass
            });
        }
        
        console.log('Generated calendar dates:', this.calendarDates); // Debug log
    }

    handleToggleCalendar() {
        this.showCalendarView = !this.showCalendarView;
        if (this.showCalendarView) {
            // Generate calendar if it hasn't been generated yet
            if (this.calendarDates.length === 0) {
                this.generateCalendar();
            }
        }
    }

    checkVehicleAvailability(date) {
        if (!this.vehicleAvailabilityData || this.vehicleAvailabilityData.length === 0) {
            return true;
        }
        
        // Create a date string in YYYY-MM-DD format to avoid timezone issues
        const dateString = date.toISOString().split('T')[0];
        
        const availabilityInfo = this.vehicleAvailabilityData.find(item => {
            // Convert Apex date to string format for comparison
            let itemDateString;
            if (typeof item.date === 'string') {
                itemDateString = item.date.split('T')[0]; // Remove time part if present
            } else {
                // If it's a Date object from Apex, convert to string
                const itemDate = new Date(item.date);
                itemDateString = itemDate.toISOString().split('T')[0];
            }
            
            return itemDateString === dateString;
        });
        
        return availabilityInfo ? availabilityInfo.isAvailable : true;
    }

    isSameDay(date1, date2) {
        return date1.getDate() === date2.getDate() &&
            date1.getMonth() === date2.getMonth() &&
            date1.getFullYear() === date2.getFullYear();
    }

    isToday(date) {
        const today = new Date();
        return date.toDateString() === today.toDateString();
    }

    formatCalendarDate(date) {
        return date.getDate();
    }

    // 5. Contact search functionality
    handleContactSearch(event) {
        const searchTerm = event.target.value;
        this.contactSearchTerm = searchTerm;
        
        // Clear previous timeout
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        
        // Hide results if search term is too short
        if (searchTerm.length < 4) {
            this.showContactResults = false;
            this.contactSearchResults = [];
            return;
        }
        
        // Debounce search - wait 300ms after user stops typing
        this.searchTimeout = setTimeout(() => {
            this.performContactSearch(searchTerm);
        }, 300);
    }

    performContactSearch(searchTerm) {
        this.isLoadingContacts = true;
        this.showContactResults = true;

        searchContacts({ searchTerm: searchTerm })
            .then((result) => {
                this.contactSearchResults = result;
            })
            .catch((error) => {
                console.error('Error searching contacts:', error);
                this.contactSearchResults = [];
            })
            .finally(() => {
                this.isLoadingContacts = false;
            });
    }

    handleContactSelect(event) {
        const contactId = event.currentTarget.dataset.contactId;
        const contactName = event.currentTarget.dataset.contactName;
        
        // Find the selected contact from search results
        const selectedContact = this.contactSearchResults.find(contact => contact.Id === contactId);
        
        if (selectedContact) {
            this.selectedContact = selectedContact;
            this.contactSearchTerm = selectedContact.Name;
            this.showContactResults = false;
            this.contactSearchResults = [];
        }
    }

    handleClearContact() {
        this.selectedContact = null;
        this.contactSearchTerm = '';
        this.showContactResults = false;
        this.contactSearchResults = [];
    }

    // 6. Book vehicle
    handleBookVehicle() {
        // Client-side validation
        if (!this.selectedContact) {
            this.showErrorMessage('Please select a contact before booking.');
            return;
        }
    
        if (!this.startDate || !this.endDate) {
            this.showErrorMessage('Please select both start and end dates.');
            return;
        }
    
        // Validate date range
        const startDate = new Date(this.startDate + 'T00:00:00');
        const endDate = new Date(this.endDate + 'T00:00:00');
        
        if (startDate >= endDate) {
            this.showErrorMessage('End date must be after start date.');
            return;
        }
    
        this.isBooking = true;
        this.error = null;
    
        const leaseData = {
            vehicleId: this.selectedVehicle.VehicleId,
            contactId: this.selectedContact.Id,
            startDate: this.startDate,
            endDate: this.endDate
        };
    
        createLease({ leaseData: JSON.stringify(leaseData) })
            .then((result) => {
                if (result.success) {
                    this.leaseRecord = {
                        Id: result.leaseId,
                        Name: result.leaseNumber,
                        VehicleName: this.selectedVehicle.VehicleName,
                        ContactName: this.selectedContact.Name,
                        StartDate: this.formattedStartDate,
                        EndDate: this.formattedEndDate
                    };
                    this.showLeaseConfirmation = true;
                    this.showSuccessMessage('Vehicle booked successfully!');
                } else {
                    this.showErrorMessage(result.message || 'Booking failed. Please try again.');
                }
            })
            .catch((error) => {
                this.showErrorMessage(error.message || 'Booking failed. Please try again.');
            })
            .finally(() => {
                this.isBooking = false;
            });
    }

    // 7. Leased vehicle confirmation
    handleBackToSearch() {
        this.showLeaseConfirmation = false;
        this.leaseRecord = null;
        this.handleClearSelection();
        this.vehicles = [];
        this.paginatedVehicles = [];
    }

    // Supporting methods
    handleClearSelection() {
        // Clear vehicle selection
        this.selectedVehicle = null;
        this.selectedVehicleId = null;
        
        // Clear contact selection
        this.selectedContact = null;
        this.contactSearchTerm = '';
        this.showContactResults = false;
        this.contactSearchResults = [];
        
        // Clear lease confirmation
        this.leaseRecord = null;
        this.showLeaseConfirmation = false;
        
        // Clear any errors
        this.error = null;
    }

    loadVehicleData() {
        this.isLoading = true;

        getVehicleModelsWithLocations()
            .then((result) => {
                this.vehicleModels = result.vehicleModels.map(model => ({
                    label: model.vehicleModelName,
                    value: model.vehicleModelName
                }));

                this.locations = result.locations.map(location => ({
                    label: location.locationName,
                    value: location.locationName
                }));
            })
            .catch((error) => {
                this.error = error;
                console.error('Error fetching vehicle models and locations:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleClickOutside(event) {
        const contactSearchContainer = this.template.querySelector('.contact-search-container');
        if (contactSearchContainer && !contactSearchContainer.contains(event.target)) {
            this.showContactResults = false;
        }
    }

    // Getters
    get formattedStartDate() {
        if (!this.startDate) return 'Not selected';
        // Parse the date string directly without timezone conversion
        const [year, month, day] = this.startDate.split('-');
        return `${month}/${day}/${year}`;
    }

    get formattedEndDate() {
        if (!this.endDate) return 'Not selected';
        const [year, month, day] = this.endDate.split('-');
        return `${month}/${day}/${year}`;
    }

    get rentalDuration() {
        if (!this.startDate || !this.endDate) return 0;
        const start = new Date(this.startDate);
        const end = new Date(this.endDate);
        const diffTime = Math.abs(end - start);
        return Math.ceil(diffTime / (1000 * 60 * 60)); // Convert to hours
    }

    get totalPrice() {
        if (!this.selectedVehicle || !this.rentalDuration) return '0.00';
        const hourlyRate = this.selectedVehicle.HourlyRate || 0;
        const total = hourlyRate * this.rentalDuration;
        return total.toFixed(2);
    }

    get totalVehicles() {
        return this.vehicles.length;
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get isBookingDisabled() {
        return !this.selectedContact || this.isBooking;
    }

    get monthName() {
        const today = new Date();
        const currentMonth = new Date(today.getFullYear(), today.getMonth(), 1);
        return currentMonth.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
    }

    get dayNames() {
        return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    }

    get calendarButtonLabel() {
        return this.showCalendarView ? 'Hide Calendar' : 'Show Calendar';
    }

    get vehicleCardClass() {
        return (vehicle) => {
            const baseClass = 'slds-card slds-card_boundary vehicle-card';
            return vehicle.VehicleId === this.selectedVehicleId 
                ? `${baseClass} selected-vehicle` 
                : baseClass;
        };
    }

    get calendarDateClass() {
        return (calendarDate) => {
            let classes = 'calendar-date';
            if (!calendarDate.date) {
                classes += ' empty';
            } else if (calendarDate.isPast) {
                classes += ' past';
            } else if (calendarDate.isToday) {
                classes += ' today';
            } else if (calendarDate.isAvailable === true) {
                classes += ' available';
            } else if (calendarDate.isAvailable === false) {
                classes += ' unavailable';
            }
            return classes;
        };
    }
    
    get calendarDateTextClass() {
        return (calendarDate) => {
            let classes = 'date-text';
            if (calendarDate.isToday) {
                classes += ' today-text';
            }
            return classes;
        };
    }

    // Utility methods
    showSuccessMessage(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success'
        }));
    }

    showErrorMessage(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }
}