class IndeedFetchJob
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
    # 1) Point to your Homebrew chromedriver
    Selenium::WebDriver::Chrome::Service.driver_path = '/opt/homebrew/bin/chromedriver'

    # 2) Launch Chrome (head-ful so CF runs its JS)
    opts = Selenium::WebDriver::Chrome::Options.new
    opts.add_argument('--disable-blink-features=AutomationControlled')
    opts.add_argument('--window-size=1280,800')
    opts.add_argument(
    '--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ' \
    'AppleWebKit/537.36 (KHTML, like Gecko) ' \
    'Chrome/136.0.7103.93 Safari/537.36'
    )

    driver = Selenium::WebDriver.for :chrome, options: opts
    driver.manage.timeouts.page_load = 60
    
    job_results = []

    begin
      target = "https://www.indeed.com/jobs?q=#{@job_title}"
      driver.get(target)
      sleep 4
      
      # 4) Wait for Cloudflare's JS to complete and for the job cards to appear
      wait = Selenium::WebDriver::Wait.new(timeout: 15)
      wait.until { driver.find_elements(css: 'div.job_seen_beacon').any? }
      
      # 5) Immediately click the first job to load its description (first job is usually pre-selected)
      first_job_title = driver.find_element(css: 'h2.jobTitle a') rescue nil
      if first_job_title
        puts "Clicking first job to preload description"
        first_job_title.click
        sleep 2
        wait.until { driver.find_elements(css: '.jobsearch-JobComponent-description').any? }
      end

      # 6) Get all list items and extract job cards
      list_items = driver.find_elements(css: 'li.css-1ac2h1w')
      puts "✅ Found #{list_items.size} list items to process"
      
      # Target count of jobs to process
      processed_jobs = 0
      target_jobs = 20
      
      # 7) Process each list item
      list_items.each_with_index do |list_item, index|
        # Break if we've processed enough jobs
        break if processed_jobs >= target_jobs
        
        begin
          # Check if this item contains a job card
          job_beacon = list_item.find_elements(css: 'div.job_seen_beacon')
          
          # Skip items without job cards (promotions, dividers, etc.)
          if job_beacon.empty?
            puts "Skipping list item #{index + 1} - not a job card"
            next
          end
          
          puts "Processing list item #{index + 1} - found job card"
          
          # Process the job card
          job_card = job_beacon.first
          
          # Extract basic info from card
          title_element = job_card.find_element(css: 'h2.jobTitle') rescue nil
          
          # Skip if we can't find the title (likely not a proper job card)
          if title_element.nil?
            puts "Skipping job card - no title found"
            next
          end
          
          title = title_element.text.strip
          company = job_card.find_element(css: '[data-testid="company-name"]').text.strip rescue "Unknown Company"
          location = job_card.find_element(css: '[data-testid="text-location"]').text.strip rescue "Remote"
          
          # Try different selectors for job snippets
          summary_element = job_card.find_element(css: '[data-testid="belowJobSnippet"]') rescue nil
          if summary_element.nil?
            summary_element = job_card.find_element(css: '[data-testid="jobsnippet_footer"]') rescue nil
          end
          summary = summary_element ? summary_element.text.strip : "No preview available"
          
          # Get the job URL
          job_link = title_element.find_element(tag_name: 'a') rescue nil
          
          # Skip if we can't find the link
          if job_link.nil?
            puts "Skipping job card - no link found"
            next
          end
          
          job_url = job_link.attribute('href')
          
          puts "Processing job #{processed_jobs + 1}: #{title}"
          
          # Get the first job's description from the already loaded view
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
            wait.until { driver.find_elements(css: '.jobsearch-JobComponent-description').any? }
            sleep 1 # Give it a moment to fully render
            
            # Extract full job description
            description_element = driver.find_element(id: 'jobDescriptionText') rescue nil
            if description_element
              full_description = description_element.text.strip
            end
          end
          
          # If still no description, try directly searching for it again
          if full_description.empty?
            description_element = driver.find_element(id: 'jobDescriptionText') rescue nil
            if description_element
              full_description = description_element.text.strip
            end
          end
          
          # If still no description, use the summary
          if full_description.empty?
            full_description = summary
          end
          
          # Extract job type
          job_type = "Unknown"
          job_type_element = driver.find_element(css: '[data-testid="jobsearch-OtherJobDetailsContainer"] .css-1h7a62l') rescue nil
          if job_type_element
            job_type = job_type_element.text.strip
          end
          
          # Extract salary
          salary = "Not specified"
          
          # Try multiple approaches to find the salary
          # First try the specific selector from the job details section
          begin
            salary_element = driver.find_element(css: '#salaryInfoAndJobType .css-1jh4tn2')
            if salary_element
              salary = salary_element.text.strip
            end
          rescue
            # Try alternate selector
            begin
              salary_element = driver.find_element(css: '[data-testid="jobsearch-OtherJobDetailsContainer"] .css-1jh4tn2')
              if salary_element
                salary = salary_element.text.strip
              end
            rescue
              # Try to find any element with those specific classes
              begin
                # Look for all spans in the page and find the one with the salary class
                all_spans = driver.find_elements(css: 'span')
                salary_span = all_spans.find { |span| span.attribute('class').to_s.include?('css-1jh4tn2') }
                if salary_span
                  potential_salary = salary_span.text.strip
                  if potential_salary.match(/\$/) # Make sure it looks like a salary with dollar sign
                    salary = potential_salary
                  end
                end
              rescue
                # Continue with next approach
              end
              
              # Try to find any element with the specific class
              begin
                salary_element = driver.find_element(css: '.css-1jh4tn2')
                if salary_element
                  salary = salary_element.text.strip
                end
              rescue
                # If we still don't have a salary, try extracting from description
                if salary == "Not specified" && !full_description.empty?
                  salary_patterns = [
                    /\$\d{2,3}(,\d{3})?\s*(-|to|–)\s*\$\d{2,3}(,\d{3})?\s*(a year|per year|yearly|annual)/i,
                    /\$\d{2,3}(,\d{3})?\s*(-|to|–)\s*\$\d{2,3}(,\d{3})?/i,
                    /\$\d{2,3}(,\d{3})?\s*(a year|per year|yearly|annual)/i,
                    /Salary:?\s*\$\d{2,3}(,\d{3})?\s*(-|to|–)\s*\$\d{2,3}(,\d{3})?/i,
                    /\$\d{2,3}(,\d{3})?\s*\+/i,
                    /\$\d{2}(-|to|–)\$\d{2}\s*an hour/i,
                    /\$\d{2}(\.\d{2})?\s*(-|to|–)\s*\$\d{2}(\.\d{2})?\s*(an hour|per hour|hourly)/i
                  ]
                  
                  # Try each pattern until we find a match
                  salary_patterns.each do |pattern|
                    if match = full_description.match(pattern)
                      salary = match[0]
                      break
                    end
                  end
                end
              end
            end
          end
          
          # Try another approach by directly looking for the salary in the details section
          if salary == "Not specified"
            begin
              # Try to get the job details container first
              job_details = driver.find_element(css: "#jobDetailsSection")
              if job_details
                # Find all spans within the job details section
                spans = job_details.find_elements(css: "span")
                
                # Look for a span that contains dollar sign
                spans.each do |span|
                  span_text = span.text.strip
                  if span_text.include?("$") && span_text.match(/\$[\d,]+/)
                    salary = span_text
                    break
                  end
                end
              end
            rescue
              # Just continue
            end
          end
          
          # Extract work setting
          work_setting = "Not specified"
          
          # Try multiple approaches to find the work setting
          # First try the most specific selector
          begin
            # Look for the work setting in the job details section
            work_setting_tiles = driver.find_elements(css: '[role="group"][aria-label="Work setting"] [data-testid="list-item"]')
            if work_setting_tiles && work_setting_tiles.any?
              work_setting_text = work_setting_tiles.first.text.strip
              if !work_setting_text.empty?
                work_setting = work_setting_text
              end
            end
          rescue
            # Try another selector
            begin
              work_setting_element = driver.find_element(css: '[data-testid="Remote-tile"] span')
              if work_setting_element
                work_setting = work_setting_element.text.strip
              end
            rescue
              # Try the generic selector
              begin
                work_setting_element = driver.find_element(css: '[data-testid="inlineHeader-companyLocation"] div')
                if work_setting_element && work_setting_element.text.include?("Remote")
                  work_setting = "Remote"
                end
              rescue
                # Fallback to checking the location
                if location.include?("Remote")
                  work_setting = "Remote"
                # Finally try extracting from the description
                elsif !full_description.empty?
                  if full_description.match(/\b(fully remote|100% remote|remote role|remote work|work from home|wfh)\b/i)
                    work_setting = "Remote"
                  elsif full_description.match(/\b(hybrid|partial remote|partially remote)\b/i)
                    work_setting = "Hybrid"
                  elsif full_description.match(/\b(on.?site|in.?office|on location|in person)\b/i)
                    work_setting = "On-site"
                  end
                end
              end
            end
          end
          
          # Create result with all details (except reference number which is not needed)
          job_result = {
            title: title,
            company: company,
            location: location,
            summary: summary,
            description: full_description,
            job_type: job_type,
            salary: salary,
            work_setting: work_setting,
            url: job_url
          }
          
          # Add to results array
          job_results << job_result
          processed_jobs += 1
          
          # Update progress after each job is processed
          update_progress(processed_jobs, processed_jobs >= target_jobs)
          
          # Print essential details
          puts "  Title: #{title}"
          puts "  Company: #{company}"
          puts "  Location: #{location}"
          puts "  Job Type: #{job_type}"
          puts "  Salary: #{salary}"
          puts "  Work Setting: #{work_setting}"
          puts ""
          
        rescue StandardError => e
          puts "Error processing list item #{index + 1}: #{e.message}"
        end
      end
      
      # Ensure progress is marked as complete when finished
      update_progress(processed_jobs, true) if @search_id
    
      return job_results
    ensure
      driver.quit
    end
  end
end
