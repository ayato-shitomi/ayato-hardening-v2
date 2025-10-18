
# サーバー初期化方法

rootユーザーで実行してください。

```bash
curl -s -o /tmp/init.sh http://172.22.52.55/init.sh
sudo /bin/bash -c "chmod +x /tmp/init.sh; /tmp/init.sh 192.168.204.130"
```

# 脆弱性一覧

## 脆弱なユーザーパスワード

- `root`, `webadmin`ユーザーはユーザー名がパスワードになっている
- `user1` ~ `user10` はユーザー名がパスワードになっている

## 脆弱なsudo権限

`user1`はsudoでfindコマンドを実行可能

## 脆弱なWEBアプリケーション

5000番ポートで動いているWEBアプリケーションはOSコマンドインジェクションが可能

```
┌──(ayato㉿redTeam)-[~/ayato-hardening-v2]
└─$ curl -X POST http://192.168.204.130:5000/api/ping --data '{"target": "1.1.1.1;whomi"}' -H "Content-Type: application/json" -s | jq
{
  "error": "/bin/sh: 1: whomi: not found\n",
  "output": "PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.\n64 bytes from 1.1.1.1: icmp_seq=1 ttl=128 time=6.42 ms\n\n--- 1.1.1.1 ping statistics ---\n1 packets transmitted, 1 received, 0% packet loss, time 0ms\nrtt min/avg/max/mdev = 6.418/6.418/6.418/0.000 ms\n"
}
```

# 脆弱なWordPress管理者パスワード

80番で動いているWordPressはユーザー`admin`と`wpmanager`はユーザー名と同様のパスワードでログインが可能

# 脆弱なWordPressプラグイン

# 脆弱なMySQLの設定

MySQLはポートが外部に開放されており、`wpuser`は`wpuser`でログインが可能。