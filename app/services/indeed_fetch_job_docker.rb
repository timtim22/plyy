class IndeedFetchJobDocker
  require 'webdrivers/chromedriver'

  def initialize(search_id = nil, job_title = nil)
    @search_id = search_id
    @job_title = job_title
    @progress_file = "#{Rails.root}/tmp/job_progress_#{search_id}.json"
    reset_progress
  end

  def reset_progress
    # Create or reset the progress file
    if @search_id
      progress = {
        job_count: 0,
        total_target: 20,
        completed: false
      }
      File.write(@progress_file, progress.to_json)
    end
  end

  def update_progress(job_count, completed = false)
    # Update the progress file
    if @search_id
      progress = {
        job_count: job_count,
        total_target: 20,
        completed: completed
      }
      File.write(@progress_file, progress.to_json)
    end
  end

  def fetch_jobs
    # Use Docker-based Selenium for consistent cross-platform behavior
    # This approach uses a remote WebDriver connection to a Dockerized Chrome
    
    # Check if we should use Docker (can be controlled via environment variable)
    use_docker = ENV['USE_DOCKER_SELENIUM'] == 'true' || docker_available?
    
    if use_docker
      driver = setup_docker_driver
    else
      # Fallback to local driver with webdrivers gem
      driver = setup_local_driver
    end
    
    job_results = []

    begin
      target = "https://www.indeed.com/jobs?q=#{@job_title}"
      driver.get(target)
      
      # More human-like waiting pattern
      sleep(rand(3..6))
      
      # Scroll a bit to simulate human behavior
      driver.execute_script("window.scrollTo(0, 300);")
      sleep(rand(1..3))
      
      # Wait for Cloudflare's JS to complete and for the job cards to appear
      wait = Selenium::WebDriver::Wait.new(timeout: 15)
      wait.until { driver.find_elements(css: 'div.job_seen_beacon').any? }
      
      # Continue with existing job processing logic...
      first_job_title = driver.find_elements(css: 'h2.jobTitle a').first rescue nil
      if first_job_title
        puts "Clicking first job to preload description"
        first_job_title.click
        sleep 2
        wait.until { driver.find_elements(css: '.jobsearch-JobComponent-description').any? }
      end

      # Get all list items and extract job cards
      list_items = driver.find_elements(css: 'li.css-1ac2h1w')
      puts "✅ Found #{list_items.size} list items to process"
      
      # Target count of jobs to process
      processed_jobs = 0
      target_jobs = 20
      
      # Process jobs (existing logic from original service)
      list_items.each_with_index do |list_item, index|
        break if processed_jobs >= target_jobs
        
        begin
          job_beacon = list_item.find_elements(css: 'div.job_seen_beacon')
          
          if job_beacon.empty?
            puts "Skipping list item #{index + 1} - not a job card"
            next
          end
          
          puts "Processing list item #{index + 1} - found job card"
          
          job_card = job_beacon.first
          title_element = job_card.find_element(css: 'h2.jobTitle') rescue nil
          
          if title_element.nil?
            puts "Skipping job card - no title found"
            next
          end
          
          title = title_element.text.strip
          company = job_card.find_element(css: '[data-testid="company-name"]').text.strip rescue "Unknown Company"
          location = job_card.find_element(css: '[data-testid="text-location"]').text.strip rescue "Remote"
          
          summary_element = job_card.find_element(css: '[data-testid="belowJobSnippet"]') rescue nil
          if summary_element.nil?
            summary_element = job_card.find_element(css: '[data-testid="jobsnippet_footer"]') rescue nil
          end
          summary = summary_element ? summary_element.text.strip : "No preview available"
          
          job_link = title_element.find_element(tag_name: 'a') rescue nil
          
          if job_link.nil?
            puts "Skipping job card - no link found"
            next
          end
          
          job_url = job_link.attribute('href')
          
          puts "Processing job #{processed_jobs + 1}: #{title}"
          
          # Extract full description (simplified for this example)
          full_description = extract_job_description(driver, job_link, processed_jobs, first_job_title)
          
          job_result = {
            title: title,
            company: company,
            location: location,
            summary: summary,
            description: full_description,
            url: job_url
          }
          
          job_results << job_result
          processed_jobs += 1
          
          update_progress(processed_jobs, processed_jobs >= target_jobs)
          
          puts "  Title: #{title}"
          puts "  Company: #{company}"
          puts "  Location: #{location}"
          puts ""
          
        rescue StandardError => e
          puts "Error processing list item #{index + 1}: #{e.message}"
        end
      end
      
      update_progress(processed_jobs, true) if @search_id
    
      return job_results
    ensure
      driver.quit if driver
    end
  end

  private

  def docker_available?
    # Check if Docker is available and Selenium containers can be used
    system('docker --version > /dev/null 2>&1')
  end

  def setup_docker_driver
    # Start a Selenium Chrome container if it's not already running
    container_name = 'selenium-chrome-ply'
    
    # Check if container is already running
    unless system("docker ps --filter name=#{container_name} --filter status=running -q | grep -q .")
      puts "Starting Selenium Chrome container..."
      
      # Start the Selenium standalone Chrome container
      system(<<~CMD.strip)
        docker run -d --rm --name #{container_name} \
          -p 4444:4444 -p 7900:7900 \
          --shm-size=2g \
          selenium/standalone-chrome:latest
      CMD
      
      # Wait for container to be ready
      sleep 10
    end
    
    # Configure Chrome options for Docker environment
    opts = Selenium::WebDriver::Chrome::Options.new
    
    # Anti-detection arguments
    opts.add_argument('--disable-blink-features=AutomationControlled')
    opts.add_argument('--disable-features=VizDisplayCompositor')
    opts.add_argument('--disable-web-security')
    opts.add_argument('--disable-ipc-flooding-protection')
    opts.add_argument('--no-sandbox')
    opts.add_argument('--disable-dev-shm-usage')
    opts.add_argument('--disable-gpu')
    opts.add_argument('--window-size=1366,768')
    
    # Dynamic user agent
    user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
    opts.add_argument("--user-agent=#{user_agent}")
    
    # Stealth options
    opts.add_experimental_option('excludeSwitches', ['enable-automation'])
    opts.add_experimental_option('useAutomationExtension', false)
    
    # Connect to the remote Selenium Grid
    driver = Selenium::WebDriver.for(
      :remote,
      url: 'http://localhost:4444/wd/hub',
      capabilities: opts
    )
    
    # Execute anti-detection script
    driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    
    # Set timeouts
    driver.manage.timeouts.page_load = 30
    driver.manage.timeouts.implicit_wait = 10
    
    driver
  end

  def setup_local_driver
    # Fallback to local driver using webdrivers gem
    Webdrivers::Chromedriver.update
    
    opts = Selenium::WebDriver::Chrome::Options.new
    
    # Anti-detection arguments
    opts.add_argument('--disable-blink-features=AutomationControlled')
    opts.add_argument('--disable-features=VizDisplayCompositor')
    opts.add_argument('--disable-web-security')
    opts.add_argument('--disable-ipc-flooding-protection')
    opts.add_argument('--window-size=1366,768')
    opts.add_argument('--no-sandbox')
    opts.add_argument('--disable-dev-shm-usage')
    opts.add_argument('--disable-gpu')
    
    # Platform-specific user agent
    user_agent = case RUBY_PLATFORM
    when /darwin/
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
    when /linux/
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
    when /mswin|mingw/
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
    else
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
    end
    opts.add_argument("--user-agent=#{user_agent}")
    
    # Stealth options
    opts.add_experimental_option('excludeSwitches', ['enable-automation'])
    opts.add_experimental_option('useAutomationExtension', false)
    
    driver = Selenium::WebDriver.for :chrome, options: opts
    
    # Execute anti-detection script
    driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    
    # Set timeouts
    driver.manage.timeouts.page_load = 30
    driver.manage.timeouts.implicit_wait = 10
    
    driver
  end

  def extract_job_description(driver, job_link, processed_jobs, first_job_title)
    full_description = ""
    
    if processed_jobs == 0 && first_job_title
      # For the first job, we already clicked it, so just get the description
      description_element = driver.find_element(id: 'jobDescriptionText') rescue nil
      if description_element
        full_description = description_element.text.strip
      end
    else
      # For other jobs, click to view details
      job_link.click
      
      # Wait for job details to load
      wait = Selenium::WebDriver::Wait.new(timeout: 10)
      wait.until { driver.find_elements(css: '.jobsearch-JobComponent-description').any? }
      sleep 1
      
      # Extract full job description
      description_element = driver.find_element(id: 'jobDescriptionText') rescue nil
      if description_element
        full_description = description_element.text.strip
      end
    end
    
    full_description
  end

  def stop_docker_container
    # Helper method to stop the Docker container when done
    container_name = 'selenium-chrome-ply'
    system("docker stop #{container_name} > /dev/null 2>&1")
  end
end 