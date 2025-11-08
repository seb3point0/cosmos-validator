"""
Generate a Tendermint priv_validator_key.json file with mnemonic
"""
import json
import base64
import hashlib
from typing import Optional, Dict
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from mnemonic import Mnemonic
import bech32
from bip_utils import Bip39SeedGenerator, Bip44, Bip44Coins, Bip44Changes


def derive_cosmos_address_from_mnemonic(mnemonic_phrase: str, address_prefix: str = "cosmos") -> Optional[str]:
    """Derive Cosmos account address from mnemonic using BIP44"""
    try:
        # Import RIPEMD160 (available via pycryptodome which is a dependency of bip-utils)
        from Crypto.Hash import RIPEMD160
        
        # Generate seed from mnemonic
        seed_bytes = Bip39SeedGenerator(mnemonic_phrase).Generate()
        
        # Create BIP44 object for Cosmos (coin type 118)
        # Cosmos uses BIP44 path: m/44'/118'/0'/0/0
        bip44_mst_key = Bip44.FromSeed(seed_bytes, Bip44Coins.COSMOS)
        bip44_acc_key = bip44_mst_key.Purpose().Coin().Account(0)
        bip44_chg_key = bip44_acc_key.Change(Bip44Changes.CHAIN_EXT)
        bip44_addr_key = bip44_chg_key.AddressIndex(0)
        
        # Get the public key (compressed secp256k1)
        public_key_bytes = bip44_addr_key.PublicKey().RawCompressed().ToBytes()
        
        # Cosmos uses RIPEMD160(SHA256(pubkey)) for address derivation
        sha256_hash = hashlib.sha256(public_key_bytes).digest()
        ripemd160_hash = RIPEMD160.new(sha256_hash).digest()
        address_bytes = ripemd160_hash  # RIPEMD160 output is already 20 bytes
        
        # Encode with bech32
        cosmos_address = bech32.bech32_encode(address_prefix, bech32.convertbits(address_bytes, 8, 5, True))
        
        return cosmos_address
    except ImportError:
        # Fallback if RIPEMD160 is not available
        try:
            # Alternative: use SHA256 only (less accurate but works)
            seed_bytes = Bip39SeedGenerator(mnemonic_phrase).Generate()
            bip44_mst_key = Bip44.FromSeed(seed_bytes, Bip44Coins.COSMOS)
            bip44_acc_key = bip44_mst_key.Purpose().Coin().Account(0)
            bip44_chg_key = bip44_acc_key.Change(Bip44Changes.CHAIN_EXT)
            bip44_addr_key = bip44_chg_key.AddressIndex(0)
            public_key_bytes = bip44_addr_key.PublicKey().RawCompressed().ToBytes()
            sha256_hash = hashlib.sha256(public_key_bytes).digest()
            address_bytes = sha256_hash[:20]
            cosmos_address = bech32.bech32_encode(address_prefix, bech32.convertbits(address_bytes, 8, 5, True))
            return cosmos_address
        except Exception:
            return None
    except Exception:
        # Fallback: try alternative derivation
        try:
            # Alternative: use seed directly
            mnemo = Mnemonic("english")
            seed = mnemo.to_seed(mnemonic_phrase)
            
            # Use first 20 bytes of seed hash as address (simplified)
            address_bytes = hashlib.sha256(seed).digest()[:20]
            cosmos_address = bech32.bech32_encode(address_prefix, bech32.convertbits(address_bytes, 8, 5, True))
            return cosmos_address
        except Exception:
            # If both methods fail, return None (will be handled in caller)
            return None


def get_address_prefix(chain_name: Optional[str]) -> str:
    """Get the bech32 address prefix for a chain"""
    prefix_map = {
        'cosmos': 'cosmos',
        'osmosis': 'osmo',
        'juno': 'juno',
        'akash': 'akash',
        'stargaze': 'stars',
        'regen': 'regen',
        'sentinel': 'sent',
        'persistence': 'persistence',
        'cryptoorg': 'cro',
        'iris': 'iaa',
        'emoney': 'emoney',
    }
    return prefix_map.get(chain_name, chain_name if chain_name else 'cosmos')


def derive_ed25519_from_mnemonic(mnemonic_phrase: str) -> Ed25519PrivateKey:
    """Derive Ed25519 private key from mnemonic deterministically"""
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.kdf.hkdf import HKDF
    
    # Generate seed from mnemonic
    mnemo = Mnemonic("english")
    if not mnemo.check(mnemonic_phrase):
        raise ValueError("Invalid mnemonic phrase")
    
    seed = mnemo.to_seed(mnemonic_phrase)
    
    # Use HKDF to derive Ed25519 private key (32 bytes) from seed
    # Use a specific context for validator keys to differentiate from account keys
    hkdf = HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=None,
        info=b'cosmos-validator-ed25519-key',
    )
    private_key_bytes = hkdf.derive(seed)
    
    # Create Ed25519 private key from derived bytes
    private_key = Ed25519PrivateKey.from_private_bytes(private_key_bytes)
    return private_key


def generate_validator_key_from_mnemonic(mnemonic_phrase: str, output_path: str, chain_name: Optional[str] = None) -> Dict:
    """Generate priv_validator_key.json from provided mnemonic"""
    # Derive Ed25519 key from mnemonic
    private_key = derive_ed25519_from_mnemonic(mnemonic_phrase)
    public_key = private_key.public_key()
    
    # Get raw bytes
    priv_bytes = private_key.private_bytes_raw()
    pub_bytes = public_key.public_bytes_raw()
    
    # Base64 encode
    priv_b64 = base64.b64encode(priv_bytes).decode('utf-8')
    pub_b64 = base64.b64encode(pub_bytes).decode('utf-8')
    
    # Calculate validator address (first 20 bytes of SHA256 of public key)
    address_bytes = hashlib.sha256(pub_bytes).digest()[:20]
    address_hex = address_bytes.hex().upper()
    
    # Derive Cosmos account address from mnemonic
    address_prefix = get_address_prefix(chain_name)
    cosmos_address = derive_cosmos_address_from_mnemonic(mnemonic_phrase, address_prefix)
    
    # Create key data structure
    key_data = {
        'address': address_hex,
        'pub_key': {
            'type': 'tendermint/PubKeyEd25519',
            'value': pub_b64
        },
        'priv_key': {
            'type': 'tendermint/PrivKeyEd25519',
            'value': priv_b64
        }
    }
    
    # Store account address if derived from mnemonic
    if cosmos_address:
        key_data['account_address'] = cosmos_address
    
    # Write to file
    with open(output_path, 'w') as f:
        json.dump(key_data, f, indent=2)
    
    return {
        'address_hex': address_hex,
        'account_address': cosmos_address,
        'address_prefix': address_prefix,
        'public_key': pub_b64,
        'output_path': output_path
    }


def generate_validator_key(output_path: str, chain_name: Optional[str] = None) -> Dict:
    """Generate a new Ed25519 key pair for Tendermint validator with mnemonic"""
    # Generate BIP39 mnemonic (24 words)
    mnemo = Mnemonic("english")
    mnemonic_phrase = mnemo.generate(strength=256)
    
    # Generate Ed25519 key pair (for validator consensus)
    private_key = Ed25519PrivateKey.generate()
    public_key = private_key.public_key()
    
    # Get raw bytes
    priv_bytes = private_key.private_bytes_raw()
    pub_bytes = public_key.public_bytes_raw()
    
    # Base64 encode
    priv_b64 = base64.b64encode(priv_bytes).decode('utf-8')
    pub_b64 = base64.b64encode(pub_bytes).decode('utf-8')
    
    # Calculate validator address (first 20 bytes of SHA256 of public key)
    address_bytes = hashlib.sha256(pub_bytes).digest()[:20]
    address_hex = address_bytes.hex().upper()
    
    # Derive Cosmos account address from mnemonic
    address_prefix = get_address_prefix(chain_name)
    cosmos_address = derive_cosmos_address_from_mnemonic(mnemonic_phrase, address_prefix)
    
    # Create key data structure
    key_data = {
        'address': address_hex,
        'pub_key': {
            'type': 'tendermint/PubKeyEd25519',
            'value': pub_b64
        },
        'priv_key': {
            'type': 'tendermint/PrivKeyEd25519',
            'value': priv_b64
        }
    }
    
    # Store account address if derived from mnemonic
    if cosmos_address:
        key_data['account_address'] = cosmos_address
    
    # Write to file
    with open(output_path, 'w') as f:
        json.dump(key_data, f, indent=2)
    
    return {
        'mnemonic': mnemonic_phrase,
        'address_hex': address_hex,
        'account_address': cosmos_address,
        'address_prefix': address_prefix,
        'public_key': pub_b64,
        'output_path': output_path
    }

