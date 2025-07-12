import os
import requests
from datetime import datetime, timedelta
from typing import List, Dict, Any
from dataclasses import dataclass
import json
from langchain.agents import initialize_agent, AgentType
from langchain.tools import Tool
from langchain.llms import OpenAI
from langchain.chat_models import ChatOpenAI
from langchain.schema import HumanMessage, SystemMessage
from langchain.prompts import PromptTemplate
from simple_salesforce import Salesforce
from bs4 import BeautifulSoup
import time
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class Event:
    name: str
    date: str
    description: str
    venue: str
    category: str
    url: str
    source: str

class EventScraper:
    def __init__(self, openai_api_key: str, salesforce_credentials: Dict[str, str]):
        """
        Initialize the EventScraper with OpenAI and Salesforce credentials
        
        Args:
            openai_api_key: OpenAI API key for LangChain
            salesforce_credentials: Dictionary containing Salesforce credentials
        """
        self.openai_api_key = openai_api_key
        self.salesforce_credentials = salesforce_credentials
        self.llm = ChatOpenAI(
            temperature=0,
            openai_api_key=openai_api_key,
            model="gpt-4"
        )
        self.sf = None
        self._connect_salesforce()
        
    def _connect_salesforce(self):
        """Connect to Salesforce using the provided credentials"""
        try:
            self.sf = Salesforce(
                username=self.salesforce_credentials['username'],
                password=self.salesforce_credentials['password'],
                security_token=self.salesforce_credentials['security_token'],
                domain=self.salesforce_credentials.get('domain', 'login')
            )
            logger.info("Successfully connected to Salesforce")
        except Exception as e:
            logger.error(f"Failed to connect to Salesforce: {e}")
            raise
    
    def scrape_events_from_web(self, location: str, month: str, year: int) -> List[Event]:
        """
        Scrape events from multiple sources for a given location and month
        
        Args:
            location: City/location name
            month: Month name (e.g., 'January', 'February')
            year: Year (e.g., 2024)
            
        Returns:
            List of Event objects
        """
        events = []
        
        # Define sources to scrape
        sources = [
            self._scrape_eventbrite,
            self._scrape_ticketmaster,
            self._scrape_local_events_sites,
            self._scrape_tripadvisor
        ]
        
        for source_func in sources:
            try:
                source_events = source_func(location, month, year)
                events.extend(source_events)
                logger.info(f"Scraped {len(source_events)} events from {source_func.__name__}")
                time.sleep(2)  # Be respectful to websites
            except Exception as e:
                logger.error(f"Error scraping from {source_func.__name__}: {e}")
                continue
        
        return events
    
    def _scrape_eventbrite(self, location: str, month: str, year: int) -> List[Event]:
        """Scrape events from Eventbrite"""
        events = []
        
        try:
            # Eventbrite search URL
            search_url = f"https://www.eventbrite.com/d/{location}/events/"
            
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.get(search_url, headers=headers, timeout=10)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Extract event information using LangChain
            prompt = PromptTemplate(
                input_variables=["html_content", "location", "month", "year"],
                template="""
                Extract event information from the following HTML content for {location} in {month} {year}.
                Look for event names, dates, descriptions, venues, and categories.
                
                HTML Content:
                {html_content}
                
                Return the events as a JSON array with the following structure:
                [
                    {{
                        "name": "Event Name",
                        "date": "YYYY-MM-DD",
                        "description": "Event description",
                        "venue": "Venue name",
                        "category": "Event category",
                        "url": "Event URL"
                    }}
                ]
                
                Only include events that are clearly happening in {month} {year}.
                """
            )
            
            messages = [
                SystemMessage(content="You are a web scraping assistant that extracts event information from HTML content."),
                HumanMessage(content=prompt.format(
                    html_content=str(soup)[:8000],  # Limit content size
                    location=location,
                    month=month,
                    year=year
                ))
            ]
            
            response = self.llm(messages)
            
            try:
                events_data = json.loads(response.content)
                for event_data in events_data:
                    events.append(Event(
                        name=event_data.get('name', ''),
                        date=event_data.get('date', ''),
                        description=event_data.get('description', ''),
                        venue=event_data.get('venue', ''),
                        category=event_data.get('category', ''),
                        url=event_data.get('url', ''),
                        source='Eventbrite'
                    ))
            except json.JSONDecodeError:
                logger.warning("Failed to parse Eventbrite events JSON")
                
        except Exception as e:
            logger.error(f"Error scraping Eventbrite: {e}")
        
        return events
    
    def _scrape_ticketmaster(self, location: str, month: str, year: int) -> List[Event]:
        """Scrape events from Ticketmaster"""
        events = []
        
        try:
            # Ticketmaster search URL
            search_url = f"https://www.ticketmaster.com/search?q={location}"
            
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.get(search_url, headers=headers, timeout=10)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Use LangChain to extract event information
            prompt = PromptTemplate(
                input_variables=["html_content", "location", "month", "year"],
                template="""
                Extract event information from Ticketmaster HTML content for {location} in {month} {year}.
                Look for concert names, dates, venues, and event details.
                
                HTML Content:
                {html_content}
                
                Return the events as a JSON array with the following structure:
                [
                    {{
                        "name": "Event Name",
                        "date": "YYYY-MM-DD",
                        "description": "Event description",
                        "venue": "Venue name",
                        "category": "Event category",
                        "url": "Event URL"
                    }}
                ]
                
                Only include events that are clearly happening in {month} {year}.
                """
            )
            
            messages = [
                SystemMessage(content="You are a web scraping assistant that extracts event information from Ticketmaster HTML content."),
                HumanMessage(content=prompt.format(
                    html_content=str(soup)[:8000],
                    location=location,
                    month=month,
                    year=year
                ))
            ]
            
            response = self.llm(messages)
            
            try:
                events_data = json.loads(response.content)
                for event_data in events_data:
                    events.append(Event(
                        name=event_data.get('name', ''),
                        date=event_data.get('date', ''),
                        description=event_data.get('description', ''),
                        venue=event_data.get('venue', ''),
                        category=event_data.get('category', ''),
                        url=event_data.get('url', ''),
                        source='Ticketmaster'
                    ))
            except json.JSONDecodeError:
                logger.warning("Failed to parse Ticketmaster events JSON")
                
        except Exception as e:
            logger.error(f"Error scraping Ticketmaster: {e}")
        
        return events
    
    def _scrape_local_events_sites(self, location: str, month: str, year: int) -> List[Event]:
        """Scrape events from local events websites"""
        events = []
        
        # Common local events sites
        local_sites = [
            f"https://www.timeout.com/{location.lower().replace(' ', '-')}/events",
            f"https://www.citysearch.com/{location.lower().replace(' ', '-')}/events",
            f"https://www.yelp.com/events/{location.lower().replace(' ', '-')}"
        ]
        
        for site_url in local_sites:
            try:
                headers = {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                }
                
                response = requests.get(site_url, headers=headers, timeout=10)
                response.raise_for_status()
                
                soup = BeautifulSoup(response.content, 'html.parser')
                
                prompt = PromptTemplate(
                    input_variables=["html_content", "location", "month", "year"],
                    template="""
                    Extract event information from local events website HTML content for {location} in {month} {year}.
                    Look for local events, festivals, community events, and cultural activities.
                    
                    HTML Content:
                    {html_content}
                    
                    Return the events as a JSON array with the following structure:
                    [
                        {{
                            "name": "Event Name",
                            "date": "YYYY-MM-DD",
                            "description": "Event description",
                            "venue": "Venue name",
                            "category": "Event category",
                            "url": "Event URL"
                        }}
                    ]
                    
                    Only include events that are clearly happening in {month} {year}.
                    """
                )
                
                messages = [
                    SystemMessage(content="You are a web scraping assistant that extracts local event information from HTML content."),
                    HumanMessage(content=prompt.format(
                        html_content=str(soup)[:8000],
                        location=location,
                        month=month,
                        year=year
                    ))
                ]
                
                response = self.llm(messages)
                
                try:
                    events_data = json.loads(response.content)
                    for event_data in events_data:
                        events.append(Event(
                            name=event_data.get('name', ''),
                            date=event_data.get('date', ''),
                            description=event_data.get('description', ''),
                            venue=event_data.get('venue', ''),
                            category=event_data.get('category', ''),
                            url=event_data.get('url', ''),
                            source='Local Events'
                        ))
                except json.JSONDecodeError:
                    logger.warning(f"Failed to parse events JSON from {site_url}")
                    
            except Exception as e:
                logger.error(f"Error scraping {site_url}: {e}")
                continue
        
        return events
    
    def _scrape_tripadvisor(self, location: str, month: str, year: int) -> List[Event]:
        """Scrape events from TripAdvisor"""
        events = []
        
        try:
            # TripAdvisor events URL
            search_url = f"https://www.tripadvisor.com/Attractions-g{location.lower().replace(' ', '-')}-Activities-events"
            
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.get(search_url, headers=headers, timeout=10)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            prompt = PromptTemplate(
                input_variables=["html_content", "location", "month", "year"],
                template="""
                Extract event information from TripAdvisor HTML content for {location} in {month} {year}.
                Look for tourist events, cultural activities, and local attractions.
                
                HTML Content:
                {html_content}
                
                Return the events as a JSON array with the following structure:
                [
                    {{
                        "name": "Event Name",
                        "date": "YYYY-MM-DD",
                        "description": "Event description",
                        "venue": "Venue name",
                        "category": "Event category",
                        "url": "Event URL"
                    }}
                ]
                
                Only include events that are clearly happening in {month} {year}.
                """
            )
            
            messages = [
                SystemMessage(content="You are a web scraping assistant that extracts tourist event information from TripAdvisor HTML content."),
                HumanMessage(content=prompt.format(
                    html_content=str(soup)[:8000],
                    location=location,
                    month=month,
                    year=year
                ))
            ]
            
            response = self.llm(messages)
            
            try:
                events_data = json.loads(response.content)
                for event_data in events_data:
                    events.append(Event(
                        name=event_data.get('name', ''),
                        date=event_data.get('date', ''),
                        description=event_data.get('description', ''),
                        venue=event_data.get('venue', ''),
                        category=event_data.get('category', ''),
                        url=event_data.get('url', ''),
                        source='TripAdvisor'
                    ))
            except json.JSONDecodeError:
                logger.warning("Failed to parse TripAdvisor events JSON")
                
        except Exception as e:
            logger.error(f"Error scraping TripAdvisor: {e}")
        
        return events
    
    def process_and_clean_events(self, events: List[Event]) -> List[Event]:
        """
        Process and clean the scraped events using LangChain
        
        Args:
            events: List of raw events
            
        Returns:
            List of cleaned and processed events
        """
        if not events:
            return []
        
        # Convert events to JSON for processing
        events_json = []
        for event in events:
            events_json.append({
                'name': event.name,
                'date': event.date,
                'description': event.description,
                'venue': event.venue,
                'category': event.category,
                'url': event.url,
                'source': event.source
            })
        
        prompt = PromptTemplate(
            input_variables=["events"],
            template="""
            Clean and process the following events data. Remove duplicates, fix formatting issues, 
            standardize dates, and ensure all required fields are present.
            
            Events Data:
            {events}
            
            Return the cleaned events as a JSON array with the following structure:
            [
                {{
                    "name": "Event Name (cleaned)",
                    "date": "YYYY-MM-DD (standardized)",
                    "description": "Event description (cleaned)",
                    "venue": "Venue name (cleaned)",
                    "category": "Event category (standardized)",
                    "url": "Event URL",
                    "source": "Source name"
                }}
            ]
            
            Rules:
            1. Remove duplicate events based on name and date
            2. Standardize date format to YYYY-MM-DD
            3. Clean and truncate descriptions to reasonable length
            4. Standardize venue names
            5. Categorize events into standard categories (Music, Sports, Arts, Food, Business, etc.)
            6. Remove events with missing critical information
            """
        )
        
        messages = [
            SystemMessage(content="You are a data cleaning assistant that processes event information."),
            HumanMessage(content=prompt.format(events=json.dumps(events_json, indent=2)))
        ]
        
        response = self.llm(messages)
        
        try:
            cleaned_events_data = json.loads(response.content)
            cleaned_events = []
            
            for event_data in cleaned_events_data:
                cleaned_events.append(Event(
                    name=event_data.get('name', ''),
                    date=event_data.get('date', ''),
                    description=event_data.get('description', ''),
                    venue=event_data.get('venue', ''),
                    category=event_data.get('category', ''),
                    url=event_data.get('url', ''),
                    source=event_data.get('source', '')
                ))
            
            return cleaned_events
            
        except json.JSONDecodeError:
            logger.error("Failed to parse cleaned events JSON")
            return events  # Return original events if cleaning fails
    
    def update_salesforce_location(self, location_name: str, events: List[Event]) -> bool:
        """
        Update Salesforce Location object with events information
        
        Args:
            location_name: Name of the location
            events: List of events to add to the location
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Query for the Location record
            location_query = f"SELECT Id, Name FROM Location WHERE Name = '{location_name}'"
            location_result = self.sf.query(location_query)
            
            if not location_result['records']:
                logger.warning(f"Location '{location_name}' not found in Salesforce")
                return False
            
            location_id = location_result['records'][0]['Id']
            
            # Prepare events data for Salesforce
            events_data = []
            for event in events:
                events_data.append({
                    'Name': event.name,
                    'Event_Date__c': event.date,
                    'Description__c': event.description[:255] if event.description else '',  # Limit to 255 chars
                    'Venue__c': event.venue,
                    'Category__c': event.category,
                    'Event_URL__c': event.url,
                    'Source__c': event.source,
                    'Location__c': location_id
                })
            
            # Create custom event records (assuming you have a custom Event__c object)
            # If you don't have a custom object, you can store this in a custom field on Location
            try:
                # Try to create Event__c records
                event_results = self.sf.Event__c.create(events_data)
                logger.info(f"Created {len(events_data)} event records for location {location_name}")
            except:
                # If Event__c doesn't exist, store in Location custom field
                events_summary = json.dumps([{
                    'name': event.name,
                    'date': event.date,
                    'venue': event.venue,
                    'category': event.category
                } for event in events[:10]], indent=2)  # Limit to 10 events
                
                # Update Location with events summary
                self.sf.Location.update(location_id, {
                    'Events_Summary__c': events_summary,
                    'Last_Events_Update__c': datetime.now().strftime('%Y-%m-%d')
                })
                logger.info(f"Updated Location {location_name} with events summary")
            
            return True
            
        except Exception as e:
            logger.error(f"Error updating Salesforce Location: {e}")
            return False
    
    def run_event_scraping_for_location(self, location_name: str, month: str, year: int) -> Dict[str, Any]:
        """
        Main method to run the complete event scraping process for a location
        
        Args:
            location_name: Name of the location
            month: Month name
            year: Year
            
        Returns:
            Dictionary with results
        """
        logger.info(f"Starting event scraping for {location_name} in {month} {year}")
        
        try:
            # Step 1: Scrape events from web
            raw_events = self.scrape_events_from_web(location_name, month, year)
            logger.info(f"Scraped {len(raw_events)} raw events")
            
            # Step 2: Process and clean events
            cleaned_events = self.process_and_clean_events(raw_events)
            logger.info(f"Cleaned to {len(cleaned_events)} events")
            
            # Step 3: Update Salesforce Location
            success = self.update_salesforce_location(location_name, cleaned_events)
            
            return {
                'success': success,
                'location': location_name,
                'month': month,
                'year': year,
                'raw_events_count': len(raw_events),
                'cleaned_events_count': len(cleaned_events),
                'events': [{
                    'name': event.name,
                    'date': event.date,
                    'venue': event.venue,
                    'category': event.category,
                    'source': event.source
                } for event in cleaned_events]
            }
            
        except Exception as e:
            logger.error(f"Error in event scraping process: {e}")
            return {
                'success': False,
                'error': str(e),
                'location': location_name,
                'month': month,
                'year': year
            }

# Example usage
def main():
    # Configuration
    OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
    SALESFORCE_CREDENTIALS = {
        'username': os.getenv('SALESFORCE_USERNAME'),
        'password': os.getenv('SALESFORCE_PASSWORD'),
        'security_token': os.getenv('SALESFORCE_SECURITY_TOKEN'),
        'domain': 'login'  # or 'test' for sandbox
    }
    
    # Initialize scraper
    scraper = EventScraper(OPENAI_API_KEY, SALESFORCE_CREDENTIALS)
    
    # Example: Scrape events for Austin in January 2024
    results = scraper.run_event_scraping_for_location('Austin', 'January', 2024)
    
    print("Event Scraping Results:")
    print(json.dumps(results, indent=2))

if __name__ == "__main__":
    main()