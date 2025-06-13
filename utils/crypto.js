const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// Generate or load encryption key
const keyPath = path.join(__dirname, '..', 'data', '.encryption_key');
let encryptionKey;

function initializeEncryption() {
  if (fs.existsSync(keyPath)) {
    encryptionKey = fs.readFileSync(keyPath, 'utf8');
  } else {
    encryptionKey = crypto.randomBytes(32).toString('hex');
    fs.writeFileSync(keyPath, encryptionKey, { mode: 0o600 });
  }
}

function encrypt(text) {
  if (!encryptionKey) initializeEncryption();
  
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(
    'aes-256-cbc',
    Buffer.from(encryptionKey, 'hex'),
    iv
  );
  
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  
  return iv.toString('hex') + ':' + encrypted;
}

function decrypt(encryptedText) {
  if (!encryptionKey) initializeEncryption();
  
  try {
    const parts = encryptedText.split(':');
    const iv = Buffer.from(parts[0], 'hex');
    const encrypted = parts[1];
    
    const decipher = crypto.createDecipheriv(
      'aes-256-cbc',
      Buffer.from(encryptionKey, 'hex'),
      iv
    );
    
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  } catch (error) {
    console.error('Decryption error:', error);
    return null;
  }
}

module.exports = { encrypt, decrypt, initializeEncryption };