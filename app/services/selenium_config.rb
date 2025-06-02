# Configuration for Selenium WebDriver across different environments and platforms
class SeleniumConfig
  class << self
    def chrome_options(headless: false, stealth: true, remote: false)
      opts = Selenium::WebDriver::Chrome::Options.new
      
      # Basic Chrome arguments
      base_args = [
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--window-size=1366,768'
      ]
      
      # Add headless mode if requested
      base_args << '--headless' if headless
      
      # Anti-detection arguments (stealth mode)
      if stealth
        stealth_args = [
          '--disable-blink-features=AutomationControlled',
          '--disable-features=VizDisplayCompositor',
          '--disable-web-security',
          '--disable-ipc-flooding-protection',
          '--disable-background-timer-throttling',
          '--disable-backgrounding-occluded-windows',
          '--disable-renderer-backgrounding',
          '--disable-features=TranslateUI',
          '--disable-default-apps',
          '--no-first-run',
          '--disable-extensions'
        ]
        base_args.concat(stealth_args)
        
        # Chrome preferences for more human-like behavior
        prefs = {
          'profile.default_content_setting_values.notifications' => 2,
          'profile.default_content_settings.popups' => 0,
          'profile.managed_default_content_settings.images' => 1,
          'profile.default_content_setting_values.media_stream_mic' => 2,
          'profile.default_content_setting_values.media_stream_camera' => 2,
          'profile.default_content_setting_values.geolocation' => 2
        }
        
        # Set preferences using the correct API
        prefs.each { |key, value| opts.add_preference(key, value) }
        
        # Stealth options - only use for local drivers (not W3C compliant for remote)
        unless remote
          opts.add_option('excludeSwitches', ['enable-automation'])
          opts.add_option('useAutomationExtension', false)
        else
          # For remote drivers, use W3C compliant arguments instead
          base_args << '--disable-automation'
          base_args << '--disable-web-security'
          puts "🔒 Using W3C-compliant stealth mode for remote driver"
        end
      end
      
      # Add all arguments
      base_args.each { |arg| opts.add_argument(arg) }
      
      # Set user agent based on platform
      user_agent = platform_user_agent
      opts.add_argument("--user-agent=#{user_agent}")
      
      opts
    end
    
    def platform_user_agent
      case RUBY_PLATFORM
      when /darwin/
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      when /linux/
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      when /mswin|mingw/
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      else
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      end
    end
    
    def create_driver(method: :auto, headless: false, stealth: true)
      method = detect_best_method if method == :auto
      
      case method
      when :docker
        create_docker_driver(headless: headless, stealth: stealth)
      when :local
        create_local_driver(headless: headless, stealth: stealth)
      when :remote
        create_remote_driver(headless: headless, stealth: stealth)
      else
        raise "Unknown driver method: #{method}"
      end
    end
    
    def detect_best_method
      # Priority: Docker > Local > Remote
      if docker_available?
        :docker
      elsif local_chrome_available?
        :local
      else
        :remote # Fallback to remote service
      end
    end
    
    def docker_available?
      # More robust Docker detection
      return false unless system('docker --version > /dev/null 2>&1')
      
      # Check if Docker daemon is running
      docker_running = system('docker info > /dev/null 2>&1')
      
      if docker_running
        puts "🐳 Docker detected and running"
        return true
      else
        puts "⚠️ Docker installed but not running. Start with: docker-machine start default (or similar)"
        return false
      end
    end
    
    def local_chrome_available?
      case RUBY_PLATFORM
      when /darwin/
        File.exist?('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
      when /linux/
        system('which google-chrome > /dev/null 2>&1') || 
        system('which google-chrome-stable > /dev/null 2>&1') ||
        system('which chromium-browser > /dev/null 2>&1')
      when /mswin|mingw/
        # Windows Chrome paths
        [
          'C:\Program Files\Google\Chrome\Application\chrome.exe',
          'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
        ].any? { |path| File.exist?(path) }
      else
        false
      end
    end
    
    private
    
    def create_docker_driver(headless: false, stealth: true)
      container_name = 'selenium-chrome-ply'
      
      # Check if container is already running
      unless system("docker ps --filter name=#{container_name} --filter status=running -q | grep -q .")
        puts "Starting Selenium Chrome container..."
        
        # Choose the right image based on architecture and requirements
        image = docker_chrome_image
        puts "📦 Using Docker image: #{image}"
        
        # Start the container
        system(<<~CMD.strip)
          docker run -d --rm --name #{container_name} \
            -p 4444:4444 -p 7900:7900 \
            --shm-size=2g \
            #{image}
        CMD
        
        # Wait for container to be ready
        wait_for_selenium_grid('http://localhost:4444', timeout: 30)
      end
      
      opts = chrome_options(headless: headless, stealth: stealth, remote: true)
      
      driver = Selenium::WebDriver.for(
        :remote,
        url: 'http://localhost:4444/wd/hub',
        capabilities: opts
      )
      
      apply_stealth_scripts(driver) if stealth
      configure_timeouts(driver)
      
      driver
    end
    
    def docker_chrome_image
      # Detect architecture and choose appropriate image
      arch = `uname -m`.strip
      puts "🏗️ Detected architecture: #{arch}"
      
      case arch
      when 'arm64', 'aarch64'
        # For Apple Silicon and ARM64 systems
        puts "🍎 Using ARM64-compatible Chromium image"
        'seleniarm/standalone-chromium:latest'
      when 'x86_64', 'amd64'
        # For Intel/AMD systems
        'selenium/standalone-chrome:latest'
      else
        # Fallback - try ARM64 first, then x86_64 with emulation
        puts "❓ Unknown architecture, trying ARM64-compatible image first"
        'seleniarm/standalone-chromium:latest'
      end
    end
    
    def create_local_driver(headless: false, stealth: true)
      # Handle non-production Chrome versions gracefully
      driver = nil
      
      begin
        puts "🔧 Setting up local Chrome driver..."
        
        # Check Chrome version and handle non-production versions
        chrome_version = detect_chrome_version
        puts "📍 Detected Chrome version: #{chrome_version}"
        
        # For non-production Chrome versions (like 136.x), set a compatible ChromeDriver version
        if chrome_version && chrome_version.start_with?('136.')
          puts "⚠️ Non-production Chrome detected (v#{chrome_version})"
          puts "🔧 Setting compatible ChromeDriver version..."
          
          require 'webdrivers/chromedriver'
          # Use a known stable ChromeDriver version that works with newer Chrome
          Webdrivers::Chromedriver.required_version = '131.0.6778.85'
          Webdrivers::Chromedriver.update
        end
        
        opts = chrome_options(headless: headless, stealth: stealth)
        driver = Selenium::WebDriver.for :chrome, options: opts
        
        puts "✅ Successfully created local ChromeDriver"
        
      rescue Webdrivers::VersionError, Webdrivers::NetworkError => e
        puts "⚠️ ChromeDriver version issue: #{e.message}"
        puts "🔧 Trying with known stable ChromeDriver version..."
        
        begin
          require 'webdrivers/chromedriver'
          # Clear any cached version and set a specific version
          Webdrivers::Chromedriver.remove
          Webdrivers::Chromedriver.required_version = '131.0.6778.85'
          Webdrivers::Chromedriver.update
          
          opts = chrome_options(headless: headless, stealth: stealth)
          driver = Selenium::WebDriver.for :chrome, options: opts
          
          puts "✅ Successfully created ChromeDriver with fixed version"
          
        rescue => update_error
          puts "❌ ChromeDriver update failed: #{update_error.message}"
          handle_driver_fallback(e, headless: headless, stealth: stealth)
        end
        
      rescue Selenium::WebDriver::Error::SessionNotCreatedError => e
        puts "⚠️ ChromeDriver session error: #{e.message}"
        handle_driver_fallback(e, headless: headless, stealth: stealth)
        
      rescue => e
        puts "❌ Unexpected error with local ChromeDriver: #{e.message}"
        handle_driver_fallback(e, headless: headless, stealth: stealth)
      end
      
      apply_stealth_scripts(driver) if stealth
      configure_timeouts(driver)
      
      driver
    end
    
    def detect_chrome_version
      case RUBY_PLATFORM
      when /darwin/
        chrome_path = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
        if File.exist?(chrome_path)
          version_output = `"#{chrome_path}" --version 2>/dev/null`.strip
          version_output.match(/Chrome (\d+\.\d+\.\d+\.\d+)/)&.captures&.first
        end
      when /linux/
        ['google-chrome', 'google-chrome-stable', 'chromium-browser'].each do |cmd|
          version_output = `#{cmd} --version 2>/dev/null`.strip
          version = version_output.match(/Chrome (\d+\.\d+\.\d+\.\d+)/)&.captures&.first
          return version if version
        end
      end
      nil
    end
    
    def handle_driver_fallback(original_error, headless: false, stealth: true)
      if docker_available?
        puts "🐳 Falling back to Docker-based Chrome..."
        return create_docker_driver(headless: headless, stealth: stealth)
      else
        puts ""
        puts "💥 Unable to setup local ChromeDriver."
        puts "🎯 RECOMMENDED SOLUTIONS:"
        puts "   1. Install Docker for a reliable setup:"
        puts "      • macOS: brew install --cask docker"
        puts "      • Then start Docker Desktop from Applications"
        puts ""
        puts "   2. OR downgrade to stable Chrome:"
        puts "      • You're using Chrome #{detect_chrome_version || 'Unknown'} (non-production)"
        puts "      • Download stable Chrome from: https://www.google.com/chrome/"
        puts ""
        puts "   3. OR manually install compatible ChromeDriver:"
        puts "      • Download from: https://chromedriver.chromium.org/downloads"
        puts "      • Place in /usr/local/bin/ and make executable"
        puts ""
        raise "Unable to setup ChromeDriver. Original error: #{original_error.message}"
      end
    end
    
    def create_remote_driver(headless: false, stealth: true)
      # For cloud services like BrowserStack, Sauce Labs, etc.
      # This would need to be configured with proper credentials
      remote_url = ENV['SELENIUM_REMOTE_URL'] || 'http://localhost:4444/wd/hub'
      
      opts = chrome_options(headless: headless, stealth: stealth, remote: true)
      
      driver = Selenium::WebDriver.for(
        :remote,
        url: remote_url,
        capabilities: opts
      )
      
      apply_stealth_scripts(driver) if stealth
      configure_timeouts(driver)
      
      driver
    end
    
    def apply_stealth_scripts(driver)
      # Remove webdriver property
      driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
      
      # Override the plugins property
      driver.execute_script(<<~JS)
        Object.defineProperty(navigator, 'plugins', {
          get: () => [1, 2, 3, 4, 5]
        });
      JS
      
      # Override the languages property
      driver.execute_script(<<~JS)
        Object.defineProperty(navigator, 'languages', {
          get: () => ['en-US', 'en']
        });
      JS
    end
    
    def configure_timeouts(driver)
      driver.manage.timeouts.page_load = 30
      driver.manage.timeouts.implicit_wait = 10
    end
    
    def wait_for_selenium_grid(url, timeout: 30)
      start_time = Time.now
      
      loop do
        begin
          require 'net/http'
          uri = URI("#{url}/status")
          response = Net::HTTP.get_response(uri)
          
          if response.code == '200'
            puts "Selenium Grid is ready!"
            return true
          end
        rescue => e
          # Continue waiting
        end
        
        if Time.now - start_time > timeout
          raise "Selenium Grid did not become ready within #{timeout} seconds"
        end
        
        sleep 2
      end
    end
  end
end 