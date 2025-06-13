// HTML escape function to prevent XSS attacks
function escapeHtml(unsafe) {
  if (typeof unsafe !== 'string') return '';
  
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// Sanitize file paths to prevent directory traversal
function sanitizePath(filePath) {
  if (!filePath || typeof filePath !== 'string') return '';
  
  // Remove any directory traversal attempts
  const sanitized = filePath
    .replace(/\.\./g, '')
    .replace(/[<>:"|?*]/g, '')
    .replace(/^[/\\]+/, '');
  
  return sanitized;
}

// Validate text input length and content
function validateTextInput(text, maxLength = 5000) {
  if (!text || typeof text !== 'string') {
    return { valid: false, error: 'Text input is required' };
  }
  
  if (text.length > maxLength) {
    return { valid: false, error: `Text exceeds maximum length of ${maxLength} characters` };
  }
  
  // Check for suspicious patterns that might indicate injection attempts
  const suspiciousPatterns = [
    /<script[^>]*>[\s\S]*?<\/script>/gi,
    /<iframe[^>]*>[\s\S]*?<\/iframe>/gi,
    /javascript:/gi,
    /on\w+\s*=/gi
  ];
  
  for (const pattern of suspiciousPatterns) {
    if (pattern.test(text)) {
      return { valid: false, error: 'Invalid content detected in text' };
    }
  }
  
  return { valid: true };
}

// Validate API key format
function validateApiKey(apiKey) {
  if (!apiKey || typeof apiKey !== 'string') {
    return { valid: false, error: 'API key is required' };
  }
  
  // Basic validation - adjust pattern based on ElevenLabs API key format
  if (apiKey.length < 20 || apiKey.length > 100) {
    return { valid: false, error: 'Invalid API key format' };
  }
  
  // Check for valid characters (alphanumeric)
  if (!/^[a-zA-Z0-9]+$/.test(apiKey)) {
    return { valid: false, error: 'API key contains invalid characters' };
  }
  
  return { valid: true };
}

// Validate voice parameters
function validateVoiceParams(params) {
  const errors = [];
  
  if (params.stability !== undefined) {
    const stability = parseFloat(params.stability);
    if (isNaN(stability) || stability < 0 || stability > 1) {
      errors.push('Stability must be between 0 and 1');
    }
  }
  
  if (params.similarity_boost !== undefined) {
    const similarity = parseFloat(params.similarity_boost);
    if (isNaN(similarity) || similarity < 0 || similarity > 1) {
      errors.push('Similarity must be between 0 and 1');
    }
  }
  
  if (params.style !== undefined) {
    const style = parseFloat(params.style);
    if (isNaN(style) || style < 0 || style > 1) {
      errors.push('Style must be between 0 and 1');
    }
  }
  
  if (params.use_speaker_boost !== undefined && typeof params.use_speaker_boost !== 'boolean') {
    errors.push('Speaker boost must be a boolean value');
  }
  
  return errors.length > 0 ? { valid: false, errors } : { valid: true };
}

module.exports = {
  escapeHtml,
  sanitizePath,
  validateTextInput,
  validateApiKey,
  validateVoiceParams
};