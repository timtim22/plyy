#!/usr/bin/env python3
"""
Example script demonstrating how to use undetected-chromedriver with ARM64 ChromeDriver
for web automation tasks. This example reuses the configuration from chrome_driver_setup.py
to ensure the correct ChromeDriver binary is used.
"""
import os
import time
import logging
import sys
import shutil
import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.service import Service

# Configure logging
logging.basicConfig(level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

def setup_driver():
    """
    Set up and return a configured undetected-chromedriver instance 
    using our local ARM64 ChromeDriver.
    """
    # Get the path to our local ARM64 ChromeDriver
    current_dir = os.path.dirname(os.path.abspath(__file__))
    chromedriver_path = os.path.join(current_dir, "drivers", "chromedriver")
    
    # Make sure the ChromeDriver exists
    if not os.path.exists(chromedriver_path):
        raise FileNotFoundError(f"ChromeDriver not found at {chromedriver_path}")
    
    # Path to Chrome browser
    chrome_path = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    
    # Set environment variables to ensure our ChromeDriver is used
    os.environ["WDM_LOG_LEVEL"] = "0"  # Suppress WebDriver Manager logs
    os.environ["WDM_LOCAL"] = "1"      # Use local driver only
    os.environ["UC_CHROMEDRIVER_PATH"] = chromedriver_path
    
    # Delete any existing chromedriver download directory to force using ours
    user_data_dir = os.path.expanduser("~/Library/Application Support/undetected_chromedriver")
    if os.path.exists(user_data_dir):
        logging.info(f"Removing existing ChromeDriver directory: {user_data_dir}")
        try:
            shutil.rmtree(user_data_dir)
        except Exception as e:
            logging.warning(f"Could not remove directory: {e}")
    
    # Configure options
    options = uc.ChromeOptions()
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.binary_location = chrome_path
    
    # Create a Service object with our local chromedriver
    service = Service(executable_path=chromedriver_path)
    
    # Create and return the ChromeDriver instance
    logging.info("Initializing undetected-chromedriver...")
    logging.info(f"Python version: {sys.version}")
    logging.info(f"Undetected ChromeDriver version: {uc.__version__}")
    
    driver = uc.Chrome(
        options=options,
        driver_executable_path=chromedriver_path,
        service=service,
        use_subprocess=False,  # Important to avoid subprocess issues
        version_main=135  # Chrome version 135
    )
    
    return driver

def example_wikipedia_search():
    """
    A simple example task that:
    1. Opens Wikipedia
    2. Searches for "Apple Silicon"
    3. Waits for and extracts information from the page
    """
    try:
        logging.info("Initializing ChromeDriver...")
        driver = setup_driver()
        
        # Open Wikipedia (very stable and reliable website)
        logging.info("Opening Wikipedia...")
        driver.get("https://en.wikipedia.org/")
        
        # Wait for the page to fully load
        logging.info("Waiting for page to load...")
        
        # Wait for the search box to be available - Wikipedia's search is very consistent
        search_box = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.ID, "searchInput"))
        )
        
        # Perform a search
        search_term = "Apple Silicon"
        logging.info(f"Searching for: {search_term}")
        search_box.clear()
        search_box.send_keys(search_term)
        search_box.send_keys(Keys.RETURN)
        
        # Wait for the search results page to load
        logging.info("Waiting for page to load...")
        
        # Wait for the article content to be present
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.ID, "content"))
        )
        
        # Check if we're on the article page (direct match) or search results
        if "Search results" in driver.title:
            logging.info("On search results page")
            
            # Find search results
            results = WebDriverWait(driver, 10).until(
                EC.presence_of_all_elements_located((By.CSS_SELECTOR, ".mw-search-result-heading"))
            )
            
            # Extract and print search results
            logging.info("Search Results:")
            for i, result in enumerate(results[:5], 1):
                logging.info(f"{i}. {result.text}")
                
            # Click on the first result
            if results:
                results[0].find_element(By.TAG_NAME, "a").click()
                
                # Wait for the article to load
                WebDriverWait(driver, 10).until(
                    EC.presence_of_element_located((By.ID, "firstHeading"))
                )
        
        # We're now on an article page
        logging.info(f"Loaded article: {driver.title}")
        
        # Extract the first paragraph of content
        first_paragraph = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, ".mw-parser-output > p"))
        )
        logging.info(f"Article excerpt: {first_paragraph.text[:200]}...")
        
        # Extract section headers
        section_headers = driver.find_elements(By.CSS_SELECTOR, ".mw-headline")
        logging.info("Article sections:")
        for i, header in enumerate(section_headers[:5], 1):
            logging.info(f"{i}. {header.text}")
        logging.info("Search Results:")
        for i, result in enumerate(results[:5], 1):
            logging.info(f"{i}. {result.text}")
        
        # Take a screenshot
        screenshot_path = os.path.join(current_dir, "search_results.png")
        driver.save_screenshot(screenshot_path)
        logging.info(f"Screenshot saved to: {screenshot_path}")
        
        # Wait a bit to see the results
        time.sleep(5)
        
        # Close the browser
        driver.quit()
        logging.info("Browser closed successfully")
        
    except Exception as e:
        logging.error(f"Error during automation: {e}", exc_info=True)
        if 'driver' in locals():
            driver.quit()

if __name__ == "__main__":
    example_wikipedia_search()

