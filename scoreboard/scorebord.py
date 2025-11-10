from flask import Flask, request, jsonify, render_template
import json
import time

app = Flask(__name__)

# Global variables for teams and scores
teams = {}
scores = {}

# curl http://127.0.0.1:1234/api/get_scores?ip=192.168.25.140
@app.route('/api/get_scores', methods=['GET'])
def get_scores():
    # ?ip=<team_ip>
    ip = request.args.get('ip')
    if ip:
        if ip not in scores:
            return jsonify({"status": "error", "message": "Invalid IP"}), 400
        return jsonify(scores[ip])
    else:
        return jsonify(scores)

# curl http://127.0.0.1:1234/api/get_teams
@app.route('/api/get_teams', methods=['GET'])
def get_teams():
    return jsonify(teams)

# curl -X POST http://127.0.0.1:1234/api/push_score -H "Content-Type: application/json" -d '{"ip": "192.168.25.140", "points": 50, "reason": "Initial points"}'
@app.route('/api/push_score', methods=['POST'])
def push_score():
    data = request.json
    ip = data.get('ip')
    points = data.get('points')
    points = int(points)
    reason = data.get('reason')
    # hh:mm timestamp
    timestamp = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(time.time() + 9 * 3600))
    if ip not in scores:
        return jsonify({"status": "error", "message": "Invalid IP"}), 400
    scores[ip]["score"] += points
    scores[ip]["actions"].append({
        "time": timestamp,
        "points": points,
        "reason": reason
    })
    return jsonify({"status": "success", "new_score": scores[ip]['score']})

@app.route('/')
def index():
    return render_template('index.html', scores=scores, teams=teams)

def get_config(path):
    try:
        json_open = open(path, 'r')
        print(f'[*] Loaded config from {path}')
    except FileNotFoundError:
        print(f'[-] The file at {path} was not found.')
        return -1
    config = json.load(json_open)
    return config

def main():
    try:
        config = get_config('../attack/config.json')
        if config == -1:
            print("[-] Could not load config from config.json, exiting.")
            exit(1)
        scoreboard_ip = config["scoreboard"]["ip"]
        scoreboard_port = config["scoreboard"]["port"]
        teams = config["teams"]
        scores = {}
        for t in teams:
            ip = teams[t]
            scores[ip] = {
                "team": t,
                "score": 0,
                "actions": []
            }
        return scoreboard_ip, scoreboard_port, teams, scores
    except Exception as e:
        print(f"[-] An error occurred in main(): {str(e)}")
        exit(1)

if __name__ == '__main__':
    # global teams
    # global scores
    ip, port, teams, scores = main()
    print(f"[*] Starting scoreboard on {ip}:{port}")
    app.run(host=ip, port=port)

"""
curl -X POST http://127.0.0.1:1234/api/push_score -H "Content-Type: application/json" -d '{"ip": "192.168.25.140", "points": 50, "reason": "Initial points"}'

curl -X POST http://127.0.0.1:1234/api/push_score -H "Content-Type: application/json" -d '{"ip": "192.168.25.140", "points": 50, "reason": "Good Work"}'

"""