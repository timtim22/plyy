# Selenium Setup Guide for Cross-Platform Indeed Scraping

This guide explains how to set up Selenium WebDriver for the Indeed job scraper to work consistently across different machines and operating systems.

## Overview

The scraper now supports multiple deployment methods that work universally:

1. **Docker-based** (Recommended for production)
2. **Local WebDriver** (Good for development)
3. **Remote WebDriver** (For cloud services)

## Quick Start

The scraper automatically detects the best method available on your system. Simply run:

```ruby
# The service will auto-detect and use the best available method
job_service = IndeedFetchJob.new(search_id, job_title)
results = job_service.fetch_jobs
```

## Setup Methods

### 1. Docker Method (Recommended)

**Advantages:**
- Consistent behavior across all platforms
- No local Chrome/ChromeDriver installation needed
- Isolated environment
- Easy to scale

**Requirements:**
- Docker installed and running

**Setup:**
```bash
# Install Docker (if not already installed)
# macOS: Download from docker.com or use Homebrew
brew install docker

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io

# Start Docker service (Linux)
sudo systemctl start docker
sudo systemctl enable docker
```

**Usage:**
```ruby
# Force Docker method
job_service = IndeedFetchJob.new(search_id, job_title)
results = job_service.fetch_jobs  # Auto-detects Docker if available
```

**Environment Variables:**
```bash
export USE_DOCKER_SELENIUM=true  # Force Docker usage
```

### 2. Local WebDriver Method

**Advantages:**
- Faster startup (no container overhead)
- Good for development
- Direct control over browser

**Requirements:**
- Google Chrome installed
- Internet connection (for automatic ChromeDriver download)

**Setup:**

**macOS:**
```bash
# Install Chrome if not already installed
brew install --cask google-chrome
```

**Ubuntu/Debian:**
```bash
# Install Chrome
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt-get update
sudo apt-get install google-chrome-stable
```

**Windows:**
Download and install Chrome from google.com/chrome

### 3. Remote WebDriver Method

**Advantages:**
- Works with cloud services (BrowserStack, Sauce Labs, etc.)
- No local setup required
- Can run on servers without GUI

**Setup:**
```bash
# Set remote URL
export SELENIUM_REMOTE_URL=http://your-selenium-grid:4444/wd/hub
```

## Environment Variables

You can control the scraper behavior with these environment variables:

```bash
# Force specific driver method
export SELENIUM_METHOD=docker          # Options: docker, local, remote, auto
export USE_DOCKER_SELENIUM=true       # Force Docker usage
export SELENIUM_REMOTE_URL=http://...  # Remote Selenium Grid URL

# Browser configuration
export SELENIUM_HEADLESS=false        # Run in headless mode
export SELENIUM_STEALTH=true          # Enable anti-detection features

# Timeouts
export SELENIUM_PAGE_TIMEOUT=30       # Page load timeout in seconds
export SELENIUM_IMPLICIT_TIMEOUT=10   # Implicit wait timeout
```

## Production Deployment

### Docker Compose Setup

Create `docker-compose.selenium.yml`:

```yaml
version: '3.8'
services:
  selenium-chrome:
    image: selenium/standalone-chrome:latest
    ports:
      - "4444:4444"
      - "7900:7900"  # VNC port for debugging
    shm_size: 2gb
    environment:
      - SE_NODE_MAX_SESSIONS=3
      - SE_NODE_SESSION_TIMEOUT=30
    restart: unless-stopped
    
  your-rails-app:
    build: .
    environment:
      - USE_DOCKER_SELENIUM=true
      - SELENIUM_REMOTE_URL=http://selenium-chrome:4444/wd/hub
    depends_on:
      - selenium-chrome
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: selenium-chrome
spec:
  replicas: 2
  selector:
    matchLabels:
      app: selenium-chrome
  template:
    metadata:
      labels:
        app: selenium-chrome
    spec:
      containers:
      - name: selenium-chrome
        image: selenium/standalone-chrome:latest
        ports:
        - containerPort: 4444
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        env:
        - name: SE_NODE_MAX_SESSIONS
          value: "3"
```

## Troubleshooting

### Common Issues

1. **ChromeDriver version mismatch:**
   ```bash
   # The webdrivers gem automatically handles this, but you can force update:
   bundle exec rails runner "Webdrivers::Chromedriver.update"
   ```

2. **Docker permission issues (Linux):**
   ```bash
   sudo usermod -aG docker $USER
   # Log out and back in
   ```

3. **Chrome not found:**
   ```bash
   # Check if Chrome is installed
   which google-chrome || which google-chrome-stable
   ```

4. **Network connectivity issues:**
   ```bash
   # Test Selenium Grid connectivity
   curl http://localhost:4444/status
   ```

### Debugging

1. **Enable VNC for Docker:**
   The Docker setup exposes port 7900 for VNC viewing. Connect with any VNC client to `localhost:7900` (password: `secret`)

2. **Check logs:**
   ```bash
   # Docker logs
   docker logs selenium-chrome-ply
   
   # Application logs
   tail -f log/development.log
   ```

3. **Test Selenium connectivity:**
   ```ruby
   # Rails console test
   driver = SeleniumConfig.create_driver(method: :auto)
   driver.get("https://www.google.com")
   puts driver.title
   driver.quit
   ```

## Security Considerations

1. **Use headless mode in production:**
   ```bash
   export SELENIUM_HEADLESS=true
   ```

2. **Limit container resources:**
   Set appropriate memory and CPU limits for Docker containers

3. **Network isolation:**
   Run Selenium containers in isolated networks

4. **Regular updates:**
   Keep Chrome and ChromeDriver updated using the webdrivers gem

## Performance Optimization

1. **Reuse containers:**
   Keep Docker containers running instead of starting/stopping them frequently

2. **Connection pooling:**
   For high-volume scraping, consider implementing WebDriver connection pooling

3. **Resource limits:**
   Set appropriate `--max_old_space_size` for Node.js processes in containers

4. **Parallel execution:**
   Run multiple Selenium instances for concurrent scraping (with rate limiting)

## Monitoring

Monitor your Selenium setup with:

1. **Container health checks**
2. **Resource usage monitoring**
3. **Success/failure rates**
4. **Response time tracking**

This setup ensures your Indeed scraper works consistently across development, staging, and production environments on any platform. 