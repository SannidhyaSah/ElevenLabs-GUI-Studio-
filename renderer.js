// HTML escape function to prevent XSS attacks
function escapeHtml(unsafe) {
  if (typeof unsafe !== 'string') return '';
  
  const div = document.createElement('div');
  div.textContent = unsafe;
  return div.innerHTML;
}

// DOM Elements
const apiKeyInput = document.getElementById('api-key-input');
const apiKeyNameInput = document.getElementById('api-key-name-input');
const apiKeySelect = document.getElementById('api-key-select');
const apiKeyStatus = document.getElementById('api-key-status');
const currentApiStatus = document.getElementById('current-api-status');
const statusIndicator = document.querySelector('.status-indicator');
const statusText = document.querySelector('.status-text');
const saveApiKeyBtn = document.getElementById('save-api-key');
const useApiKeyBtn = document.getElementById('use-api-key');
const deleteApiKeyBtn = document.getElementById('delete-api-key');
const tabButtons = document.querySelectorAll('.tab-button');
const tabPanes = document.querySelectorAll('.tab-pane');
const voiceSelect = document.getElementById('voice-select');
const modelSelect = document.getElementById('model-select');
const textInput = document.getElementById('text-input');
const newBtn = document.getElementById('new-btn');
const generateBtn = document.getElementById('generate-btn');
const playBtn = document.getElementById('play-btn');
const saveBtn = document.getElementById('save-btn');
const addBreakBtn = document.getElementById('add-break-btn');
const breakDurationInput = document.getElementById('break-duration');
const audioPlayer = document.getElementById('audio-player');
const voiceList = document.getElementById('voice-list');
const historyList = document.getElementById('history-list');
const addVoiceBtn = document.getElementById('add-voice-btn');
const refreshVoicesBtn = document.getElementById('refresh-voices-btn');
const refreshVoicesSelectBtn = document.getElementById('refresh-voices-select-btn');
const refreshModelsBtn = document.getElementById('refresh-models-btn');
const clearHistoryBtn = document.getElementById('clear-history-btn');

// Voice cloning elements
const voiceTabBtns = document.querySelectorAll('.voice-tab-btn');
const voiceTabContents = document.querySelectorAll('.voice-tab-content');
const cloneVoiceName = document.getElementById('clone-voice-name');
const cloneVoiceDescription = document.getElementById('clone-voice-description');
const cloneFileUpload = document.getElementById('clone-file-upload');
const cloneAudioInput = document.getElementById('clone-audio-input');
const cloneFileList = document.getElementById('clone-file-list');
const cloneVoiceLabels = document.getElementById('clone-voice-labels');
const createCloneBtn = document.getElementById('create-clone-btn');
const librarySearch = document.getElementById('library-search');
const libraryFilterCategory = document.getElementById('library-filter-category');
const libraryVoices = document.getElementById('library-voices');

// Sliders
const stabilitySlider = document.getElementById('stability-slider');
const similaritySlider = document.getElementById('similarity-slider');
const styleSlider = document.getElementById('style-slider');
const speedSlider = document.getElementById('speed-slider');
const stabilityValue = document.getElementById('stability-value');
const similarityValue = document.getElementById('similarity-value');
const styleValue = document.getElementById('style-value');
const speedValue = document.getElementById('speed-value');

// Preset elements
const presetSelect = document.getElementById('preset-select');
const presetNameInput = document.getElementById('preset-name-input');
const savePresetBtn = document.getElementById('save-preset-btn');
const deletePresetBtn = document.getElementById('delete-preset-btn');

// State
let currentAudioPath = null;
let voices = [];
let models = [];
let history = JSON.parse(localStorage.getItem('history') || '[]');

// Settings management
const SETTINGS_KEY = 'elevenlabs-gui-settings';
let settings = loadSettings();

function loadSettings() {
  try {
    const saved = localStorage.getItem(SETTINGS_KEY);
    if (saved) {
      return JSON.parse(saved);
    }
  } catch (error) {
    console.error('Error loading settings:', error);
  }
  
  // Return default settings
  return {
    voiceSettings: {
      stability: 0.5,
      similarity_boost: 0.75,
      style: 0,
      speed: 1.0
    },
    lastVoiceId: null,
    lastModelId: null,
    breakDuration: 1.5,
    theme: 'dark',
    autoPlay: true,
    presets: []
  };
}

function saveSettings() {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch (error) {
    console.error('Error saving settings:', error);
  }
}

// Apply saved voice settings
function applySavedSettings() {
  if (settings.voiceSettings) {
    if (stabilitySlider) {
      stabilitySlider.value = settings.voiceSettings.stability;
      stabilityValue.textContent = settings.voiceSettings.stability;
      updateSliderColor(stabilitySlider);
    }
    
    if (similaritySlider) {
      similaritySlider.value = settings.voiceSettings.similarity_boost;
      similarityValue.textContent = settings.voiceSettings.similarity_boost;
      updateSliderColor(similaritySlider);
    }
    
    if (styleSlider) {
      styleSlider.value = settings.voiceSettings.style;
      styleValue.textContent = settings.voiceSettings.style;
      updateSliderColor(styleSlider);
    }
    
    if (speedSlider) {
      speedSlider.value = settings.voiceSettings.speed;
      speedValue.textContent = settings.voiceSettings.speed;
      updateSliderColor(speedSlider);
    }
  }
  
  if (settings.breakDuration && breakDurationInput) {
    breakDurationInput.value = settings.breakDuration;
  }
}

// Preset Management Functions
function loadPresets() {
  if (!presetSelect) return;
  
  presetSelect.innerHTML = '<option value="">Select a preset...</option>';
  
  // Add default presets if no custom presets exist
  if (!settings.presets || settings.presets.length === 0) {
    settings.presets = [
      {
        name: 'Balanced',
        values: { stability: 0.5, similarity_boost: 0.75, style: 0, speed: 1.0 }
      },
      {
        name: 'Expressive',
        values: { stability: 0.3, similarity_boost: 0.65, style: 0.7, speed: 1.0 }
      },
      {
        name: 'Stable',
        values: { stability: 0.8, similarity_boost: 0.9, style: 0, speed: 1.0 }
      },
      {
        name: 'Fast Speech',
        values: { stability: 0.5, similarity_boost: 0.75, style: 0, speed: 1.5 }
      },
      {
        name: 'Slow & Clear',
        values: { stability: 0.7, similarity_boost: 0.8, style: 0, speed: 0.8 }
      }
    ];
    saveSettings();
  }
  
  // Populate preset select
  settings.presets.forEach((preset, index) => {
    const option = document.createElement('option');
    option.value = index;
    option.textContent = preset.name;
    presetSelect.appendChild(option);
  });
}

function savePreset(name) {
  const preset = {
    name: name,
    values: {
      stability: parseFloat(stabilitySlider.value),
      similarity_boost: parseFloat(similaritySlider.value),
      style: parseFloat(styleSlider.value),
      speed: parseFloat(speedSlider.value)
    }
  };
  
  // Check if preset with same name exists
  const existingIndex = settings.presets.findIndex(p => p.name === name);
  if (existingIndex >= 0) {
    if (confirm(`Preset "${name}" already exists. Do you want to overwrite it?`)) {
      settings.presets[existingIndex] = preset;
    } else {
      return false;
    }
  } else {
    settings.presets.push(preset);
  }
  
  saveSettings();
  loadPresets();
  return true;
}

function loadPreset(index) {
  if (index < 0 || index >= settings.presets.length) return;
  
  const preset = settings.presets[index];
  
  // Apply preset values
  if (stabilitySlider && preset.values.stability !== undefined) {
    stabilitySlider.value = preset.values.stability;
    stabilityValue.textContent = preset.values.stability;
    updateSliderColor(stabilitySlider);
  }
  
  if (similaritySlider && preset.values.similarity_boost !== undefined) {
    similaritySlider.value = preset.values.similarity_boost;
    similarityValue.textContent = preset.values.similarity_boost;
    updateSliderColor(similaritySlider);
  }
  
  if (styleSlider && preset.values.style !== undefined) {
    styleSlider.value = preset.values.style;
    styleValue.textContent = preset.values.style;
    updateSliderColor(styleSlider);
  }
  
  if (speedSlider && preset.values.speed !== undefined) {
    speedSlider.value = preset.values.speed;
    speedValue.textContent = preset.values.speed;
    updateSliderColor(speedSlider);
  }
  
  // Save as current settings
  settings.voiceSettings = { ...preset.values };
  saveSettings();
  
  showNotification(`Loaded preset: ${preset.name}`, 'success');
}

function deletePreset(index) {
  if (index < 0 || index >= settings.presets.length) return;
  
  const preset = settings.presets[index];
  
  // Don't allow deletion of default presets
  const defaultPresets = ['Balanced', 'Expressive', 'Stable', 'Fast Speech', 'Slow & Clear'];
  if (defaultPresets.includes(preset.name)) {
    showNotification('Cannot delete default presets', 'warning');
    return;
  }
  
  if (confirm(`Are you sure you want to delete the preset "${preset.name}"?`)) {
    settings.presets.splice(index, 1);
    saveSettings();
    loadPresets();
    showNotification(`Deleted preset: ${preset.name}`, 'success');
  }
}

// Notification system
function showNotification(message, type = 'info') {
  // Remove any existing notifications
  const existingNotification = document.querySelector('.notification');
  if (existingNotification) {
    existingNotification.remove();
  }

  const notification = document.createElement('div');
  notification.className = `notification notification-${type}`;
  notification.textContent = message;
  
  // Add to body
  document.body.appendChild(notification);
  
  // Auto-hide after 1 second
  setTimeout(() => {
    notification.classList.add('fade-out');
    setTimeout(() => notification.remove(), 200);
  }, 1000);
}

// Function to update slider color based on its value
function updateSliderColor(slider) {
  if (!slider) return;

  const value = parseFloat(slider.value);
  const min = parseFloat(slider.min) || 0;
  const max = parseFloat(slider.max) || 1;
  const percentage = ((value - min) / (max - min)) * 100;

  // Create the gradient background
  slider.style.background = `linear-gradient(to right, var(--primary-color) 0%, var(--primary-color) ${percentage}%, var(--button-color) ${percentage}%, var(--button-color) 100%)`;
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  console.log('DOM content loaded');

  // Check if API is available
  if (window.api) {
    console.log('API is available in window object');

    // Load saved API keys
    loadApiKeys();
  } else {
    console.error('API is not available in window object');
  }

  // Tab switching
  tabButtons.forEach(button => {
    button.addEventListener('click', () => {
      tabButtons.forEach(btn => btn.classList.remove('active'));
      tabPanes.forEach(pane => pane.classList.remove('active'));

      button.classList.add('active');
      document.getElementById(button.dataset.tab).classList.add('active');
    });
  });

  // Voice tab switching
  if (voiceTabBtns.length > 0) {
    voiceTabBtns.forEach(button => {
      button.addEventListener('click', () => {
        const targetTab = button.dataset.voiceTab;
        
        voiceTabBtns.forEach(btn => btn.classList.remove('active'));
        voiceTabContents.forEach(content => content.classList.remove('active'));
        
        button.classList.add('active');
        document.getElementById(targetTab).classList.add('active');
        
        // Load content for specific tabs
        if (targetTab === 'voice-library') {
          loadVoiceLibrary();
        }
      });
    });
  }

  // File upload handling for voice cloning
  let uploadedFiles = [];
  
  if (cloneFileUpload) {
    cloneFileUpload.addEventListener('click', () => {
      cloneAudioInput.click();
    });
    
    cloneFileUpload.addEventListener('dragover', (e) => {
      e.preventDefault();
      cloneFileUpload.classList.add('drag-over');
    });
    
    cloneFileUpload.addEventListener('dragleave', () => {
      cloneFileUpload.classList.remove('drag-over');
    });
    
    cloneFileUpload.addEventListener('drop', (e) => {
      e.preventDefault();
      cloneFileUpload.classList.remove('drag-over');
      handleFiles(e.dataTransfer.files);
    });
    
    cloneAudioInput.addEventListener('change', (e) => {
      handleFiles(e.target.files);
    });
  }
  
  function handleFiles(files) {
    for (const file of files) {
      if (file.type.startsWith('audio/')) {
        uploadedFiles.push(file);
        renderFileList();
      } else {
        showNotification(`${file.name} is not an audio file`, 'warning');
      }
    }
  }
  
  function renderFileList() {
    cloneFileList.innerHTML = '';
    uploadedFiles.forEach((file, index) => {
      const fileItem = document.createElement('div');
      fileItem.className = 'file-item';
      
      const fileName = document.createElement('span');
      fileName.textContent = file.name;
      
      const removeBtn = document.createElement('button');
      removeBtn.textContent = 'Remove';
      removeBtn.onclick = () => {
        uploadedFiles.splice(index, 1);
        renderFileList();
      };
      
      fileItem.appendChild(fileName);
      fileItem.appendChild(removeBtn);
      cloneFileList.appendChild(fileItem);
    });
  }

  // Initialize sliders with colors

  // Initialize all sliders
  [stabilitySlider, similaritySlider, styleSlider, speedSlider].forEach(slider => {
    if (slider) {
      updateSliderColor(slider);
    }
  });

  // Slider value updates with settings persistence
  stabilitySlider.addEventListener('input', () => {
    stabilityValue.textContent = stabilitySlider.value;
    updateSliderColor(stabilitySlider);
    settings.voiceSettings.stability = parseFloat(stabilitySlider.value);
    saveSettings();
  });

  similaritySlider.addEventListener('input', () => {
    similarityValue.textContent = similaritySlider.value;
    updateSliderColor(similaritySlider);
    settings.voiceSettings.similarity_boost = parseFloat(similaritySlider.value);
    saveSettings();
  });

  styleSlider.addEventListener('input', () => {
    styleValue.textContent = styleSlider.value;
    updateSliderColor(styleSlider);
    settings.voiceSettings.style = parseFloat(styleSlider.value);
    saveSettings();
  });

  speedSlider.addEventListener('input', () => {
    speedValue.textContent = speedSlider.value;
    updateSliderColor(speedSlider);
    settings.voiceSettings.speed = parseFloat(speedSlider.value);
    saveSettings();
  });

  // Add break button functionality
  addBreakBtn.addEventListener('click', () => {
    insertBreakTag(textInput, breakDurationInput, addBreakBtn);
  });

  // Allow pressing Enter in the break duration input to insert the break
  breakDurationInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      insertBreakTag(textInput, breakDurationInput, addBreakBtn);
    }
  });
  
  // Save break duration preference
  breakDurationInput.addEventListener('change', () => {
    settings.breakDuration = parseFloat(breakDurationInput.value) || 1.5;
    saveSettings();
  });

  // Apply saved settings
  applySavedSettings();
  
  // Load presets
  loadPresets();
  
  // Preset event listeners
  if (savePresetBtn) {
    savePresetBtn.addEventListener('click', () => {
      const name = presetNameInput.value.trim();
      if (!name) {
        showNotification('Please enter a preset name', 'warning');
        presetNameInput.focus();
        return;
      }
      
      if (savePreset(name)) {
        presetNameInput.value = '';
        showNotification(`Saved preset: ${name}`, 'success');
      }
    });
  }
  
  // Load preset button removed - preset loads on selection
  
  if (deletePresetBtn) {
    deletePresetBtn.addEventListener('click', () => {
      const selectedIndex = parseInt(presetSelect.value);
      if (isNaN(selectedIndex)) {
        showNotification('Please select a preset to delete', 'warning');
        return;
      }
      
      deletePreset(selectedIndex);
    });
  }
  
  if (presetSelect) {
    presetSelect.addEventListener('change', () => {
      const selectedIndex = parseInt(presetSelect.value);
      if (!isNaN(selectedIndex)) {
        loadPreset(selectedIndex);
      }
    });
  }
  
  // Allow pressing Enter in preset name input to save
  if (presetNameInput) {
    presetNameInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        savePresetBtn.click();
      }
    });
  }
  
  // Load history
  renderHistory();
});

// Function to insert a break tag at the cursor position
function insertBreakTag(inputElement, durationInput, button) {
  const duration = parseFloat(durationInput.value);

  // Validate the duration
  if (isNaN(duration) || duration <= 0 || duration > 10) {
    showNotification('Please enter a valid duration between 0.1 and 10 seconds.', 'warning');
    return;
  }

  // Format the duration to one decimal place
  const formattedDuration = duration.toFixed(1);

  // Create the break tag
  const breakTag = `<break time="${formattedDuration}s" />`;

  // Get cursor position
  const cursorPos = inputElement.selectionStart;
  const textBefore = inputElement.value.substring(0, cursorPos);
  const textAfter = inputElement.value.substring(cursorPos);

  // Insert the break tag at the cursor position
  inputElement.value = textBefore + breakTag + textAfter;

  // Set the cursor position after the inserted tag
  const newCursorPos = cursorPos + breakTag.length;
  inputElement.setSelectionRange(newCursorPos, newCursorPos);

  // Focus back on the text input
  inputElement.focus();

  // Show a brief visual feedback on the button
  button.classList.add('active');
  setTimeout(() => {
    button.classList.remove('active');
  }, 200);
}

// Load saved API keys
async function loadApiKeys() {
  try {
    const apiKeys = await window.api.getApiKeys();
    const currentApiKeyName = await window.api.getCurrentApiKeyName();

    // Clear and populate API key select
    apiKeySelect.innerHTML = '<option value="">Select a saved API key</option>';

    if (apiKeys.length > 0) {
      apiKeys.forEach(key => {
        const option = document.createElement('option');
        option.value = key.name;
        option.textContent = key.name;

        // Set the current API key as selected
        if (currentApiKeyName && key.name === currentApiKeyName) {
          option.selected = true;
          apiKeyStatus.innerHTML = `<span style="color: var(--success-color);">Active: ${currentApiKeyName}</span>`;

          // Update header status
          statusIndicator.classList.add('active');
          statusText.textContent = `API Key: ${currentApiKeyName}`;
        }

        apiKeySelect.appendChild(option);
      });

      // Enable buttons
      useApiKeyBtn.disabled = false;
      deleteApiKeyBtn.disabled = false;
    } else {
      // First-time user experience
      useApiKeyBtn.disabled = true;
      deleteApiKeyBtn.disabled = true;

      // Show a helpful message if this appears to be a first run
      if (!document.querySelector('.first-run-message')) {
        const message = document.createElement('div');
        message.className = 'first-run-message';
        message.innerHTML = `
          <button class="close-message-btn">&times;</button>
          <p>Welcome to ElevenLabs GUI Studio!</p>
          <p>To get started, please go to the <strong>Settings</strong> tab to add your ElevenLabs API key.</p>
          <p>You can get an API key from <a href="https://elevenlabs.io/speech-synthesis" target="_blank">ElevenLabs</a>.</p>
        `;

        // Insert at the top of the settings tab
        const settingsContainer = document.querySelector('.settings-container');
        settingsContainer.insertBefore(message, settingsContainer.firstChild);

        // Switch to the settings tab
        document.querySelector('.tab-button[data-tab="settings"]').click();

        // Add event listener to close button
        const closeBtn = message.querySelector('.close-message-btn');
        closeBtn.addEventListener('click', () => {
          message.classList.add('fade-out');
          setTimeout(() => {
            message.remove();
          }, 300); // Match this with the CSS animation duration
        });

        // Auto-focus the API key input after a short delay to ensure the tab has switched
        setTimeout(() => {
          apiKeyInput.focus();
        }, 100);
      }
    }
  } catch (error) {
    console.error('Error loading API keys:', error);
  }
}

// API Key handling
saveApiKeyBtn.addEventListener('click', async () => {
  const apiKey = apiKeyInput.value.trim();
  const keyName = apiKeyNameInput.value.trim();

  if (!apiKey) {
    showNotification('Please enter an API key', 'warning');
    apiKeyInput.focus();
    return;
  }

  if (!keyName) {
    showNotification('Please enter a name for this API key', 'warning');
    apiKeyNameInput.focus();
    return;
  }

  try {
    const result = await window.api.saveApiKey({ name: keyName, apiKey });

    if (result.success) {
      showNotification(`API key "${keyName}" saved successfully`, 'success');
      apiKeyInput.value = '';
      apiKeyNameInput.value = '';
      loadApiKeys();
      loadVoices();
      loadModels();
    } else {
      showNotification(result.error || 'Failed to save API key', 'error');
    }
  } catch (error) {
    console.error('Error:', error);
    showNotification(error.message || 'An unexpected error occurred', 'error');
  }
});

// Use selected API key
useApiKeyBtn.addEventListener('click', async () => {
  const selectedKeyName = apiKeySelect.value;

  if (!selectedKeyName) {
    showNotification('Please select an API key', 'warning');
    apiKeySelect.focus();
    return;
  }

  try {
    const result = await window.api.setApiKey(selectedKeyName);

    if (result.success) {
      // Update settings tab status
      apiKeyStatus.innerHTML = `<span style="color: var(--success-color);">Active: ${selectedKeyName}</span>`;
      apiKeyStatus.style.opacity = 1;

      // Update header status
      statusIndicator.classList.add('active');
      statusText.textContent = `API Key: ${selectedKeyName}`;

      // Briefly show success message
      const originalStatus = apiKeyStatus.innerHTML;
      apiKeyStatus.innerHTML = `<span style="color: var(--success-color);">✓ API key activated successfully</span>`;

      setTimeout(() => {
        apiKeyStatus.innerHTML = originalStatus;
      }, 2000);

      loadVoices();
      loadModels();
    } else {
      // Update error status
      apiKeyStatus.innerHTML = `<span style="color: var(--error-color);">Error: ${result.error}</span>`;
      statusIndicator.classList.remove('active');
      statusText.textContent = 'No API key in use';
      showNotification(result.error || 'Failed to save API key', 'error');
    }
  } catch (error) {
    console.error('Error:', error);
    showNotification(error.message || 'An unexpected error occurred', 'error');
  }
});

// Delete selected API key
deleteApiKeyBtn.addEventListener('click', async () => {
  const selectedKeyName = apiKeySelect.value;

  if (!selectedKeyName) {
    showNotification('Please select an API key to delete', 'warning');
    apiKeySelect.focus();
    return;
  }

  if (!confirm(`Are you sure you want to delete the API key "${selectedKeyName}"? This action cannot be undone.`)) {
    return;
  }

  try {
    const result = await window.api.deleteApiKey(selectedKeyName);

    if (result.success) {
      if (result.deleted) {
        showNotification(`API key "${selectedKeyName}" deleted successfully`, 'success');

        // Check if the current API key was deleted
        if (statusText.textContent.includes(selectedKeyName)) {
          // Reset header status
          statusIndicator.classList.remove('active');
          statusText.textContent = 'No API key in use';
        }

        loadApiKeys();
      } else {
        showNotification(`API key "${selectedKeyName}" not found`, 'error');
      }
    } else {
      showNotification(result.error || 'Failed to save API key', 'error');
    }
  } catch (error) {
    console.error('Error:', error);
    showNotification(error.message || 'An unexpected error occurred', 'error');
  }
});
// Load voices from API
async function loadVoices() {
  try {
    console.log('Loading voices...');

    // Check if API key is set before attempting to load voices
    const currentApiKeyName = await window.api.getCurrentApiKeyName();
    if (!currentApiKeyName) {
      console.warn('No API key set when loading voices');
      const noApiKeyMsg = 'No API key set. Please add an API key in Settings.';

      voiceSelect.innerHTML = `<option value="">${noApiKeyMsg}</option>`;
      return;
    }

    // Show loading state
    voiceSelect.innerHTML = '<option value="">Loading voices...</option>';

    // Disable refresh buttons during loading
    if (refreshVoicesSelectBtn) {
      refreshVoicesSelectBtn.disabled = true;
      refreshVoicesSelectBtn.innerHTML = '<span class="loading"></span>';
    }

    if (refreshVoicesBtn) {
      refreshVoicesBtn.disabled = true;
    }

    const result = await window.api.getVoices();
    console.log('Voices API response:', result);

    if (result.success) {
      // Make sure voices is an array
      if (!result.voices) {
        console.error('No voices in response:', result);
        voiceSelect.innerHTML = '<option value="">No voices available</option>';
        return;
      }

      voices = Array.isArray(result.voices) ? result.voices : [];
      console.log(`Loaded ${voices.length} voices`);

      if (voices.length === 0) {
        voiceSelect.innerHTML = '<option value="">No voices available</option>';
        return;
      }

      // Clear and populate main voice select
      voiceSelect.innerHTML = '';
      
      // Add event listener to save voice preference
      voiceSelect.addEventListener('change', () => {
        settings.lastVoiceId = voiceSelect.value;
        saveSettings();
      });

      // Safely iterate through voices for main select
      for (let i = 0; i < voices.length; i++) {
        const voice = voices[i];
        if (voice && voice.voice_id && voice.name) {
          const option = document.createElement('option');
          option.value = voice.voice_id;
          option.textContent = voice.name;
          voiceSelect.appendChild(option);
        }
      }

      // Restore last selected voice or select the first one
      if (settings.lastVoiceId && voices.some(v => v.voice_id === settings.lastVoiceId)) {
        voiceSelect.value = settings.lastVoiceId;
      } else if (voiceSelect.value === '') {
        voiceSelect.selectedIndex = 0;
      }

      // Populate voice list in management tab
      renderVoiceList();
    } else {
      console.error('Error loading voices:', result.error);

      // Check for authentication errors
      if (result.error && (result.error.includes('API key not set') ||
                          result.error.includes('401') ||
                          result.error.toLowerCase().includes('unauthorized'))) {
        const authErrorMsg = 'Authentication error. Please check your API key in Settings.';
        voiceSelect.innerHTML = `<option value="">${authErrorMsg}</option>`;
      } else {
        const errorMsg = `Error: ${result.error}`;
        voiceSelect.innerHTML = `<option value="">${errorMsg}</option>`;
      }
    }
  } catch (error) {
    console.error('Exception loading voices:', error);
    const errorMsg = `Error: ${error.message}`;
    voiceSelect.innerHTML = `<option value="">${errorMsg}</option>`;
  } finally {
    // Reset button states
    if (refreshVoicesSelectBtn) {
      refreshVoicesSelectBtn.disabled = false;
      // Always reset to the refresh icon
      refreshVoicesSelectBtn.innerHTML = '<i class="refresh-icon"></i>';
    }

    if (refreshVoicesBtn) {
      refreshVoicesBtn.disabled = false;
    }
  }
}

// Load models from API
async function loadModels() {
  try {
    console.log('Loading models...');

    // Check if API key is set before attempting to load models
    const currentApiKeyName = await window.api.getCurrentApiKeyName();
    if (!currentApiKeyName) {
      console.warn('No API key set when loading models');
      const noApiKeyMsg = 'No API key set. Please add an API key in Settings.';

      modelSelect.innerHTML = `<option value="">${noApiKeyMsg}</option>`;
      return;
    }

    // Show loading state
    modelSelect.innerHTML = '<option value="">Loading models...</option>';

    // Disable refresh button during loading
    if (refreshModelsBtn) {
      refreshModelsBtn.disabled = true;
      refreshModelsBtn.innerHTML = '<span class="loading"></span>';
    }

    const result = await window.api.getModels();
    console.log('Models API response:', result);

    if (result.success) {
      // Make sure models is an array
      if (!result.models) {
        console.error('No models in response:', result);
        modelSelect.innerHTML = '<option value="">No models available</option>';
        return;
      }

      models = Array.isArray(result.models) ? result.models : [];
      console.log(`Loaded ${models.length} models`);

      if (models.length === 0) {
        modelSelect.innerHTML = '<option value="">No models available</option>';
        return;
      }

      // Clear and populate model select
      modelSelect.innerHTML = '';
      
      // Add event listener to save model preference
      modelSelect.addEventListener('change', () => {
        settings.lastModelId = modelSelect.value;
        saveSettings();
      });

      // Safely iterate through models
      for (let i = 0; i < models.length; i++) {
        const model = models[i];
        if (model && model.model_id && model.name) {
          const option = document.createElement('option');
          option.value = model.model_id;
          option.textContent = model.name;
          modelSelect.appendChild(option);
        }
      }

      // Restore last selected model or select the first one
      if (settings.lastModelId && models.some(m => m.model_id === settings.lastModelId)) {
        modelSelect.value = settings.lastModelId;
      } else if (modelSelect.value === '') {
        modelSelect.selectedIndex = 0;
      }
    } else {
      console.error('Error loading models:', result.error);

      // Check for authentication errors
      if (result.error && (result.error.includes('API key not set') ||
                          result.error.includes('401') ||
                          result.error.toLowerCase().includes('unauthorized'))) {
        const authErrorMsg = 'Authentication error. Please check your API key in Settings.';
        modelSelect.innerHTML = `<option value="">${authErrorMsg}</option>`;
      } else {
        const errorMsg = `Error: ${result.error}`;
        modelSelect.innerHTML = `<option value="">${errorMsg}</option>`;
      }
    }
  } catch (error) {
    console.error('Exception loading models:', error);
    const errorMsg = `Error: ${error.message}`;
    modelSelect.innerHTML = `<option value="">${errorMsg}</option>`;
  } finally {
    // Reset button state
    if (refreshModelsBtn) {
      refreshModelsBtn.disabled = false;
      // Always reset to the refresh icon
      refreshModelsBtn.innerHTML = '<i class="refresh-icon"></i>';
    }
  }
}

// Render voice list in management tab
function renderVoiceList() {
  if (!voiceList) return;

  voiceList.innerHTML = '';

  if (voices.length === 0) {
    voiceList.innerHTML = '<div class="empty-message">No voices available</div>';
    return;
  }

  voices.forEach(voice => {
    const voiceCard = document.createElement('div');
    voiceCard.className = 'voice-card';
    // Create elements safely to prevent XSS
    const voiceInfo = document.createElement('div');
    voiceInfo.className = 'voice-info';
    
    const voiceName = document.createElement('h3');
    voiceName.textContent = voice.name;
    
    const voiceDesc = document.createElement('p');
    voiceDesc.textContent = voice.description || 'No description available';
    
    const voiceMeta = document.createElement('span');
    voiceMeta.className = 'voice-meta';
    voiceMeta.textContent = voice.category || 'Unknown category';
    
    voiceInfo.appendChild(voiceName);
    voiceInfo.appendChild(voiceDesc);
    voiceInfo.appendChild(voiceMeta);
    
    const voiceActions = document.createElement('div');
    voiceActions.className = 'voice-card-actions';
    
    const useButton = document.createElement('button');
    useButton.className = 'use-voice-btn';
    useButton.textContent = 'Use';
    useButton.dataset.voiceId = voice.voice_id;
    
    voiceActions.appendChild(useButton);
    
    voiceCard.appendChild(voiceInfo);
    voiceCard.appendChild(voiceActions);

    voiceList.appendChild(voiceCard);

    // Add event listener to use voice button
    const useVoiceBtn = voiceCard.querySelector('.use-voice-btn');
    useVoiceBtn.addEventListener('click', () => {
      voiceSelect.value = voice.voice_id;
      // Switch to the Text to Speech tab
      document.querySelector('.tab-button[data-tab="tts"]').click();
    });
  });
}

// Render history list
function renderHistory() {
  if (!historyList) return;

  historyList.innerHTML = '';

  if (history.length === 0) {
    historyList.innerHTML = '<div class="empty-message">No history yet</div>';
    return;
  }

  history.forEach(item => {
    const historyItem = document.createElement('div');
    historyItem.className = 'history-item';
    // Create elements safely to prevent XSS
    const header = document.createElement('div');
    header.className = 'history-item-header';
    
    const title = document.createElement('h3');
    title.textContent = item.voiceName || 'Unknown voice';
    
    const date = document.createElement('span');
    date.textContent = item.date || 'Unknown date';
    
    header.appendChild(title);
    header.appendChild(date);
    
    const textDiv = document.createElement('div');
    textDiv.className = 'history-item-text';
    textDiv.textContent = item.text || 'No text';
    
    const footer = document.createElement('div');
    footer.className = 'history-item-footer';
    
    const audioStatus = document.createElement('div');
    audioStatus.className = `audio-status ${item.audioPath ? 'available' : 'missing'}`;
    audioStatus.textContent = item.audioPath ? 'Audio available' : 'Audio not available';
    
    const actions = document.createElement('div');
    actions.className = 'history-actions';
    
    if (item.audioPath) {
      const playButton = document.createElement('button');
      playButton.className = 'history-play';
      playButton.textContent = 'Play';
      playButton.dataset.path = item.audioPath;
      actions.appendChild(playButton);
    }
    
    const useButton = document.createElement('button');
    useButton.className = 'history-use';
    useButton.textContent = 'Use Text';
    useButton.dataset.id = item.id;
    
    const deleteButton = document.createElement('button');
    deleteButton.className = 'history-delete';
    deleteButton.textContent = 'Delete';
    deleteButton.dataset.id = item.id;
    
    actions.appendChild(useButton);
    actions.appendChild(deleteButton);
    
    footer.appendChild(audioStatus);
    footer.appendChild(actions);
    
    historyItem.appendChild(header);
    historyItem.appendChild(textDiv);
    historyItem.appendChild(footer);

    historyList.appendChild(historyItem);

    // Add event listeners to history item buttons
    if (item.audioPath) {
      const playBtn = historyItem.querySelector('.history-play');
      playBtn.addEventListener('click', async () => {
        await playAudio(item.audioPath);
      });
    }

    const useBtn = historyItem.querySelector('.history-use');
    useBtn.addEventListener('click', () => {
      textInput.value = item.text;
      if (item.voiceId) {
        voiceSelect.value = item.voiceId;
      }
      if (item.modelId) {
        modelSelect.value = item.modelId;
      }
      // Switch to the Text to Speech tab
      document.querySelector('.tab-button[data-tab="tts"]').click();
    });

    const deleteBtn = historyItem.querySelector('.history-delete');
    deleteBtn.addEventListener('click', () => {
      if (confirm('Are you sure you want to delete this history item?')) {
        deleteHistoryItem(item.id);
      }
    });
  });
}
// Delete history item
function deleteHistoryItem(id) {
  history = history.filter(item => item.id !== id);
  localStorage.setItem('history', JSON.stringify(history));
  renderHistory();
}

// Clear all history
clearHistoryBtn.addEventListener('click', () => {
  if (confirm('Are you sure you want to clear all history? This action cannot be undone.')) {
    history = [];
    localStorage.setItem('history', JSON.stringify(history));
    renderHistory();
  }
});

// Play audio
async function playAudio(path) {
  if (!path) {
    showNotification('No audio file to play', 'error');
    return;
  }

  try {
    // Check if file exists first
    const exists = await window.api.checkFileExists(path);
    if (!exists) {
      showNotification('Audio file not found. It may have been moved or deleted.', 'error');
      return;
    }

    currentAudioPath = path;
    audioPlayer.src = `file://${path}`;
    
    // Add error handling for audio playback
    audioPlayer.onerror = () => {
      showNotification('Failed to play audio file', 'error');
      audioPlayer.src = '';
    };
    
    await audioPlayer.play();
  } catch (error) {
    console.error('Error playing audio:', error);
    showNotification('Error playing audio file', 'error');
  }
}

// Generate audio
generateBtn.addEventListener('click', async () => {
  const text = textInput.value.trim();
  const voiceId = voiceSelect.value;
  const modelId = modelSelect.value;

  if (!text) {
    showNotification('Please enter some text to convert to speech', 'warning');
    textInput.focus();
    return;
  }

  if (!voiceId) {
    showNotification('Please select a voice', 'warning');
    voiceSelect.focus();
    return;
  }

  if (!modelId) {
    showNotification('Please select a model', 'warning');
    modelSelect.focus();
    return;
  }

  // Get and validate voice settings
  const voiceSettings = validateVoiceSettings({
    stability: parseFloat(stabilitySlider.value),
    similarity_boost: parseFloat(similaritySlider.value),
    style: parseFloat(styleSlider.value),
    use_speaker_boost: true,
    speed: parseFloat(speedSlider.value)
  });

  // Log the voice settings for debugging
  console.log('Voice settings being sent to main process:', voiceSettings);

  // Disable button and show loading state
  generateBtn.disabled = true;
  generateBtn.innerHTML = '<span class="loading"></span> Generating...';

  try {
    const result = await window.api.generateSpeech({
      text,
      voiceId,
      modelId,
      voiceSettings
    });

    if (result.success) {
      // Play the generated audio
      await playAudio(result.audioPath);
      showNotification('Speech generated successfully!', 'success');

      // Enable save button
      saveBtn.disabled = false;

      // Add to history
      addToHistory(text, voiceId, modelId, voiceSettings, result.audioPath);
    } else {
      showNotification(result.error || 'Failed to generate speech', 'error');
    }
  } catch (error) {
    console.error('Generate speech error:', error);
    showNotification(error.message || 'An unexpected error occurred', 'error');
  } finally {
    // Reset button state
    generateBtn.disabled = false;
    generateBtn.innerHTML = 'Generate';
  }
});

// Save audio
saveBtn.addEventListener('click', async () => {
  if (!currentAudioPath) {
    showNotification('No audio to save. Generate speech first.', 'warning');
    return;
  }

  try {
    const result = await window.api.saveAudio({
      audioPath: currentAudioPath
    });

    if (result.success) {
      showNotification(`Audio saved successfully!`, 'success');
    } else {
      showNotification(result.error || 'Failed to save audio', 'error');
    }
  } catch (error) {
    console.error('Save audio error:', error);
    showNotification(error.message || 'Failed to save audio file', 'error');
  }
});

// Play button
playBtn.addEventListener('click', () => {
  if (audioPlayer.paused) {
    audioPlayer.play();
    playBtn.innerHTML = '<i class="pause-icon"></i>';
  } else {
    audioPlayer.pause();
    playBtn.innerHTML = '<i class="play-icon"></i>';
  }
});

// Audio player events
audioPlayer.addEventListener('play', () => {
  playBtn.innerHTML = '<i class="pause-icon"></i>';
});

audioPlayer.addEventListener('pause', () => {
  playBtn.innerHTML = '<i class="play-icon"></i>';
});

audioPlayer.addEventListener('ended', () => {
  playBtn.innerHTML = '<i class="play-icon"></i>';
});

// Function to validate voice settings and ensure they are within valid ranges
// This follows the exact format expected by the Eleven Labs API
function validateVoiceSettings(settings) {
  // Create a new object with validated values according to the API documentation
  const validatedSettings = {
    // Stability (0-1): Controls how stable/consistent the voice is
    // Lower values allow for more emotional range, higher values are more monotonous
    stability: isNaN(parseFloat(settings.stability)) ? 0.5 : Math.max(0, Math.min(1, parseFloat(settings.stability))),

    // Similarity Boost (0-1): Controls how closely the AI adheres to the original voice
    // Higher values make it sound more like the original speaker
    similarity_boost: isNaN(parseFloat(settings.similarity_boost)) ? 0.75 : Math.max(0, Math.min(1, parseFloat(settings.similarity_boost))),

    // Style (0-1): Controls style exaggeration of the voice
    // Higher values amplify the style of the original speaker
    style: isNaN(parseFloat(settings.style)) ? 0.5 : Math.max(0, Math.min(1, parseFloat(settings.style))),

    // Use Speaker Boost: Boosts similarity to the original speaker
    // Boolean value that enhances voice similarity but may increase latency
    use_speaker_boost: settings.use_speaker_boost !== undefined ? Boolean(settings.use_speaker_boost) : true
  };

  // Speed (0.5-2.0): Controls the speed of the generated speech
  // Lower values create slower speech, higher values create faster speech
  if (settings.speed !== undefined) {
    const speed = parseFloat(settings.speed);
    if (!isNaN(speed)) {
      validatedSettings.speed = Math.max(0.5, Math.min(2.0, speed));
    } else {
      validatedSettings.speed = 1.0; // Default speed
    }
  }

  return validatedSettings;
}

// Function to reset voice settings to defaults according to Eleven Labs API documentation
function resetVoiceSettings() {
  // Default values according to Eleven Labs API documentation
  stabilitySlider.value = 0.5;      // Default stability (balanced between consistency and emotion)
  similaritySlider.value = 0.75;    // Default similarity boost (good voice similarity)
  styleSlider.value = 0.0;          // Default style (no style exaggeration)
  speedSlider.value = 1.0;          // Default speed (normal pace)

  // Update displayed values
  stabilityValue.textContent = stabilitySlider.value;
  similarityValue.textContent = similaritySlider.value;
  styleValue.textContent = styleSlider.value;
  speedValue.textContent = speedSlider.value;

  // Update slider colors
  updateSliderColor(stabilitySlider);
  updateSliderColor(similaritySlider);
  updateSliderColor(styleSlider);
  updateSliderColor(speedSlider);

  console.log('Voice settings reset to defaults');
}

// New button
newBtn.addEventListener('click', () => {
  textInput.value = '';
  textInput.focus();

  // Optionally reset voice settings to defaults
  // Uncomment the line below if you want to reset settings on new
  // resetVoiceSettings();
});

// Refresh voices button
refreshVoicesBtn.addEventListener('click', () => {
  loadVoices();
});

// Refresh voices select button
refreshVoicesSelectBtn.addEventListener('click', () => {
  loadVoices();
});

// Refresh models button
refreshModelsBtn.addEventListener('click', () => {
  loadModels();
});

// Function to test if voice settings are working
async function testVoiceSettings() {
  // Create a test message that demonstrates the effect of different settings
  const testText = "This is a test of the voice settings. You should hear changes in my voice based on the current settings.";

  // Get current voice settings
  const currentSettings = {
    stability: parseFloat(stabilitySlider.value),
    similarity_boost: parseFloat(similaritySlider.value),
    style: parseFloat(styleSlider.value),
    use_speaker_boost: true,
    speed: parseFloat(speedSlider.value)
  };

  // Update slider colors to match current values
  updateSliderColor(stabilitySlider);
  updateSliderColor(similaritySlider);
  updateSliderColor(styleSlider);
  updateSliderColor(speedSlider);

  // Show what settings are being tested
  showNotification(`Testing with: Stability=${currentSettings.stability}, Similarity=${currentSettings.similarity_boost}, Style=${currentSettings.style}, Speed=${currentSettings.speed}`, 'info');

  // Generate speech with current settings
  try {
    const result = await window.api.generateSpeech({
      text: testText,
      voiceId: voiceSelect.value,
      modelId: modelSelect.value,
      voiceSettings: validateVoiceSettings(currentSettings)
    });

    if (result.success) {
      // Play the generated audio
      audioPlayer.src = result.audioPath;
      audioPlayer.play();
      playBtn.innerHTML = '<i class="pause-icon"></i>';
      showNotification('Test completed successfully. Listen to hear the effect of your settings.', 'success');
    } else {
      showNotification('Test failed: ' + result.error, 'error');
    }
  } catch (error) {
    showNotification('Error testing voice settings: ' + error.message, 'error');
  }
}

// Test settings button
const testSettingsBtn = document.getElementById('test-settings-btn');
if (testSettingsBtn) {
  testSettingsBtn.addEventListener('click', () => {
    // Check if a voice is selected
    if (!voiceSelect.value) {
      showNotification('Please select a voice first', 'error');
      return;
    }

    // Check if a model is selected
    if (!modelSelect.value) {
      showNotification('Please select a model first', 'error');
      return;
    }

    // Test the current voice settings
    testVoiceSettings();
  });
}

// Reset settings button
const resetSettingsBtn = document.getElementById('reset-settings-btn');
if (resetSettingsBtn) {
  resetSettingsBtn.addEventListener('click', () => {
    if (confirm('Reset all voice parameters to default values?')) {
      resetVoiceSettings();
      showNotification('Voice parameters reset to defaults', 'success');

      // Optionally test with default settings
      if (confirm('Would you like to test the default settings?')) {
        testVoiceSettings();
      }
    }
  });
}

// Add to history
function addToHistory(text, voiceId, modelId, voiceSettings, audioPath) {
  const voice = voices.find(v => v.voice_id === voiceId);
  const model = models.find(m => m.model_id === modelId);

  const historyItem = {
    id: Date.now(),
    date: new Date().toLocaleString(),
    text,
    voiceId,
    voiceName: voice ? voice.name : 'Unknown voice',
    modelId,
    modelName: model ? model.name : 'Unknown model',
    voiceSettings,
    audioPath
  };

  history.unshift(historyItem);

  // Limit history to 20 items
  if (history.length > 20) {
    history = history.slice(0, 20);
  }

  // Save to localStorage
  localStorage.setItem('history', JSON.stringify(history));

  // Update history display
  renderHistory();
}

// Duplicate showNotification function removed - using the one defined earlier

// Format time in seconds to MM:SS format
function formatTime(timeInSeconds) {
  if (isNaN(timeInSeconds)) return '00:00';

  const minutes = Math.floor(timeInSeconds / 60);
  const seconds = Math.floor(timeInSeconds % 60);
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

// Voice cloning functionality
if (createCloneBtn) {
  createCloneBtn.addEventListener('click', async () => {
    const name = cloneVoiceName.value.trim();
    const description = cloneVoiceDescription.value.trim();
    const labels = cloneVoiceLabels.value.trim();
    
    if (!name) {
      showNotification('Please enter a name for your voice clone', 'warning');
      cloneVoiceName.focus();
      return;
    }
    
    if (uploadedFiles.length === 0) {
      showNotification('Please upload at least one audio file', 'warning');
      return;
    }
    
    createCloneBtn.disabled = true;
    createCloneBtn.innerHTML = '<span class="loading"></span> Creating voice clone...';
    
    try {
      // Convert files to base64
      const audioSamples = await Promise.all(uploadedFiles.map(file => {
        return new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = () => resolve({
            name: file.name,
            data: reader.result.split(',')[1] // Remove data:audio/...;base64, prefix
          });
          reader.onerror = reject;
          reader.readAsDataURL(file);
        });
      }));
      
      const result = await window.api.cloneVoice({
        name,
        description,
        labels: labels ? labels.split(',').map(l => l.trim()) : [],
        files: audioSamples
      });
      
      if (result.success) {
        showNotification('Voice clone created successfully!', 'success');
        // Clear form
        cloneVoiceName.value = '';
        cloneVoiceDescription.value = '';
        cloneVoiceLabels.value = '';
        uploadedFiles = [];
        renderFileList();
        // Refresh voice list
        loadVoices();
        // Switch to My Voices tab
        document.querySelector('.voice-tab-btn[data-voice-tab="my-voices"]').click();
      } else {
        showNotification(result.error || 'Failed to create voice clone', 'error');
      }
    } catch (error) {
      console.error('Voice clone error:', error);
      showNotification(error.message || 'Failed to create voice clone', 'error');
    } finally {
      createCloneBtn.disabled = false;
      createCloneBtn.innerHTML = 'Create Voice Clone';
    }
  });
}

// Load voice library
async function loadVoiceLibrary() {
  if (!libraryVoices) return;
  
  libraryVoices.innerHTML = '<p>Loading voice library...</p>';
  
  try {
    const result = await window.api.getVoiceLibrary();
    
    if (result.success && result.voices) {
      displayLibraryVoices(result.voices);
    } else {
      libraryVoices.innerHTML = '<p>Failed to load voice library</p>';
    }
  } catch (error) {
    console.error('Error loading voice library:', error);
    libraryVoices.innerHTML = '<p>Error loading voice library</p>';
  }
}

// Display library voices
function displayLibraryVoices(voices) {
  if (!libraryVoices) return;
  
  libraryVoices.innerHTML = '';
  
  if (voices.length === 0) {
    libraryVoices.innerHTML = '<p>No voices found in library</p>';
    return;
  }
  
  voices.forEach(voice => {
    const voiceCard = document.createElement('div');
    voiceCard.className = 'voice-card';
    
    const voiceInfo = document.createElement('div');
    voiceInfo.className = 'voice-info';
    
    const voiceName = document.createElement('h3');
    voiceName.textContent = voice.name;
    
    const voiceDesc = document.createElement('p');
    voiceDesc.textContent = voice.description || 'No description available';
    
    const voiceMeta = document.createElement('span');
    voiceMeta.className = 'voice-meta';
    voiceMeta.textContent = voice.category || 'Unknown category';
    
    voiceInfo.appendChild(voiceName);
    voiceInfo.appendChild(voiceDesc);
    voiceInfo.appendChild(voiceMeta);
    
    const voiceActions = document.createElement('div');
    voiceActions.className = 'voice-card-actions';
    
    const addButton = document.createElement('button');
    addButton.textContent = 'Add to My Voices';
    addButton.onclick = async () => {
      addButton.disabled = true;
      addButton.textContent = 'Adding...';
      
      try {
        const result = await window.api.addVoiceFromLibrary(voice.voice_id);
        if (result.success) {
          showNotification('Voice added successfully!', 'success');
          loadVoices();
        } else {
          showNotification(result.error || 'Failed to add voice', 'error');
        }
      } catch (error) {
        showNotification('Failed to add voice', 'error');
      } finally {
        addButton.disabled = false;
        addButton.textContent = 'Add to My Voices';
      }
    };
    
    voiceActions.appendChild(addButton);
    
    voiceCard.appendChild(voiceInfo);
    voiceCard.appendChild(voiceActions);
    libraryVoices.appendChild(voiceCard);
  });
}

// Search and filter library voices
if (librarySearch) {
  librarySearch.addEventListener('input', filterLibraryVoices);
}

if (libraryFilterCategory) {
  libraryFilterCategory.addEventListener('change', filterLibraryVoices);
}

function filterLibraryVoices() {
  const searchTerm = librarySearch ? librarySearch.value.toLowerCase() : '';
  const category = libraryFilterCategory ? libraryFilterCategory.value : '';
  
  const voiceCards = libraryVoices.querySelectorAll('.voice-card');
  
  voiceCards.forEach(card => {
    const name = card.querySelector('h3').textContent.toLowerCase();
    const desc = card.querySelector('p').textContent.toLowerCase();
    const cardCategory = card.querySelector('.voice-meta').textContent.toLowerCase();
    
    const matchesSearch = !searchTerm || name.includes(searchTerm) || desc.includes(searchTerm);
    const matchesCategory = !category || cardCategory.includes(category.toLowerCase());
    
    card.style.display = matchesSearch && matchesCategory ? 'block' : 'none';
  });
}
