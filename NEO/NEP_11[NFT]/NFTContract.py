from typing import Any, Dict, List, Union, cast, MutableSequence

from boa3.builtin import CreateNewEvent, NeoMetadata, metadata, public
from boa3.builtin.contract import Nep17TransferEvent, abort
from boa3.builtin.interop.blockchain import get_contract, Transaction
from boa3.builtin.interop.contract import NEO, GAS, call_contract, destroy_contract, update_contract
from boa3.builtin.interop.runtime import notify, log, calling_script_hash, executing_script_hash, check_witness, script_container
from boa3.builtin.interop.stdlib import serialize, deserialize, base58_encode
from boa3.builtin.interop.storage import delete, get, put, find, get_context
from boa3.builtin.interop.iterator import Iterator
from boa3.builtin.interop.crypto import ripemd160, sha256
from boa3.builtin.type import UInt160, UInt256
from boa3.builtin.interop.contract import CallFlags
from boa3.builtin.interop.json import json_serialize, json_deserialize


# ---------------------------------
# CONTRACT GENERAL
# ---------------------------------

CONTRACT_NAME = 'Chain.Game Items'
CONTRACT_VERSION = 'v0.0.1'
AUTHOR = 'Thomas Geyer'
EMAIL = 'thomas.geyer@tec-consulting.at'

@metadata
def manifest_metadata() -> NeoMetadata:
    meta = NeoMetadata()
    meta.author = 'Thomas Geyer'
    meta.email = 'thomas.geyer@tec-consulting.at'
    meta.description = 'Chain.Game Items'
    meta.version = "v0.1"
    return meta

# -------------------------------------------
# CONTRACT GLOBALS & PREFIXES
# -------------------------------------------

# Admin
ADMIN = UInt160(b'#\xf8\xc6\xd2\xf2o\x90\xfd\x1f:\x88\x863wt9]\xe0\n\xea')
# Symbol of the Token
TOKEN_SYMBOL = 'C.G:I'
# Number of decimal places
TOKEN_DECIMALS = 0

# Account Prefix
ACCOUNT_PREFIX = b'a'
# Token Prefix
TOKEN_PREFIX = b't' #full NFT
# Supply Prefix
SUPPLY_PREFIX = b's' #Total supply
# Balance Prefix
BALANCE_PREFIX = b'b' #individuall balance
# Property Prefix
PROP_PREFIX = b'p'
# Steamstone Prefix
STEAMSTONE_PREFIX = b'st'
# Steamstone Charges Prefix
CHARGE_PREFIX = b'ch'

# -------------------------------------------
# Events
# -------------------------------------------

Nep11TransferEvent = CreateNewEvent(
    [
        ('from', Union[UInt160, None]),
        ('to', Union[UInt160, None]),
        ('amount', int),
        ('tokenId', bytes)
    ],
    'Transfer'
)

debug = CreateNewEvent(
    [
        ('params', list),
    ],
    'Debug'
)
#DEBUG_END

# ---------------------------------
# Methods
# ---------------------------------

@public
def _deploy(data: Any, update: bool):
    if not update:
        put(SUPPLY_PREFIX, 0)

        steamstone = {
            'title': 'Chain.Game.Item',
            'type': 'consumable',
            'name': 'SteamStone',
            'charges': 10,
            'costGAS': 2
        }

        put(STEAMSTONE_PREFIX, json_serialize(steamstone))

@public
def symbol() -> str:
    return TOKEN_SYMBOL

@public
def decimals() -> int:
    return TOKEN_DECIMALS

@public
def totalSupply() -> int:
    return get(SUPPLY_PREFIX).to_int()

@public
def balanceOf(owner: UInt160) -> int:
    assert len(owner) == 20, "Incorrect length - owner"
    return get(BALANCE_PREFIX + owner).to_int()

@public
def tokensOf(owner: UInt160) -> Iterator:
    assert len(owner) == 20, "Incorrect length - owner"
    return find(ACCOUNT_PREFIX + owner)

@public
def ownerOf(tokenId: bytes) -> UInt160:
    owner = get(TOKEN_PREFIX + tokenId)
    return UInt160(owner)

@public
def tokens() -> Iterator:
    return find(TOKEN_PREFIX)

@public
def properties(tokenId: bytes) -> bytes:
    properties = get(PROP_PREFIX + tokenId)
    assert len(properties) != 0, 'Token has no properties'
    return properties

@public
def steamstoneCharges(tokenId: int) -> int:
    return get(STEAMSTONE_PREFIX + tokenId.to_bytes() + CHARGE_PREFIX).to_int()

@public
def mint(account: UInt160, propString: bytes, receiver: UInt160, data_in: str) -> bool:
    assert check_witness(ADMIN), 'Invalid witness'
    assert len(receiver) == 20, 'Invalid length - receiver'
    assert len(propString) != 0, 'Invalid property data'
    assert len(data_in) != 0, 'Invalid data payload'

    data: Dict[str, Any] = json_deserialize(data_in)
    steamstoneId = cast(int, data['tokenId'])

    allowMint = identifySteamstone(receiver, steamstoneId)

    if (allowMint == True):
        #Reduce SteamStone Charge
        takeCharge(steamstoneId)
        #Create new TokenId
        tokenId = get(SUPPLY_PREFIX).to_int() + 1
        #change total Supply
        put(SUPPLY_PREFIX, tokenId.to_bytes())
        #set token owner
        put(TOKEN_PREFIX + tokenId.to_bytes(), receiver)
        #set tokens of owner
        put(ACCOUNT_PREFIX + receiver + tokenId.to_bytes(), tokenId.to_bytes())
        #change Balance of receiver
        change_balance(receiver, 1)
        #create token properties
        put(PROP_PREFIX + tokenId.to_bytes(), propString)
        #call post transfer
        post_transfer(None, receiver, tokenId.to_bytes(), None)

        return True

    else:
        return False

def identifySteamstone(address: UInt160, tokenId: int) -> bool:
    #check if is owner of steamstone
    if (ownerOf(tokenId.to_bytes()) == address):
        charges = get(STEAMSTONE_PREFIX + tokenId.to_bytes() + CHARGE_PREFIX)

        if (charges.to_int() > 0):
            return True
        else:
            return False

    else:
        return False

def takeCharge(tokenId: int):
    charges = get(STEAMSTONE_PREFIX + tokenId.to_bytes() + CHARGE_PREFIX)
    charges = (charges.to_int() - 1).to_bytes()
    put(STEAMSTONE_PREFIX + tokenId.to_bytes() + CHARGE_PREFIX, charges)

@public
def transfer(to: UInt160, tokenId: bytes, data: Any) -> bool:
    assert len(to) == 20, "Incorrect length - to"

    #get current owner
    current_owner = UInt160(get(TOKEN_PREFIX + tokenId))

    if not check_witness(current_owner):
        return False

    if (current_owner != to):
        #reduce balance of sender
        change_balance(current_owner, -1)
        #raise balance of receiver
        change_balance(to, 1)
        #change owner of token
        put(TOKEN_PREFIX + tokenId, to)
        #delete old owner
        delete(ACCOUNT_PREFIX + current_owner + tokenId)
        #set new owner
        put(ACCOUNT_PREFIX + to + tokenId, tokenId)

    post_transfer(current_owner, to, tokenId, None)

    return True

def change_balance(owner: UInt160, amount: int):
    current = balanceOf(owner)
    new = current + amount

    if (new > 0):
        put(BALANCE_PREFIX + owner, new)
    else:
        delete(BALANCE_PREFIX + owner)

@public
def onNEP11Payment(from_address: UInt160, amount: int, tokenId: bytes, data: Any):
    abort()

@public
def onNEP17Payment(from_address: UInt160, amount: int, data_in: str):
    data: Dict[str, Any] = json_deserialize(data_in)
    type = cast(str, data['type'])

    if (type == "steamstone"):
        specific = cast(str, data['specific'])

        if (specific == "new"):
            mintSteamstone(from_address, amount)

        elif (specific == "recharge"):
            tokenId = cast(int, data['tokenId'])
            rechargeSteamstone(from_address, amount, tokenId)

        else:
            abort()

    elif (type == "skin"):
        mintSkin(from_address, amount)

    else:
        abort()


def mintSteamstone(receiver: UInt160, amount: int):
    steamstoneByte = get(STEAMSTONE_PREFIX).to_str()
    steamstoneData: Dict[str, Any] = json_deserialize(steamstoneByte)
    cost = cast(int, steamstoneData['costGAS'])

    if (cost == amount):
        assert len(receiver) == 20, 'Invalid length - receiver'

        propertiesToken = {
            'title': steamstoneData['title'],
            'type': steamstoneData['type'],
            'properties': {
                'name': steamstoneData['name']
            }
        }

        #Create new TokenId
        tokenId = get(SUPPLY_PREFIX).to_int() + 1
        #change total Supply
        put(SUPPLY_PREFIX, tokenId.to_bytes())
        #set token owner
        put(TOKEN_PREFIX + tokenId.to_bytes(), receiver)
        #set tokens of owner
        put(ACCOUNT_PREFIX + receiver + tokenId.to_bytes(), tokenId.to_bytes())
        #change Balance of receiver
        change_balance(receiver, 1)
        #create token properties
        put(PROP_PREFIX + tokenId.to_bytes(), json_serialize(propertiesToken).to_bytes())
        #create charges
        charges = 10
        put(STEAMSTONE_PREFIX + tokenId.to_bytes() + CHARGE_PREFIX, charges.to_bytes())
        #call post transfer
        post_transfer(None, receiver, tokenId.to_bytes(), None)

    else:
        abort()

def rechargeSteamstone(from_address: UInt160, amount: int, tokenId: int):
    #schaune ob besitzer von token
        #amount durch charge dividieren


def mintSkin(receiver: UInt160, amount: int):
    abort()
    #code

        #dataJSON = json_deserialize(data.to_bytes())
        #if (dataJSON.type == "steamstone"):
    #        put(SUPPLY_PREFIX, amount.to_bytes())
    #    else:
    #        val = 87
    #        put(SUPPLY_PREFIX, val.to_bytes())



    #data lesen [wsl String ]
    #wenn sagt SteamStone
        #neuer SteamStone
        #charges Auffüllen von vorhandenen

def post_transfer(owner: Union[UInt160, None], to: Union[UInt160, None], tokenId: bytes, data: Any):
    pass
