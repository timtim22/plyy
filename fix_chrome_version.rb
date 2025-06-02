#!/usr/bin/env ruby

# Quick fix script to manually setup ChromeDriver
# Run this with: ruby fix_chrome_version.rb

require 'webdrivers/chromedriver'

puts "🔧 Setting up ChromeDriver manually..."

begin
  # Clear any existing cached versions
  puts "🧹 Clearing cached ChromeDriver..."
  Webdrivers::Chromedriver.remove rescue nil
  
  # Set a known working version
  puts "⬇️ Setting ChromeDriver to version 114.0.5735.90..."
  Webdrivers::Chromedriver.required_version = '114.0.5735.90'
  
  # Force download
  puts "📦 Downloading ChromeDriver..."
  Webdrivers::Chromedriver.update
  
  puts "✅ ChromeDriver setup complete!"
  puts "🚀 Now try running your scraper again"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts ""
  puts "🐳 Alternative: Install Docker instead:"
  puts "   brew install --cask docker"
  puts "   Then set: export FORCE_DOCKER_SELENIUM=true"
end 