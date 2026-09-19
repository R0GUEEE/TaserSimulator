#!/usr/bin/env python3
import os, time, json, base64, sys
import requests
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import ec, utils

KEY_PATH = os.environ.get('ASC_KEY_PATH', '/var/minis/attachments/uploads/AuthKey_NP38M6W8KF.p8')
KEY_ID = os.environ['APP_STORE_CONNECT_API_KEY_ID']
ISSUER_ID = os.environ['APP_STORE_CONNECT_API_ISSUER_ID']
BASE = 'https://api.appstoreconnect.apple.com/v1'

def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

def jwt_token():
    with open(KEY_PATH, 'rb') as f:
        key = serialization.load_pem_private_key(f.read(), password=None)
    now = int(time.time())
    header = {'alg':'ES256','kid':KEY_ID,'typ':'JWT'}
    payload = {'iss':ISSUER_ID,'iat':now,'exp':now+900,'aud':'appstoreconnect-v1'}
    msg = (b64url(json.dumps(header,separators=(',',':')).encode())+'.'+b64url(json.dumps(payload,separators=(',',':')).encode())).encode()
    der = key.sign(msg, ec.ECDSA(hashes.SHA256()))
    r,s = utils.decode_dss_signature(der)
    sig = r.to_bytes(32,'big') + s.to_bytes(32,'big')
    return msg.decode()+'.'+b64url(sig)

def get(path, params=None):
    r = requests.get(BASE+path, headers={'Authorization':'Bearer '+jwt_token()}, params=params or {}, timeout=30)
    print('HTTP', r.status_code, file=sys.stderr)
    if r.status_code >= 400:
        print(r.text[:1000], file=sys.stderr)
        sys.exit(1)
    return r.json()

if __name__ == '__main__':
    bundle = sys.argv[1] if len(sys.argv)>1 else 'com.r0gueee.stunfun'
    apps = get('/apps', {'filter[bundleId]': bundle, 'limit': 1})
    print(json.dumps(apps, indent=2))
