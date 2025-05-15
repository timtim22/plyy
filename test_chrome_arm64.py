#!/usr/bin/env python3
"""
Test script for ARM64 ChromeDriver with undetected-chromedriver

This script first tests a basic Selenium connection with the ARM64 ChromeDriver,
then adds undetected-chromedriver features to avoid detection.
"""
import os
import sys
import time
import logging
import shutil
import subprocess
import re
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# Import undetected_chromedriver only after testing basic Selenium connection
import undetected_chromedriver as uc

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

def check_versions():
    """
    Check Chrome and ChromeDriver versions to ensure compatibility.
    Returns a tuple of (chrome_version, chromedriver_version).
    """
    try:
        # Get Chrome version
        chrome_path = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        chrome_version_output = subprocess.check_output([chrome_path, "--version"], text=True).strip()
        chrome_version_match = re.search(r'Chrome\s+(\d+\.\d+\.\d+\.\d+)', chrome_version_output)
        chrome_version = chrome_version_match.group(1) if chrome_version_match else "Unknown"
        logging.info(f"Chrome version: {chrome_version}")
        
        # Get ChromeDriver version
        current_dir = os.path.dirname(os.path.abspath(__file__))
        chromedriver_path = os.path.join(current_dir, "drivers", "chromedriver")
        driver_version_output = subprocess.check_output([chromedriver_path, "--version"], text=True).strip()
        driver_version_match = re.search(r'ChromeDriver\s+(\d+\.\d+\.\d+\.\d+)', driver_version_output)
        driver_version = driver_version_match.group(1) if driver_version_match else "Unknown"
        logging.info(f"ChromeDriver version: {driver_version}")
        
        # Check major version compatibility
        chrome_major = chrome_version.split('.')[0] if chrome_version != "Unknown" else None
        driver_major = driver_version.split('.')[0] if driver_version != "Unknown" else None
        
        if chrome_major and driver_major and chrome_major != driver_major:
            logging.warning(f"⚠️ Version mismatch! Chrome {chrome_major} != ChromeDriver {driver_major}")
            logging.warning("This may cause compatibility issues. Versions should match.")
        elif chrome_major and driver_major:
            logging.info(f"✅ Compatible major versions: Chrome {chrome_major} and ChromeDriver {driver_major}")
            
        return chrome_version, driver_version
    except Exception as e:
        logging.error(f"Failed to check versions: {e}")
        return "Unknown", "Unknown"

def get_basic_selenium_driver():
    """
    Configure and return a basic Selenium Chrome WebDriver with our ARM64 ChromeDriver.
    """
    try:
        logging.info("Setting up basic Selenium WebDriver with ARM64 ChromeDriver...")
        
        # Get path to local ARM64 ChromeDriver
        current_dir = os.path.dirname(os.path.abspath(__file__))
        chromedriver_path = os.path.join(current_dir, "drivers", "chromedriver")
        
        # Verify ChromeDriver exists
        if not os.path.exists(chromedriver_path):
            raise FileNotFoundError(f"ChromeDriver not found at {chromedriver_path}")
        
        logging.info(f"Using ChromeDriver at: {chromedriver_path}")
        
        # Path to Chrome browser (macOS-specific)
        chrome_path = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        
        # Configure Chrome options
        options = Options()
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.binary_location = chrome_path
        
        # Create a service with our local ChromeDriver
        service = Service(executable_path=chromedriver_path)
        
        # Create and return the Chrome WebDriver
        driver = webdriver.Chrome(
            options=options,
            service=service
        )
        
        return driver
        
    except Exception as e:
        logging.error(f"Failed to initialize basic Selenium ChromeDriver: {e}", exc_info=True)
        raise

def get_undetected_chrome_driver():
    """
    Configure and return an undetected_chromedriver Chrome WebDriver instance using ARM64 ChromeDriver.
    """
    try:
        logging.info("Setting up undetected-chromedriver with ARM64 ChromeDriver...")
        
        # Get path to local ARM64 ChromeDriver
        current_dir = os.path.dirname(os.path.abspath(__file__))
        chromedriver_path = os.path.join(current_dir, "drivers", "chromedriver")
        
        # Path to Chrome browser (macOS-specific)
        chrome_path = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        
        # Delete any existing chromedriver download directory to force using our local binary
        user_data_dir = os.path.expanduser("~/Library/Application Support/undetected_chromedriver")
        if os.path.exists(user_data_dir):
            logging.info(f"Removing existing ChromeDriver directory: {user_data_dir}")
            try:
                shutil.rmtree(user_data_dir)
            except Exception as e:
                logging.warning(f"Could not remove directory: {e}")
        
        # Set environment variables to prevent auto-downloading
        os.environ["WDM_LOG_LEVEL"] = "0"  # Suppress WebDriver Manager logs
        os.environ["WDM_LOCAL"] = "1"      # Use local driver only
        os.environ["UC_CHROMEDRIVER_PATH"] = chromedriver_path
        
        # Configure Chrome options
        options = uc.ChromeOptions()
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.binary_location = chrome_path
        
        # Create a service with our local ChromeDriver
        service = Service(executable_path=chromedriver_path)
        
        # Get Chrome version
        chrome_version, _ = check_versions()
        chrome_major = int(chrome_version.split('.')[0]) if chrome_version != "Unknown" else 135
        
        # Create and return the Chrome WebDriver
        driver = uc.Chrome(
            options=options,
            driver_executable_path=chromedriver_path,
            service=service,
            version_main=chrome_major  # Use detected Chrome version
        )
        
        logging.info("ChromeDriver initialized successfully!")
        return driver
    
    except Exception as e:
        logging.error(f"Failed to initialize ChromeDriver: {e}", exc_info=True)
        raise

def test_basic_selenium():
    """
    Test that basic Selenium ChromeDriver connects properly and can navigate to a website.
    """
    driver = None
    try:
        # Check versions first
        check_versions()
        
        # Create basic Selenium driver
        driver = get_basic_selenium_driver()
        
        # Navigate to a simple test page
        test_url = "https://www.example.com"
        logging.info(f"Navigating to {test_url}...")
        driver.get(test_url)
        
        # Wait for page to load
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.TAG_NAME, "h1"))
        )
        
        # Get page title and content
        title = driver.title
        h1_text = driver.find_element(By.TAG_NAME, "h1").text
        
        logging.info(f"Page title: {title}")
        logging.info(f"H1 content: {h1_text}")
        
        # Take a screenshot as proof
        screenshot_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "basic_selenium_screenshot.png")
        driver.save_screenshot(screenshot_path)
        logging.info(f"Screenshot saved to: {screenshot_path}")
        
        # Test successful
        logging.info("✅ Test completed successfully! Basic Selenium with ARM64 ChromeDriver is working properly.")
        return True
        
    except Exception as e:
        logging.error(f"❌ Test failed: {e}", exc_info=True)
        return False
        
    finally:
        # Always close the browser
        if driver:
            logging.info("Closing browser...")
            driver.quit()

def test_undetected_chrome():
    """
    Test that undetected-chromedriver connects properly and can navigate to a website.
    This uses anti-detection features to avoid bot detection.
    """
    driver = None
    try:
        # Create undetected-chromedriver instance
        driver = get_undetected_chrome_driver()
        
        # Navigate to a test page
        test_url = "https://bot.sannysoft.com/"  # Good site to test bot detection
        logging.info(f"Navigating to {test_url}...")
        driver.get(test_url)
        
        # Wait for page to load
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.ID, "webdriver-result"))
        )
        
        # Check if we're detected as a bot
        webdriver_result = driver.find_element(By.ID, "webdriver-result").text
        if "missing" in webdriver_result.lower() or "false" in webdriver_result.lower():
            logging.info("✅ Successfully avoided webdriver detection!")
        else:
            logging.warning(f"⚠️ Webdriver detected: {webdriver_result}")
        
        # Take a screenshot as proof
        screenshot_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "undetected_chrome_screenshot.png")
        driver.save_screenshot(screenshot_path)
        logging.info(f"Screenshot saved to: {screenshot_path}")
        
        # Test successful
        logging.info("✅ Test completed successfully! Undetected-chromedriver with ARM64 ChromeDriver is working.")
        return True
        
    except Exception as e:
        logging.error(f"❌ Test failed: {e}", exc_info=True)
        return False
        
    finally:
        # Always close the browser
        if driver:
            logging.info("Closing browser...")
            driver.quit()

def run_tests():
    """
    Run all tests in sequence.
    """
    # First check versions
    chrome_version, driver_version = check_versions()
    logging.info(f"Testing with Chrome {chrome_version} and ChromeDriver {driver_version}")
    
    # Test basic Selenium first
    basic_success = test_basic_selenium()
    if not basic_success:
        logging.error("Basic Selenium test failed. Not proceeding with undetected-chromedriver test.")
        return False
    
    # Allow a brief pause between tests
    time.sleep(2)
    
    # Test undetected-chromedriver
    undetected_success = test_undetected_chrome()
    
    # Report overall success
    if basic_success and undetected_success:
        logging.info("🎉 All tests passed successfully! Your ARM64 ChromeDriver is working properly.")
        return True
    else:
        logging.error("❌ Some tests failed. See logs above for details.")
        return False

if __name__ == "__main__":
    try:
        run_tests()
    except KeyboardInterrupt:
        logging.info("Tests interrupted by user.")
        sys.exit(1)

