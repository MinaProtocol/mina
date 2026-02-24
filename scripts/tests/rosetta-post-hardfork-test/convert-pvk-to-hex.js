#!/usr/bin/env node

/**
 * Convert Mina private key from Base58Check format to hex
 *
 * Usage: node convert-pvk-to-hex.js <private-key-base58>
 * Example: node convert-pvk-to-hex.js EKErBK1KznrJJY3raJafSyxSayJ6viejaVrmjzXkSmoxXiJQsesU
 */

const bs58check = require('bs58check').default;

function privateKeyToHex(privateKeyBase58) {
  try {
    // Decode the Base58Check encoded private key
    const decoded = bs58check.decode(privateKeyBase58);

    // Mina private keys have a 2-byte version prefix (0x5a01)
    // We need to strip it to get the raw 32-byte private key
    const privateKeyBytes = decoded.slice(2);

    // Verify we have exactly 32 bytes
    if (privateKeyBytes.length !== 32) {
      throw new Error(`Expected 32 bytes for private key but got ${privateKeyBytes.length}`);
    }

    // Convert to hex string
    const hex = Buffer.from(privateKeyBytes).toString('hex');

    return hex;
  } catch (error) {
    throw new Error(`Failed to convert private key: ${error.message}`);
  }
}

// Main execution
if (process.argv.length < 3) {
  console.error('Usage: node convert-pvk-to-hex.js <private-key-base58>');
  console.error('Example: node convert-pvk-to-hex.js EKErBK1KznrJJY3raJafSyxSayJ6viejaVrmjzXkSmoxXiJQsesU');
  process.exit(1);
}

const privateKeyBase58 = process.argv[2];

try {
  const hex = privateKeyToHex(privateKeyBase58);
  console.log(hex);
} catch (error) {
  console.error(`Error: ${error.message}`);
  process.exit(1);
}
