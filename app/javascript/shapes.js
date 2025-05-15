// Shape animations and interactions

document.addEventListener('DOMContentLoaded', function() {
  // Initialize shapes
  initShapes();
  
  // Setup theme switcher
  setupThemeSwitcher();
});

// Initialize shape click interactions
function initShapes() {
  // Get all shape elements
  const shapes = document.querySelectorAll('.shape');
  const particlesContainer = document.getElementById('particles-container');
  
  if (!shapes.length) return;
  
  // Add click event listener to each shape
  shapes.forEach(shape => {
    shape.addEventListener('click', function(e) {
      // Create blast effect
      this.classList.add('blasting');
      
      // Create explosion particles
      createExplosionParticles(e, this);
      
      // Save reference to the shape
      const clickedShape = this;
      
      // After the blast animation completes, reposition the shape
      setTimeout(function() {
        // Generate random position values - more restricted to ensure visibility
        // Smaller values keep elements more centered in view
        const randomX = Math.random() * 60 - 30; // -30% to 30% from center
        const randomY = Math.random() * 60 - 30; // -30% to 30% from center
        
        // Reset the animation and position
        clickedShape.style.animationPlayState = 'paused';
        
        // Position at random location
        clickedShape.style.left = `calc(50% + ${randomX}%)`;
        clickedShape.style.top = `calc(50% + ${randomY}%)`;
        
        // Remove the blasting class
        clickedShape.classList.remove('blasting');
        
        // Force a reflow to ensure the animation restarts
        void clickedShape.offsetWidth;
        
        // Restart the animation
        clickedShape.style.animationPlayState = 'running';
        
        // Safety check - if shape is still out of view after a brief delay, reset to center
        setTimeout(() => {
          const rect = clickedShape.getBoundingClientRect();
          const windowWidth = window.innerWidth;
          const windowHeight = window.innerHeight;
          
          // If shape is completely off screen, reset position
          if (rect.right < 0 || rect.left > windowWidth || 
              rect.bottom < 0 || rect.top > windowHeight) {
            clickedShape.style.left = '50%';
            clickedShape.style.top = '50%';
          }
        }, 200);
      }, 400); // Match the blast animation duration
    });
  });
  
  // Check if any shapes have gone off-screen and reset them
  window.addEventListener('resize', resetOffscreenShapes);
  
  // Initial check
  setTimeout(resetOffscreenShapes, 1000);
}

// Reset any shapes that have gone off screen
function resetOffscreenShapes() {
  const shapes = document.querySelectorAll('.shape');
  const windowWidth = window.innerWidth;
  const windowHeight = window.innerHeight;
  
  shapes.forEach(shape => {
    const rect = shape.getBoundingClientRect();
    
    // If shape is completely off screen, reset position
    if (rect.right < 0 || rect.left > windowWidth || 
        rect.bottom < 0 || rect.top > windowHeight) {
      // Reset to center with small random offset
      const smallOffsetX = Math.random() * 20 - 10;
      const smallOffsetY = Math.random() * 20 - 10;
      shape.style.left = `calc(50% + ${smallOffsetX}%)`;
      shape.style.top = `calc(50% + ${smallOffsetY}%)`;
    }
  });
}

// Function to create explosion particles
function createExplosionParticles(event, element) {
  const particlesContainer = document.getElementById('particles-container');
  if (!particlesContainer) return;
  
  // Get the position of the click relative to the element
  const rect = element.getBoundingClientRect();
  const centerX = rect.left + rect.width / 2;
  const centerY = rect.top + rect.height / 2;
  
  // Get computed style to determine shape color
  const computedStyle = window.getComputedStyle(element);
  let color;
  
  // Try to extract color from different properties
  if (element.classList.contains('rounded-full') && element.style.backgroundColor) {
    color = element.style.backgroundColor;
  } else if (computedStyle.backgroundColor && computedStyle.backgroundColor !== 'rgba(0, 0, 0, 0)') {
    color = computedStyle.backgroundColor;
  } else if (computedStyle.borderColor && computedStyle.borderColor !== 'rgba(0, 0, 0, 0)') {
    color = computedStyle.borderColor;
  } else {
    // Default color if we can't determine
    color = element.id.includes('shape1') ? '#f59e0b' : 
            element.id.includes('shape3') ? '#2dd4bf' : 
            element.id.includes('shape4') ? '#71717a' : 
            element.id.includes('shape5') ? '#60a5fa' : 
            element.id.includes('shape6') ? '#c084fc' : 
            element.id.includes('shape7') ? '#818cf8' : 
            element.id.includes('shape8') ? '#34d399' : '#a1a1aa';
  }
  
  // Create multiple particles
  for (let i = 0; i < 20; i++) {
    const particle = document.createElement('div');
    particle.className = 'particle';
    
    // Random position within the element
    const offsetX = (Math.random() - 0.5) * rect.width * 0.8;
    const offsetY = (Math.random() - 0.5) * rect.height * 0.8;
    
    // Set initial position at the center of the clicked element
    particle.style.left = `${centerX + offsetX}px`;
    particle.style.top = `${centerY + offsetY}px`;
    
    // Random direction and distance for the particle to travel
    const angle = Math.random() * Math.PI * 2;
    const distance = 50 + Math.random() * 100;
    const tx = Math.cos(angle) * distance;
    const ty = Math.sin(angle) * distance;
    
    // Set custom properties for the animation
    particle.style.setProperty('--tx', `${tx}px`);
    particle.style.setProperty('--ty', `${ty}px`);
    
    // Set the particle color
    particle.style.backgroundColor = color;
    
    // Random size
    const size = 3 + Math.random() * 8;
    particle.style.width = `${size}px`;
    particle.style.height = `${size}px`;
    
    // Add to container
    particlesContainer.appendChild(particle);
    
    // Remove particle after animation completes
    setTimeout(() => {
      if (particle.parentNode) {
        particle.parentNode.removeChild(particle);
      }
    }, 600);
  }
}

// Setup theme switcher
function setupThemeSwitcher() {
  // Get all theme option buttons
  const themeButtons = document.querySelectorAll('[data-theme]');
  
  if (!themeButtons.length) return;
  
  // Add click event listener to each button
  themeButtons.forEach(button => {
    button.addEventListener('click', function() {
      const theme = this.getAttribute('data-theme');
      showTheme(theme);
    });
  });
  
  // Show first theme by default
  showTheme('1');
}

// Show selected theme
function showTheme(themeNumber) {
  // Hide all themes
  document.querySelectorAll('[id^="option"]').forEach(el => {
    el.classList.add('hidden');
  });
  
  // Show selected theme
  const selectedTheme = document.getElementById('option' + themeNumber);
  if (selectedTheme) {
    selectedTheme.classList.remove('hidden');
    
    // Reset any off-screen shapes when switching themes
    setTimeout(resetOffscreenShapes, 100);
  }
} 