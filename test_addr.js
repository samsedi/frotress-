const crypto = require('crypto');
const ecdh = crypto.createECDH('secp256k1');
ecdh.setPublicKey(Buffer.from('021d50ef65ac1942fa9a1d4df18d7577ce3722ef63dbae898810e9fb2ff78730ed', 'hex'));
const uncompressed = ecdh.getPublicKey(null, 'uncompressed').slice(1);
const keccak256 = crypto.createHash('sha3-256'); // Wait, Node.js crypto's sha3-256 is NOT keccak256!
// Need a keccak implementation or just use ethers if installed
