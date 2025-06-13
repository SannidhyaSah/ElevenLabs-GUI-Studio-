const { contextBridge, ipcRenderer } = require('electron');

console.log('Preload script is running');

// Expose protected methods that allow the renderer process to use
// the ipcRenderer without exposing the entire object
try {
  contextBridge.exposeInMainWorld(
    'api', {
      // API Key Management
      getApiKeys: () => ipcRenderer.invoke('get-api-keys'),
      saveApiKey: (data) => ipcRenderer.invoke('save-api-key', data),
      deleteApiKey: (name) => ipcRenderer.invoke('delete-api-key', name),
      setApiKey: (name) => ipcRenderer.invoke('set-api-key', name),
      getCurrentApiKeyName: () => ipcRenderer.invoke('get-current-api-key-name'),

      // ElevenLabs API
      getVoices: () => ipcRenderer.invoke('get-voices'),
      getModels: () => ipcRenderer.invoke('get-models'),
      generateSpeech: (options) => ipcRenderer.invoke('generate-speech', options),
      saveAudio: (options) => ipcRenderer.invoke('save-audio', options),
      
      // Voice cloning and library
      cloneVoice: (data) => ipcRenderer.invoke('clone-voice', data),
      getVoiceLibrary: () => ipcRenderer.invoke('get-voice-library'),
      addVoiceFromLibrary: (voiceId) => ipcRenderer.invoke('add-voice-from-library', voiceId),

      // File operations
      checkFileExists: (filePath) => ipcRenderer.invoke('check-file-exists', filePath)
    }
  );
  console.log('API methods exposed successfully');
} catch (error) {
  console.error('Error in preload script:', error);
}
