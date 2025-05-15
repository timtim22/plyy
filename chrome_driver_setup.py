#!/usr/bin/env python3
import os
import undetected_chromedriver as uc
import time
import sys
import logging
from selenium.webdriver.chrome.service import Service

# Setup logging for better debugging
logging.basicConfig(level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

def setup_chrome_driver():
    logging.info("Setting up ChromeDriver for ARM64 architecture...")
    
    # Get absolute path to the local ChromeDriver
    current_dir = os.path.dirname(os.path.abspath(__file__))
    chromedriver_path = os.path.join(current_dir, "drivers", "chromedriver")
    logging.info(f"Using ChromeDriver at: {chromedriver_path}")
    
    # Verify ChromeDriver file exists and has execute permissions
    if not os.path.exists(chromedriver_path):
        logging.error(f"ChromeDriver not found at {chromedriver_path}")
        return False
    
    logging.info(f"ChromeDriver permissions: {oct(os.stat(chromedriver_path).st_mode)[-3:]}")
    
    # Chrome executable path
    chrome_path = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    logging.info(f"Chrome binary at: {chrome_path}")
    
    try:
        # Create and configure undetected-chromedriver options
        logging.info("Setting up undetected-chromedriver with our local ARM64 binary...")
        
        # Configure options
        options = uc.ChromeOptions()
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.binary_location = chrome_path
        
        # Create a Service object with our local chromedriver
        service = Service(executable_path=chromedriver_path)
        
        # Set environment variables to ensure our ChromeDriver is used
        os.environ["WDM_LOG_LEVEL"] = "0"  # Suppress WebDriver Manager logs
        os.environ["WDM_LOCAL"] = "1"      # Use local driver only
        os.environ["UC_CHROMEDRIVER_PATH"] = chromedriver_path
        
        # Delete any existing chromedriver download directory to force using ours
        user_data_dir = os.path.expanduser("~/Library/Application Support/undetected_chromedriver")
        if os.path.exists(user_data_dir):
            logging.info(f"Removing existing ChromeDriver directory: {user_data_dir}")
            import shutil
            try:
                shutil.rmtree(user_data_dir)
            except Exception as e:
                logging.warning(f"Could not remove directory: {e}")
        
        # Initialize undetected-chromedriver with our configuration
        logging.info("Initializing undetected-chromedriver...")
        logging.info(f"Python version: {sys.version}")
        logging.info(f"Undetected ChromeDriver version: {uc.__version__}")
        
        # Create the ChromeDriver instance using undetected-chromedriver
        driver = uc.Chrome(
            options=options,
            driver_executable_path=chromedriver_path,
            service=service,
            use_subprocess=False,  # Important to avoid subprocess issues
            version_main=135  # Chrome version 135
        )
        
        logging.info("ChromeDriver initialized successfully!")
        logging.info("Making a test connection to verify it works...")
        
        # Test the connection
        driver.get("https://www.google.com")
        logging.info(f"Successfully loaded: {driver.title}")
        
        # Wait a bit longer to see the browser window
        logging.info("Waiting for 5 seconds to view the browser...")
        time.sleep(5)
        
        driver.quit()
        logging.info("Test completed successfully.")
        return True
    except Exception as e:
        logging.error(f"Error initializing ChromeDriver: {e}", exc_info=True)
        return False

if __name__ == "__main__":
    setup_chrome_driver()

