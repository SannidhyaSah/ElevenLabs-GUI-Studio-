const { app, BrowserWindow, ipcMain, dialog, Menu, MenuItem } = require('electron');
const path = require('path');
const fs = require('fs');
const Store = require('electron-store');
const { ElevenLabsClient } = require('elevenlabs');
const { encrypt, decrypt, initializeEncryption } = require('./utils/crypto');
const { validateApiKey, validateTextInput, validateVoiceParams, sanitizePath } = require('./utils/sanitizer');

// Create data directory if it doesn't exist
const dataDir = path.join(__dirname, 'data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir);
}

// Path to API keys file
const apiKeysPath = path.join(dataDir, 'api_keys.json');

// Initialize store for saving settings with encryption
const store = new Store({
  encryptionKey: 'elevenlabs-gui-studio-2024',
  clearInvalidConfig: true
});

// Initialize encryption
initializeEncryption();

// Initialize API keys storage with encryption
let apiKeys = [];
if (fs.existsSync(apiKeysPath)) {
  try {
    const encryptedData = fs.readFileSync(apiKeysPath, 'utf8');
    const decryptedData = decrypt(encryptedData);
    if (decryptedData) {
      apiKeys = JSON.parse(decryptedData);
    } else {
      // Handle legacy unencrypted format
      try {
        apiKeys = JSON.parse(encryptedData);
        // Re-save as encrypted
        saveApiKeys();
      } catch (e) {
        console.error('Error reading API keys file:', e);
        apiKeys = [];
      }
    }
  } catch (error) {
    console.error('Error reading API keys file:', error);
    apiKeys = [];
  }
}

// Helper function to save encrypted API keys
function saveApiKeys() {
  try {
    const encrypted = encrypt(JSON.stringify(apiKeys));
    fs.writeFileSync(apiKeysPath, encrypted, 'utf8');
  } catch (error) {
    console.error('Error saving API keys:', error);
    throw new Error('Failed to save API keys securely');
  }
}

// Initialize ElevenLabs client
let elevenLabsClient = null;

// Keep a global reference of the window object to prevent garbage collection
let mainWindow;

// Cleanup temporary audio files older than 24 hours
function cleanupTempFiles() {
  try {
    const tempDir = app.getPath('temp');
    const files = fs.readdirSync(tempDir);
    const now = Date.now();
    const maxAge = 24 * 60 * 60 * 1000; // 24 hours

    files.forEach(file => {
      if (file.startsWith('elevenlabs-output-')) {
        const filePath = path.join(tempDir, file);
        const stats = fs.statSync(filePath);
        if (now - stats.mtime.getTime() > maxAge) {
          fs.unlinkSync(filePath);
          console.log('Cleaned up old temp file:', file);
        }
      }
    });
  } catch (error) {
    console.error('Error cleaning up temp files:', error);
  }
}

function createWindow() {
  // Create the browser window
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      spellcheck: true
    },
    icon: path.join(__dirname, 'assets/icon.png')
  });

  // Load the index.html file
  mainWindow.loadFile('index.html');

  // Create and set up the context menu
  setupContextMenu();

  // Open DevTools in development mode
  if (process.argv.includes('--dev')) {
    mainWindow.webContents.openDevTools();

    // Enable remote debugging
    console.log('Enabling remote debugging');
    mainWindow.webContents.on('did-finish-load', () => {
      console.log('Main window finished loading');
      mainWindow.webContents.executeJavaScript(`
        console.log('Renderer process started');
        if (window.api) {
          console.log('API is available in window object');
        } else {
          console.error('API is not available in window object');
        }
      `);
    });
  }

  // Initialize ElevenLabs client with stored API key if available
  const currentApiKeyName = store.get('currentApiKeyName');
  if (currentApiKeyName) {
    const apiKeyObj = apiKeys.find(key => key.name === currentApiKeyName);
    if (apiKeyObj) {
      elevenLabsClient = new ElevenLabsClient({
        apiKey: apiKeyObj.apiKey
      });
    }
  }
}

// Create window when Electron has finished initialization
app.whenReady().then(() => {
  console.log('Electron app is ready');
  createWindow();
  console.log('Main window created');

  // Clean up old temporary audio files on startup
  cleanupTempFiles();

  app.on('activate', function () {
    // On macOS it's common to re-create a window when the dock icon is clicked
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
}).catch(err => {
  console.error('Error during app initialization:', err);
});

// Quit when all windows are closed, except on macOS
app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit();
});

// Set up context menu with spell check and text editing options
function setupContextMenu() {
  mainWindow.webContents.on('context-menu', (event, params) => {
    // Only show context menu for editable elements (like textareas and inputs)
    if (params.isEditable) {
      const menu = new Menu();

      // Add spell check suggestions if available
      if (params.misspelledWord) {
        for (const suggestion of params.dictionarySuggestions) {
          menu.append(new MenuItem({
            label: suggestion,
            click: () => mainWindow.webContents.replaceMisspelling(suggestion)
          }));
        }

        // Add a separator if we have suggestions
        if (params.dictionarySuggestions.length > 0) {
          menu.append(new MenuItem({ type: 'separator' }));
        }

        // Add to dictionary option
        menu.append(new MenuItem({
          label: 'Add to Dictionary',
          click: () => mainWindow.webContents.session.addWordToSpellCheckerDictionary(params.misspelledWord)
        }));

        menu.append(new MenuItem({ type: 'separator' }));
      }

      // Standard text editing options
      if (params.editFlags.canCut) {
        menu.append(new MenuItem({
          label: 'Cut',
          role: 'cut'
        }));
      }

      if (params.editFlags.canCopy) {
        menu.append(new MenuItem({
          label: 'Copy',
          role: 'copy'
        }));
      }

      if (params.editFlags.canPaste) {
        menu.append(new MenuItem({
          label: 'Paste',
          role: 'paste'
        }));
      }

      if (params.editFlags.canSelectAll) {
        menu.append(new MenuItem({
          label: 'Select All',
          role: 'selectAll'
        }));
      }

      // Show the context menu
      menu.popup();
    }
  });
}

// IPC handlers for communication with renderer process

// Get all saved API keys
ipcMain.handle('get-api-keys', () => {
  return apiKeys;
});

// Save a new API key
ipcMain.handle('save-api-key', async (event, { name, apiKey }) => {
  try {
    // Validate inputs
    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return { success: false, error: 'API key name is required' };
    }
    
    const validation = validateApiKey(apiKey);
    if (!validation.valid) {
      return { success: false, error: validation.error };
    }

    // Create new client with the provided API key
    const testClient = new ElevenLabsClient({
      apiKey: apiKey
    });

    // Test the API key by fetching voices
    try {
      await testClient.voices.getAll();
    } catch (apiError) {
      console.error('API key validation failed:', apiError);
      return { success: false, error: 'Invalid API key. Please check your API key and try again.' };
    }

    // If successful, add to API keys list
    const existingIndex = apiKeys.findIndex(key => key.name === name);
    if (existingIndex >= 0) {
      apiKeys[existingIndex] = { name, apiKey };
    } else {
      apiKeys.push({ name, apiKey });
    }

    // Save encrypted to file
    saveApiKeys();

    // Set as current API key
    elevenLabsClient = testClient;
    store.set('currentApiKeyName', name);

    return { success: true };
  } catch (error) {
    console.error('Error saving API key:', error);
    return { success: false, error: error.message || 'Failed to save API key' };
  }
});

// Delete an API key
ipcMain.handle('delete-api-key', (event, name) => {
  try {
    if (!name || typeof name !== 'string') {
      return { success: false, error: 'Invalid API key name' };
    }

    const initialLength = apiKeys.length;
    apiKeys = apiKeys.filter(key => key.name !== name);

    // Save encrypted to file
    saveApiKeys();

    // If current API key was deleted, reset client
    if (store.get('currentApiKeyName') === name) {
      elevenLabsClient = null;
      store.delete('currentApiKeyName');
    }

    return {
      success: true,
      deleted: initialLength > apiKeys.length
    };
  } catch (error) {
    console.error('Error deleting API key:', error);
    return { success: false, error: error.message || 'Failed to delete API key' };
  }
});

// Set active API key
ipcMain.handle('set-api-key', async (event, name) => {
  try {
    const apiKeyObj = apiKeys.find(key => key.name === name);

    if (!apiKeyObj) {
      return { success: false, error: 'API key not found' };
    }

    // Create new client with the selected API key
    elevenLabsClient = new ElevenLabsClient({
      apiKey: apiKeyObj.apiKey
    });

    // Test the API key by fetching voices
    await elevenLabsClient.voices.getAll();

    // If successful, store the current API key name
    store.set('currentApiKeyName', name);
    return { success: true };
  } catch (error) {
    console.error('Error setting API key:', error);
    return { success: false, error: error.message };
  }
});

// Get all available voices
ipcMain.handle('get-voices', async () => {
  try {
    if (!elevenLabsClient) {
      return { success: false, error: 'API key not set' };
    }

    const voicesResponse = await elevenLabsClient.voices.getAll();
    console.log('Voices response structure:', JSON.stringify(voicesResponse, null, 2));

    // Check if the response has a voices property
    if (voicesResponse && voicesResponse.voices) {
      return { success: true, voices: voicesResponse.voices };
    } else if (Array.isArray(voicesResponse)) {
      return { success: true, voices: voicesResponse };
    } else {
      console.log('Unexpected voices response format:', voicesResponse);
      return { success: true, voices: [] };
    }
  } catch (error) {
    console.error('Error getting voices:', error);
    return { success: false, error: error.message };
  }
});

// Get all available models
ipcMain.handle('get-models', async () => {
  try {
    if (!elevenLabsClient) {
      return { success: false, error: 'API key not set' };
    }

    const modelsResponse = await elevenLabsClient.models.getAll();
    console.log('Models response structure:', JSON.stringify(modelsResponse, null, 2));

    // Check if the response has a models property
    if (modelsResponse && modelsResponse.models) {
      return { success: true, models: modelsResponse.models };
    } else if (Array.isArray(modelsResponse)) {
      return { success: true, models: modelsResponse };
    } else {
      console.log('Unexpected models response format:', modelsResponse);
      return { success: true, models: [] };
    }
  } catch (error) {
    console.error('Error getting models:', error);
    return { success: false, error: error.message };
  }
});

// Generate speech from text
ipcMain.handle('generate-speech', async (event, { text, voiceId, modelId, voiceSettings }) => {
  try {
    console.log('Generate speech request received:', { voiceId, modelId });

    if (!elevenLabsClient) {
      console.error('No API client available - API key not set');
      return { success: false, error: 'API key not set. Please set an API key in the Settings tab.' };
    }

    // Validate text input
    const textValidation = validateTextInput(text);
    if (!textValidation.valid) {
      return { success: false, error: textValidation.error };
    }

    if (!voiceId) {
      return { success: false, error: 'Voice ID is required' };
    }

    if (!modelId) {
      return { success: false, error: 'Model ID is required' };
    }

    // Validate voice parameters if provided
    if (voiceSettings) {
      const paramsValidation = validateVoiceParams(voiceSettings);
      if (!paramsValidation.valid) {
        return { success: false, error: 'Invalid voice parameters: ' + paramsValidation.errors.join(', ') };
      }
    }

    // Create options object with correct parameter names for the Eleven Labs API
    const options = {
      text: text,
      model_id: modelId
    };

    // Add voice settings if provided - following the exact format expected by the Eleven Labs API
    if (voiceSettings) {
      try {
        // According to the Eleven Labs API documentation, voice_settings should have these properties:
        // - stability (number between 0 and 1)
        // - similarity_boost (number between 0 and 1)
        // - style (number between 0 and 1)
        // - use_speaker_boost (boolean)
        // - speed (number between 0.5 and 2.0)

        // Create a clean object with the exact property names expected by the API
        const cleanSettings = {
          stability: Math.max(0, Math.min(1, parseFloat(voiceSettings.stability) || 0.5)),
          similarity_boost: Math.max(0, Math.min(1, parseFloat(voiceSettings.similarity_boost) || 0.75)),
          style: Math.max(0, Math.min(1, parseFloat(voiceSettings.style) || 0)),
          use_speaker_boost: voiceSettings.use_speaker_boost !== undefined ? Boolean(voiceSettings.use_speaker_boost) : true
        };

        // Add speed if provided (must be a number between 0.5 and 2.0)
        if (voiceSettings.speed !== undefined) {
          const speed = parseFloat(voiceSettings.speed);
          if (!isNaN(speed)) {
            cleanSettings.speed = Math.max(0.5, Math.min(2.0, speed));
          }
        }

        // Add the clean settings to the options
        options.voice_settings = cleanSettings;

        console.log('Voice settings being sent to API:', JSON.stringify(cleanSettings, null, 2));
      } catch (error) {
        console.error('Error processing voice settings:', error);
        // If there's an error processing voice settings, use default values
        options.voice_settings = {
          stability: 0.5,
          similarity_boost: 0.75,
          style: 0,
          use_speaker_boost: true,
          speed: 1.0
        };
        console.log('Using default voice settings due to error:', JSON.stringify(options.voice_settings, null, 2));
      }
    }

    // Log the final options for debugging
    console.log('Final API request options:', JSON.stringify(options, null, 2));

    console.log('Calling ElevenLabs API with options:', options);

    try {
      console.log(`Calling ElevenLabs API textToSpeech.convert with voiceId: ${voiceId}`);

      // Add additional debugging
      if (!elevenLabsClient.textToSpeech || typeof elevenLabsClient.textToSpeech.convert !== 'function') {
        console.error('textToSpeech.convert is not a function!', elevenLabsClient.textToSpeech);
        throw new Error('Internal error: API client is not properly initialized');
      }

      // Create a clean API request with the correct format according to the Eleven Labs API documentation
      console.log('Making API request with the following options:', JSON.stringify(options, null, 2));

      // Make the API call with proper error handling
      let audio;
      try {
        // First attempt with all settings
        audio = await elevenLabsClient.textToSpeech.convert(voiceId, options);
        console.log('API call successful with full options');
      } catch (fullOptionsError) {
        console.error('Error with full options:', fullOptionsError);

        // If that fails, try with just the essential parameters
        console.log('Retrying with basic options (no voice settings)');
        const basicOptions = {
          text: text,
          model_id: modelId
        };

        try {
          audio = await elevenLabsClient.textToSpeech.convert(voiceId, basicOptions);
          console.log('API call successful with basic options');
        } catch (basicOptionsError) {
          console.error('Error with basic options:', basicOptionsError);
          throw new Error('Failed to generate speech with both full and basic options');
        }
      }

      console.log('API call successful, received audio data');

      // Save audio to temporary file with a unique name
      const timestamp = Date.now();
      const tempFilePath = path.join(app.getPath('temp'), `elevenlabs-output-${timestamp}.mp3`);

      // Check if audio is an async iterable (ReadableStream)
      if (audio[Symbol.asyncIterator]) {
        // Collect chunks from the stream
        const chunks = [];
        for await (const chunk of audio) {
          chunks.push(Buffer.from(chunk));
        }
        // Write the combined buffer to file
        fs.writeFileSync(tempFilePath, Buffer.concat(chunks));
      } else {
        // If it's not a stream, write it directly
        fs.writeFileSync(tempFilePath, audio);
      }

      console.log('Speech generated successfully, saved to:', tempFilePath);
      return { success: true, audioPath: tempFilePath };
    } catch (apiError) {
      console.error('ElevenLabs API error:', apiError);

      // Check for specific error types
      if (apiError.response && apiError.response.status === 401) {
        return {
          success: false,
          error: 'Authentication failed. Your API key may be invalid or expired.',
          statusCode: 401
        };
      } else if (apiError.response && apiError.response.status === 429) {
        return {
          success: false,
          error: 'Rate limit exceeded. You may have used all your available characters for this billing period.',
          statusCode: 429
        };
      } else if (apiError.response && apiError.response.status === 400) {
        // Provide more detailed information for 400 Bad Request errors
        let errorMessage = 'Bad request - The server could not process your request.';

        console.error('400 Bad Request Error Details:');
        console.error('- Request URL:', apiError.config ? apiError.config.url : 'unknown');
        console.error('- Request Method:', apiError.config ? apiError.config.method : 'unknown');
        console.error('- Request Headers:', apiError.config ? apiError.config.headers : 'unknown');
        console.error('- Request Data:', apiError.config ? apiError.config.data : 'unknown');
        console.error('- Response Status:', apiError.response ? apiError.response.status : 'unknown');
        console.error('- Response Headers:', apiError.response ? apiError.response.headers : 'unknown');
        console.error('- Response Data:', apiError.response ? apiError.response.data : 'unknown');

        // Log the full error object for debugging
        console.error('Full API Error Object:', JSON.stringify(apiError, null, 2));

        // Try to read the response body if it's a ReadableStream
        if (apiError.body && typeof apiError.body.getReader === 'function') {
          try {
            console.log('Attempting to read error response body from ReadableStream');
            const reader = apiError.body.getReader();
            reader.read().then(({ done, value }) => {
              if (!done && value) {
                const text = new TextDecoder().decode(value);
                console.log('Error response body content:', text);
                try {
                  const jsonData = JSON.parse(text);
                  console.log('Parsed error response:', jsonData);
                } catch (e) {
                  console.log('Error response is not valid JSON');
                }
              }
            }).catch(err => {
              console.error('Error reading response body stream:', err);
            });
          } catch (streamError) {
            console.error('Error accessing response body stream:', streamError);
          }
        }

        // Try to extract more specific error information
        if (apiError.response && apiError.response.data) {
          try {
            const errorData = typeof apiError.response.data === 'string'
              ? JSON.parse(apiError.response.data)
              : apiError.response.data;

            if (errorData.detail) {
              errorMessage = `Bad request: ${errorData.detail}`;
            } else if (errorData.message) {
              errorMessage = `Bad request: ${errorData.message}`;
            } else if (errorData.error) {
              errorMessage = `Bad request: ${errorData.error}`;
            }

            console.log('Detailed 400 error:', errorData);
          } catch (e) {
            console.error('Error parsing 400 response data:', e);
          }
        }

        // If we have an empty response body, provide a more helpful message
        if (!apiError.response.data ||
            (typeof apiError.response.data === 'object' && Object.keys(apiError.response.data).length === 0)) {
          errorMessage = 'There was an issue with the voice settings. Try generating audio with default settings.';

          console.error('Empty response body detected. Request parameters:', {
            text,
            voiceId,
            modelId,
            voiceSettings: options.voice_settings
          });
        }

        return {
          success: false,
          error: errorMessage,
          statusCode: 400,
          details: apiError.response.data || 'No detailed error information available',
          requestParams: { text, voiceId, modelId, voiceSettings: options.voice_settings }
        };
      } else {
        return {
          success: false,
          error: apiError.message || 'Unknown API error',
          statusCode: apiError.response ? apiError.response.status : 'unknown',
          details: apiError.response ? apiError.response.data : null
        };
      }
    }
  } catch (error) {
    console.error('Error generating speech:', error);
    return {
      success: false,
      error: `Error: ${error.message}`,
      details: error.stack
    };
  }
});

// Get current API key name
ipcMain.handle('get-current-api-key-name', () => {
  return store.get('currentApiKeyName') || null;
});

// Check if a file exists
ipcMain.handle('check-file-exists', (event, filePath) => {
  try {
    return fs.existsSync(filePath);
  } catch (error) {
    console.error('Error checking if file exists:', error);
    return false;
  }
});

// Save audio file
ipcMain.handle('save-audio', async (event, { audioPath, format = 'mp3', quality = 'high' }) => {
  try {
    console.log('Saving audio with options:', { format, quality });

    // Validate and sanitize the audio path
    if (!audioPath || typeof audioPath !== 'string') {
      return { success: false, error: 'Invalid audio path' };
    }

    const sanitizedPath = sanitizePath(audioPath);
    const resolvedPath = path.resolve(audioPath);
    
    // Check if file exists and is within allowed directories
    if (!fs.existsSync(resolvedPath)) {
      return { success: false, error: 'Audio file not found' };
    }

    // Verify the file is in temp directory (security check)
    const tempDir = app.getPath('temp');
    if (!resolvedPath.startsWith(tempDir)) {
      return { success: false, error: 'Invalid file location' };
    }

    // Determine file extension based on format
    const extension = format.toLowerCase();

    const { filePath } = await dialog.showSaveDialog({
      title: 'Export Audio',
      defaultPath: path.join(app.getPath('downloads'), `elevenlabs-output.${extension}`),
      filters: [
        { name: 'Audio Files', extensions: [extension] },
        { name: 'All Files', extensions: ['*'] }
      ]
    });

    if (filePath) {
      // For now, we're just copying the file since we don't have actual audio processing
      // In a future update, this would use ffmpeg or another library to process the audio
      // based on the format and quality settings

      console.log(`Exporting audio to ${filePath} (format: ${format}, quality: ${quality})`);

      // Copy the file
      fs.copyFileSync(resolvedPath, filePath);

      // Log success
      console.log('Audio exported successfully');

      return {
        success: true,
        savedPath: filePath,
        format: format,
        quality: quality
      };
    } else {
      console.log('Export cancelled by user');
      return { success: false, error: 'Export cancelled' };
    }
  } catch (error) {
    console.error('Error exporting audio:', error);
    return { success: false, error: error.message };
  }
});

// Clone voice
ipcMain.handle('clone-voice', async (event, { name, description, labels, files }) => {
  try {
    if (!elevenLabsClient) {
      return { success: false, error: 'API key not set' };
    }

    // Validate inputs
    if (!name || name.trim().length === 0) {
      return { success: false, error: 'Voice name is required' };
    }

    if (!files || files.length === 0) {
      return { success: false, error: 'At least one audio file is required' };
    }

    console.log('Creating voice clone:', name);

    // Convert base64 files to buffers
    const audioBuffers = files.map(file => ({
      name: file.name,
      buffer: Buffer.from(file.data, 'base64')
    }));

    // Create the voice clone
    const voice = await elevenLabsClient.voices.add({
      name: name,
      description: description,
      labels: labels,
      files: audioBuffers.map(f => f.buffer)
    });

    console.log('Voice clone created successfully:', voice.voice_id);

    return {
      success: true,
      voiceId: voice.voice_id,
      voice: voice
    };
  } catch (error) {
    console.error('Error creating voice clone:', error);
    return {
      success: false,
      error: error.message || 'Failed to create voice clone'
    };
  }
});

// Get voice library
ipcMain.handle('get-voice-library', async (event) => {
  try {
    if (!elevenLabsClient) {
      return { success: false, error: 'API key not set' };
    }

    // Get shared voices from the library
    const response = await elevenLabsClient.voices.getAll({ show_legacy: false });
    
    // Filter to show only library voices (not user's own voices)
    const libraryVoices = response.voices.filter(voice => 
      voice.category && voice.category !== 'cloned'
    );

    return {
      success: true,
      voices: libraryVoices
    };
  } catch (error) {
    console.error('Error fetching voice library:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch voice library'
    };
  }
});

// Add voice from library
ipcMain.handle('add-voice-from-library', async (event, voiceId) => {
  try {
    if (!elevenLabsClient) {
      return { success: false, error: 'API key not set' };
    }

    // This would typically add the voice to the user's collection
    // However, the ElevenLabs API doesn't have a direct method for this
    // Instead, users can simply use any voice_id directly in their requests
    
    return {
      success: true,
      message: 'Voice is now available for use'
    };
  } catch (error) {
    console.error('Error adding voice from library:', error);
    return {
      success: false,
      error: error.message || 'Failed to add voice'
    };
  }
});
