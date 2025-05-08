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

// Sliders
const stabilitySlider = document.getElementById('stability-slider');
const similaritySlider = document.getElementById('similarity-slider');
const styleSlider = document.getElementById('style-slider');
const speedSlider = document.getElementById('speed-slider');
const stabilityValue = document.getElementById('stability-value');
const similarityValue = document.getElementById('similarity-value');
const styleValue = document.getElementById('style-value');
const speedValue = document.getElementById('speed-value');

// State
let currentAudioPath = null;
let voices = [];
let models = [];
let history = JSON.parse(localStorage.getItem('history') || '[]');

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

  // Initialize sliders with colors

  // Initialize all sliders
  [stabilitySlider, similaritySlider, styleSlider, speedSlider].forEach(slider => {
    if (slider) {
      updateSliderColor(slider);
    }
  });

  // Slider value updates
  stabilitySlider.addEventListener('input', () => {
    stabilityValue.textContent = stabilitySlider.value;
    updateSliderColor(stabilitySlider);
  });

  similaritySlider.addEventListener('input', () => {
    similarityValue.textContent = similaritySlider.value;
    updateSliderColor(similaritySlider);
  });

  styleSlider.addEventListener('input', () => {
    styleValue.textContent = styleSlider.value;
    updateSliderColor(styleSlider);
  });

  speedSlider.addEventListener('input', () => {
    speedValue.textContent = speedSlider.value;
    updateSliderColor(speedSlider);
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

  // Load history
  renderHistory();
});

// Function to insert a break tag at the cursor position
function insertBreakTag(inputElement, durationInput, button) {
  const duration = parseFloat(durationInput.value);

  // Validate the duration
  if (isNaN(duration) || duration <= 0 || duration > 10) {
    alert('Please enter a valid duration between 0.1 and 10 seconds.');
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
    alert('Please enter an API key');
    return;
  }

  if (!keyName) {
    alert('Please enter a name for this API key');
    return;
  }

  try {
    const result = await window.api.saveApiKey({ name: keyName, apiKey });

    if (result.success) {
      alert(`API key "${keyName}" saved successfully`);
      apiKeyInput.value = '';
      apiKeyNameInput.value = '';
      loadApiKeys();
      loadVoices();
      loadModels();
    } else {
      alert(`Error: ${result.error}`);
    }
  } catch (error) {
    alert(`Error: ${error.message}`);
  }
});

// Use selected API key
useApiKeyBtn.addEventListener('click', async () => {
  const selectedKeyName = apiKeySelect.value;

  if (!selectedKeyName) {
    alert('Please select an API key');
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
      alert(`Error: ${result.error}`);
    }
  } catch (error) {
    alert(`Error: ${error.message}`);
  }
});

// Delete selected API key
deleteApiKeyBtn.addEventListener('click', async () => {
  const selectedKeyName = apiKeySelect.value;

  if (!selectedKeyName) {
    alert('Please select an API key to delete');
    return;
  }

  if (!confirm(`Are you sure you want to delete the API key "${selectedKeyName}"? This action cannot be undone.`)) {
    return;
  }

  try {
    const result = await window.api.deleteApiKey(selectedKeyName);

    if (result.success) {
      if (result.deleted) {
        alert(`API key "${selectedKeyName}" deleted successfully`);

        // Check if the current API key was deleted
        if (statusText.textContent.includes(selectedKeyName)) {
          // Reset header status
          statusIndicator.classList.remove('active');
          statusText.textContent = 'No API key in use';
        }

        loadApiKeys();
      } else {
        alert(`API key "${selectedKeyName}" not found`);
      }
    } else {
      alert(`Error: ${result.error}`);
    }
  } catch (error) {
    alert(`Error: ${error.message}`);
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

      // Select the first voice by default if none is selected
      if (voiceSelect.value === '') {
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

      // Select the first model by default if none is selected
      if (modelSelect.value === '') {
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
    voiceCard.innerHTML = `
      <div class="voice-info">
        <h3>${voice.name}</h3>
        <p>${voice.description || 'No description available'}</p>
        <span class="voice-meta">${voice.category || 'Unknown category'}</span>
      </div>
      <div class="voice-card-actions">
        <button class="use-voice-btn" data-voice-id="${voice.voice_id}">Use</button>
      </div>
    `;

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
    historyItem.innerHTML = `
      <div class="history-item-header">
        <h3>${item.voiceName || 'Unknown voice'}</h3>
        <span>${item.date || 'Unknown date'}</span>
      </div>
      <div class="history-item-text">${item.text || 'No text'}</div>
      <div class="history-item-footer">
        <div class="audio-status ${item.audioPath ? 'available' : 'missing'}">
          ${item.audioPath ? 'Audio available' : 'Audio not available'}
        </div>
        <div class="history-actions">
          ${item.audioPath ? `<button class="history-play" data-path="${item.audioPath}">Play</button>` : ''}
          <button class="history-use" data-id="${item.id}">Use Text</button>
          <button class="history-delete" data-id="${item.id}">Delete</button>
        </div>
      </div>
    `;

    historyList.appendChild(historyItem);

    // Add event listeners to history item buttons
    if (item.audioPath) {
      const playBtn = historyItem.querySelector('.history-play');
      playBtn.addEventListener('click', () => {
        playAudio(item.audioPath);
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
function playAudio(path) {
  if (!path) return;

  currentAudioPath = path;
  audioPlayer.src = `file://${path}`;
  audioPlayer.play();
}

// Generate audio
generateBtn.addEventListener('click', async () => {
  const text = textInput.value.trim();
  const voiceId = voiceSelect.value;
  const modelId = modelSelect.value;

  if (!text) {
    alert('Please enter some text to convert to speech');
    return;
  }

  if (!voiceId) {
    alert('Please select a voice');
    return;
  }

  if (!modelId) {
    alert('Please select a model');
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
      playAudio(result.audioPath);

      // Enable save button
      saveBtn.disabled = false;

      // Add to history
      addToHistory(text, voiceId, modelId, voiceSettings, result.audioPath);
    } else {
      alert(`Error: ${result.error}`);
    }
  } catch (error) {
    alert(`Error: ${error.message}`);
  } finally {
    // Reset button state
    generateBtn.disabled = false;
    generateBtn.innerHTML = 'Generate';
  }
});

// Save audio
saveBtn.addEventListener('click', async () => {
  if (!currentAudioPath) {
    alert('No audio to save');
    return;
  }

  try {
    const result = await window.api.saveAudio({
      audioPath: currentAudioPath
    });

    if (result.success) {
      alert(`Audio saved to: ${result.savedPath}`);
    } else {
      alert(`Error: ${result.error}`);
    }
  } catch (error) {
    alert(`Error: ${error.message}`);
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

// Show notification
function showNotification(message, type = 'info') {
  const notification = document.createElement('div');
  notification.className = `notification ${type}`;
  notification.textContent = message;

  document.body.appendChild(notification);

  // Auto-remove after 3 seconds
  setTimeout(() => {
    notification.classList.add('fade-out');
    setTimeout(() => {
      notification.remove();
    }, 300);
  }, 3000);
}

// Format time in seconds to MM:SS format
function formatTime(timeInSeconds) {
  if (isNaN(timeInSeconds)) return '00:00';

  const minutes = Math.floor(timeInSeconds / 60);
  const seconds = Math.floor(timeInSeconds % 60);
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}
