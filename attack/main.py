import json
import time

def create_requirements_txt(scenario):
    requirements = set()
    requirements.add('setuptools>=40.8.0')
    requirements.add('futures>=3.0.5')
    for step in scenario['scenario']:
        attack_libs = step.get('attack', {}).get('libraries', [])
        success_libs = step.get('onsuccess', {}).get('libraries', [])
        for lib in attack_libs + success_libs:
            requirements.add(lib)
    requirements = sorted(requirements)
    with open('requirements.txt', 'w') as req_file:
        for lib in requirements:
            req_file.write(f"{lib}\n")
    print('[*] Created requirements.txt with necessary libraries.')

def check_env():
    print('[*] Checking environment for required libraries...')
    try:
        import importlib.util
    except ImportError as e:
        print(f'[-] Missing required library: {e.name}. Please install it using pip.')
        return -1
    with open('requirements.txt', 'r') as req_file:
        for line in req_file:
            lib = line.strip()
            if lib:
                package_name = lib.split('>=')[0]
                if package_name == 'beautifulsoup4':
                    try:
                        import bs4
                    except ImportError:
                        print(f'[-] Missing required library: {package_name}.')
                        print('[-] Please run: "pip install -r requirements.txt".')
                        return -1
                elif package_name == 'futures':
                    try:
                        import concurrent.futures
                    except ImportError:
                        print(f'[-] Missing required library: {package_name}.')
                        print('[-] Please run: "pip install -r requirements.txt".')
                        return -1
                elif importlib.util.find_spec(package_name) is None:
                    print(f'[-] Missing required library: {package_name}.')
                    print('[-] Please run: "pip install -r requirements.txt".')
                    return -1
    print('[*] All required libraries are installed.')
    return 0

def get_config(path):
    try:
        json_open = open(path, 'r')
        print(f'[*] Loaded config from {path}')
    except FileNotFoundError:
        print(f'[-] The file at {path} was not found.')
        return -1
    config = json.load(json_open)
    return config

def get_scenario(path):
    try:
        json_open = open(path, 'r')
        print(f'[*] Loaded scenario from {path}')
    except FileNotFoundError:
        print(f'[-] The file at {path} was not found.')
        return -1
    scenario = json.load(json_open)
    return scenario

def push_scoreboard(ip, points, reason):
    for t in teams:
        if teams[t] == ip:
            team = t
    print("\033[31m")
    print(f"[*] Pushing {points} points to scoreboard for {team} / {ip} - Reason: {reason}")
    print("\033[0m")
    import requests
    url = f"{scoreboard_url}/api/push_score"
    data = {
        "ip": ip,
        "points": points,
        "reason": reason
    }
    try:
        res = requests.post(url, json=data)
        if res.status_code != 200:
            print(f"[-] Could not push score to scoreboard: {res.text}")
            return -1
        print(f"[+] Successfully pushed score to scoreboard: {res.text}")
    except Exception as e:
        print(f"[-] Error pushing score to scoreboard: {e}")
        return -1
    return 0

def run_attack(ip, step):
    try:
        print(f"[*] Running attack: {step['name']}")
        print(f"[*] Attack description: {step['description']}")
        attack_module_path = step['attack']['module']
        print(f"[*] Loading attack module from: {attack_module_path}")
        attack_options = step['attack'].get('options', {})
        print("[*] Attack options:")
        for option, value in attack_options.items():
            print(f"    |- {option}: {str(value)[0:50]}{' <SNIP>' if len(str(value)) > 50 else ''}")
        import importlib.util
        from pathlib import Path
        spec = importlib.util.spec_from_file_location("attack_module", Path(attack_module_path).resolve())
        attack_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(attack_module)
        ret = attack_module.run(ip, **attack_options)
        if 'onsuccess' in step and ret != -1:
            print(f"[*] Running onsuccess module for attack: {step['name']}")
            onsuccess_module_path = step['onsuccess']['module']
            print(f"[*] Loading onsuccess module from: {onsuccess_module_path}")
            onsuccess_options = step['onsuccess'].get('options', {})
            print("[*] Onsuccess options:")
            for option, value in onsuccess_options.items():
                if value == "RETURN_VALUE":
                    value = ret
                    onsuccess_options[option] = value
                print(f"    |- {option}: {str(value)[0:50]}{' <SNIP>' if len(str(value)) > 50 else ''}")
            spec = importlib.util.spec_from_file_location("onsuccess_module", Path(onsuccess_module_path).resolve())
            onsuccess_module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(onsuccess_module)
            ret = onsuccess_module.run(ip, **onsuccess_options)
        if ret == -1:
            print(f"[-] Attack {step['name']} failed on {ip}.")
            if 'gain_points' in step:
                push_scoreboard(ip, step['gain_points'] , f"Defended against {step['name']}")
            return -1
        else:
            print(f"[+] Attack {step['name']} succeeded on {ip}.")
            push_scoreboard(ip, 0, f"Attacker succeeded in {step['name']}")
    except Exception as e:
        print(f"[-] Error running attack {step['name']} on {ip}: {e}")
        return -1
    return 0

def run_scenario(victim_ips, scenario):
    print('[*] Starting attack scenario...')
    # Initial point deduction for all teams
    for ip in victim_ips:
        push_scoreboard(ip, scenario.get('initial_point_deduction', 100), "Initial point deduction at scenario start")
    for step in scenario['scenario']:
        print("--------------------------------")
        print(f"[*] Preparing to execute attack: {step['name']} in {step.get('start', 0)} minutes")
        time.sleep(step.get('start', 0) * 60)
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor() as executor:
            futures = [executor.submit(run_attack, ip, step) for ip in victim_ips]
            for future in concurrent.futures.as_completed(futures):
                future.result()
    return 0

def check_scoreboard(config):
    import requests
    scoreboard_ip = config["scoreboard"]["ip"]
    scoreboard_port = config["scoreboard"]["port"]
    url = f"http://{scoreboard_ip}:{scoreboard_port}"
    print(f"[*] Checking scoreboard: {url}")
    try:
        res = requests.get(url)
        if res.status_code != 200:
            print(f"[-] Could not connect scoreboard {url}")
            return False
        return url
    except Exception as e:
        print(f"[-] Scoreboard check error: {e}")
        return False

def main():
    global teams
    global scoreboard_verbose
    global scoreboard_url
    config = get_config('config.json')
    if config == -1:
        return -1
    scenario_path = config['senario_path']
    scenario = get_scenario(scenario_path)
    if scenario == -1:
        return -1
    create_requirements_txt(scenario)
    if check_env() == -1:
        return -1
    scoreboard_url = check_scoreboard(config)
    if scoreboard_url == False:
        return -1
    victim_ips = config['victim_ips']
    teams = config['teams']
    scoreboard_verbose = config["scoreboard"].get("verbose", False)
    run_scenario(victim_ips, scenario)

if __name__== '__main__':
    main()