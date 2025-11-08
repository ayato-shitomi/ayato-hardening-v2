#!/bin/bash

echo ""
echo "AYATO HARDENING v2.0 Installer"
echo ""
echo "[*] Initializing srv..."
echo "[*] Setting up with user `whoami`"

# get server IP from argument
IP="$1"
if [ -z "$IP" ]; then
  echo "[-] Usage: sudo $0 <SERVER_IP>"
  exit 1
fi

# check if user is root
if [ "$(id -u)" != "0" ]; then
   echo "[-] This script must be run as root" 1>&2
   exit 1
fi

# installing with apt
echo "[*] Installing required packages"
sudo apt update &> /dev/null
sudo apt install python3-pip python3-venv iputils-ping -y > /dev/null &> /dev/null
sudo apt install apache2 php libapache2-mod-php mysql-server php-mysql wget vim apache2-utils cron -y &> /dev/null

# enable ssh service
echo "[*] Enabling SSH service"
sudo systemctl enable ssh &> /dev/null
sudo systemctl start ssh &> /dev/null

# enable root login via ssh
echo "[*] Enabling root login via SSH"
sudo sed -i 's/^#\?\s*PermitRootLogin\s\+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd &> /dev/null

# MaxSessions set to 100
# MaxAuthTries set to 100
# MaxStartups set to 100:100:200
echo "[*] Setting MaxSessions, MaxAuthTries and MaxStartups in sshd_config"
sudo sed -i '/^#\?\s*MaxSessions\s\+.*/d' /etc/ssh/sshd_config
sudo sed -i '/^#\?\s*MaxAuthTries\s\+.*/d' /etc/ssh/sshd_config
sudo sed -i '/^#\?\s*MaxStartups\s\+.*/d' /etc/ssh/sshd_config
echo "MaxSessions 100" >> /etc/ssh/sshd_config
echo "MaxAuthTries 100" >> /etc/ssh/sshd_config
echo "MaxStartups 100:100:200" >> /etc/ssh/sshd_config
sudo systemctl restart sshd &> /dev/null

# enable cron service
echo "[*] Enabling cron service"
sudo systemctl enable --now cron &> /dev/null
sudo systemctl start cron &> /dev/null

# set user configrations
echo "[*] Adding user: hardening"
useradd -m -s /bin/bash hardening
echo "[*] Adding user: webadmin"
useradd -m -s /bin/bash webadmin
for i in {1..10}; do
  echo "[*] Adding user: user$i"
  useradd -m -s /bin/bash user$i
done
# set all user passwords to their username
echo "[*] Changing all user passwords to their username"
grep -Ff /etc/shells /etc/passwd | cut -d: -f1 | while read -r user; do
  echo "$user:$user"
done | sudo chpasswd

# set vulnerable sudo to user1
# allow find command with sudo 
echo "[*] Setting vulnerable sudo to user1"
echo "user1 ALL=(ALL) NOPASSWD: /usr/bin/find" >> /etc/sudoers

echo "[*] Setting up sudo to user2, 3, 5, 6, 10"
echo "user2 ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "user3 ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "user5 ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "user6 ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "user10 ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# set up flask app
echo "[*] Setting up flask app"
mkdir /home/webadmin/app
# create a simple flask app
echo "[*] Creating flask app"
cat << 'EOF' > /home/webadmin/app/app.py
from flask import Flask, request, jsonify, send_from_directory
import logging
import subprocess
import os

app = Flask(__name__)
os.environ['WERKZEUG_DEBUG_PIN'] = '000-000-000'
applog = "/home/webadmin/app/app.log"

logging.basicConfig(
    filename=applog,
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s in %(module)s: %(message)s'
)

@app.route('/')
def index():
    return send_from_directory('templates', 'index.html')

@app.route('/api/status')
def status():
    services = ['ssh', 'apache2', 'mysql', 'flaskapp']
    status = {}
    for srv in services:
        try:
            cmd = f'systemctl status {srv}'
            res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            res = res.stdout.decode().split('\n')
            for r in res:
                if 'Active:' in r:
                    status[srv] = r.replace('Active: ', '').lstrip()
                    break
                status[srv] = 'Unknown'
        except Exception as e:
            jsonify({'result': e}), 500
    return jsonify({'result': status}), 200

@app.route('/api/ping', methods=['POST', 'GET'])
def ping():
    if request.method == 'GET':
        return jsonify({'message': 'Send a POST request with JSON body {"target": "hostname or IP"}'}), 200
    data = request.get_json()
    if not data or 'target' not in data:
        return jsonify({'error': 'No target provided'}), 400
    target = data['target']
    cmd = f'ping -c 1 {target}'
    res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return jsonify({'output': res.stdout.decode(), 'error': res.stderr.decode()}), 200

@app.route('/api/echo', methods=['POST', 'GET'])
def echo():
    if request.method == 'GET':
        return jsonify({'message': 'Send a POST request with JSON body {"message": "your message"}'}), 200
    data = request.get_json()
    if not data or 'message' not in data:
        return jsonify({'error': 'No message provided'}), 400
    message = data['message']
    return jsonify({'echo': message}), 200

@app.route('/api/logs', methods=['POST', 'GET'])
def logs():
    filename = request.args.get('filename') or request.form.get('filename')
    if filename == '' or filename is None:
        filename = applog
    if not os.path.isfile(filename):
        return jsonify({'error': f'File {filename} does not exist'}), 400
    if not os.access(filename, os.R_OK):
        return jsonify({'error': f'File {filename} Permission denied'}), 403
    return send_from_directory(
        directory=os.path.dirname(filename),
        path=os.path.basename(filename),
        as_attachment=True
    )

# バグ修正が必要
@app.route('/api/users')
def users():
    cmd = 'grep -Ff /etc/shells /etc/passwd | cut -d: -f1 | while read -r user; do echo "$user" ;done'
    try:
        res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        users = res.stdout.decode().split('\n')
        user_list = []
        for u in users:
            if u:
                user_list.append(u)
    except Exception as e:
        return jsonify({'result': e}), 500
    return jsonify({'result': list}), 200

if __name__ == '__main__':
    app.run('0.0.0.0', 5000, debug=True)
EOF
# create index.html flask template
echo "[*] Setting permissions for flask app"
mkdir /home/webadmin/app/templates
cat << 'EOF' > /home/webadmin/app/templates/index.html
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <title>サーバー管理コンソール</title>
</head>
<body>
    <h1>サーバー管理コンソール</h1>
    <h2>サーバーステータス</h2>
    <div id="status"></div>
    <script>
        async function fetchStatus() {
            const response = await fetch('/api/status');
            const data = await response.json();
            let statusHtml = '<ul>';
            for (const [service, state] of Object.entries(data.result)) {
                statusHtml += `<li>${service}: ${state}</li>`;
            }
            statusHtml += '</ul>';
            document.getElementById('status').innerHTML = statusHtml;
        }
        fetchStatus();
    </script>
    <h2>管理コンソールへのアクセスログ</h2>
    <p>最後の50行のログを表示しています。</p>
    <div id="logs" style="background-color: #f0f0f0; padding: 10px; border: 1px solid #ccc; height: 300px; overflow-y: scroll;"></div>
    <script>
        async function fetchLogs() {
            const response = await fetch('/api/logs');
            const logText = await response.text();
            const logLines = logText.trim().split('\n');
            const last20Lines = logLines.slice(-50).join('<br>');
            document.getElementById('logs').innerHTML = last20Lines;
        }
        fetchLogs();
    </script>
    <h2>サーバーユーザー一覧</h2>
    <div id="users"></div>
    <script>
        async function fetchUsers() {
            const response = await fetch('/api/users');
            // 取得できなかった場合の処理を追加
            if (!response.ok) {
                document.getElementById('users').innerHTML = 'ユーザー情報の取得に失敗しました。';
                return;
            }
            const data = await response.json();
            let usersHtml = '<ul>';
            data.result.forEach(function(user) {
                usersHtml += `<li>${user}</li>`;
            });
            usersHtml += '</ul>';
            document.getElementById('users').innerHTML = usersHtml;
        }
        fetchUsers();
    </script>
    <h2>Pingテスト</h2>
    <p>開発中...</p>
</body>
</html>
EOF
# set ownership to webadmin
chown -R webadmin:webadmin /home/webadmin/app
chmod 755 /home/webadmin/app
echo "[*] Installing flask to webadmin user"
sudo -u webadmin -H bash -lc '
cd /home/webadmin/
python3 -m venv .venv
. .venv/bin/activate
pip install flask==2.2.5 werkzeug==2.2.3 gunicorn &> /dev/null
'
# create systemd service for flask app
echo "[*] Setting up flask systemctl"
cat << 'EOF' > /etc/systemd/system/flaskapp.service
[Unit]
Description=Flask App
After=network.target
[Service]
User=webadmin
WorkingDirectory=/home/webadmin/app
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/webadmin/.venv/bin"
ExecStart=/home/webadmin/.venv/bin/python /home/webadmin/app/app.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF
# start flask app
echo "[*] Starting flask app"
systemctl daemon-reload &> /dev/null
systemctl enable flaskapp &> /dev/null
systemctl start flaskapp
systemctl restart flaskapp
echo "[*] Flask app is running on port 5000"

# install wordpress
echo "[*] Installing wordpress and dependencies"
sudo systemctl enable apache2 &> /dev/null
sudo systemctl start apache2 
sudo systemctl enable mysql &> /dev/null
sudo systemctl start mysql
# setup mysql
echo "[*] Setting up databases"
sudo mysql -e "CREATE DATABASE wp; CREATE USER 'wpuser'@'localhost' IDENTIFIED BY 'wpuser'; GRANT ALL ON wp.* TO 'wpuser'@'localhost'; FLUSH PRIVILEGES;"
sudo mysql -e "CREATE USER 'wpuser'@'%' IDENTIFIED BY 'wpuser';"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'wpuser'@'%' WITH GRANT OPTION;"
sudo mysql -e "FLUSH PRIVILEGES;"
sudo sed -i 's/^#\?\s*bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
echo '[mysqld]' >> /etc/mysql/my.cnf
echo 'secure_file_priv = /' >> /etc/mysql/my.cnf
systemctl restart mysql
# install wp-cli
echo "[*] Installing WP-CLI"
cd /usr/local/bin && sudo curl -LO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -s && sudo mv wp-cli.phar wp && sudo chmod +x wp
sudo mkdir -p /var/www/html && sudo chown -R www-data:www-data /var/www/html
cd /var/www/html
# setup wordpress
echo "[*] Setting up WordPress"
sudo -u www-data -H bash -lc "
cd /var/www/html
mv /var/www/html/index.html /var/www/html/index.html.bak
wp core download --locale=ja &> /dev/null
echo '[*] Adding user admin'
wp core config --dbname=wp --dbuser=wpuser --dbpass='wpuser' --dbhost=localhost --dbprefix=wp_ &> /dev/null
wp core install --url='http://$IP' --title='守るぜWordPress' --admin_user=admin --admin_password='admin' --admin_email=example@example.com &> /dev/null
echo '[*] Adding user wpmanager'
wp user create wpmanager wpmanager@example.com --role=administrator --user_pass='wpmanager' &> /dev/null
"
# update default page content
echo "[*] Updating default page content"
sudo -u www-data -H bash -lc '
cd /var/www/html
PAGE_ID=$(wp post list --post_type=page --name=sample-page --format=ids)
PAGE_ID=${PAGE_ID:-2}
cat > /tmp/page_content.html <<'"HTML"'
<h2>ようこそ！</h2>
<p>我々の作成したWordPressサイトは<strong>決して</strong>ハッキングされません！</p>
セキュリティ・パフォーマンス・UXすべてを考慮した構成です。</p>
<ul>
  <li><strong>サーバー:</strong> Apache + PHP + MySQL</li>
  <li><strong>自動構築:</strong> wp-cli &amp; bash スクリプト</li>
</ul>
編集するには <a href="/wp-admin/">管理画面</a> にログインしてくださいね。</p>
HTML
wp post update "$PAGE_ID" \
  --post_title="はじめに - Welcome to WordPress" \
  --post_status=publish \
  --post_title="守ろう！" \
  --post_content="$(cat /tmp/page_content.html)" &> /dev/null
rm -f /tmp/page_content.html
'
# update blog post
echo "[*] Updating default blog post"
sudo -u www-data -H bash -lc '
cd /var/www/html
POST_ID=$(wp post list --post_type=post --name=hello-world --format=ids)
POST_ID=${POST_ID:-1}
cat > /tmp/post_content.html <<'"HTML"'
<p>独自開発を行っているプラグインの有効化を行いました。</p>
<p>アクセスログを表示することができます。<a href="/index.php/access-counter/">こちらより</a>アクセスしてください。</p>
HTML
wp post update "$POST_ID" \
  --post_title="Plugin update" \
  --post_status=publish \
  --post_content="$(cat /tmp/post_content.html)" &> /dev/null
rm -f /tmp/post_content.html
'
echo "[*] Creating new blog post"
sudo -u www-data -H bash -lc '
cd /var/www/html
cat > /tmp/new_post.html <<'"HTML"'
<p>ブログを公開状態にして皆さんに見えるようにしました。</p>
<p>どんどんアップデートするのでこうご期待！</p>
HTML
wp post create \
  --post_type=post \
  --post_status=publish \
  --post_title="Announce of Blog Publishing" \
  --post_author=1 \
  --post_content="$(cat /tmp/new_post.html)" &> /dev/null
rm -f /tmp/new_post.html
'
sudo chown -R www-data:www-data /var/www/html
sudo a2enmod rewrite &> /dev/null
sudo systemctl restart apache2

# Enable wordpress debug mode
echo "[*] Enabling WordPress debug mode"
sudo -u www-data -H bash -lc '
cd /var/www/html
wp config set WP_DEBUG true --raw &> /dev/null
wp config set WP_DEBUG_LOG true --raw &> /dev/null
wp config set WP_DEBUG_DISPLAY false --raw &> /dev/null
'
# install a vulnerable plugin
echo "[*] Installing a vulnerable plugin: LiteSpeed Cache v6.4.1"
sudo -u www-data -H bash -lc '
cd /var/www/html
wp plugin install litespeed-cache --version=6.4.1 --force &> /dev/null
'
echo "[*] Enabling debug mode for LiteSpeed Cache plugin"
sudo -u www-data -H bash -lc '
cd /var/www/html
wp plugin activate litespeed-cache &> /dev/null
wp option update 'litespeed.conf.debug' '1' &> /dev/null
wp option update 'litespeed.conf.debug-level' 'advanced' &> /dev/null
wp option update 'litespeed.conf.debug-cookie' '1' &> /dev/null
wp option update 'litespeed.conf.debug-filesize' '10' &> /dev/null
'
echo "[*] Creating a custom plugin: Access Counter"
sudo -u www-data -H bash -lc '
cd /var/www/html
mkdir /var/www/html/wp-content/plugins/access-counter
cat >/tmp/access_counter.php <<'EOF'
<?php
/*
Plugin Name: Access Counter
Description: A simple access counter plugin
Version: 1.2
Author: Access Counter Dev
*/

function ac_increment_counter() {
  \$count = (int) get_option("ac_access_count", 0);
  \$count++;
  update_option("ac_access_count", \$count);
  return \$count;
}

function ac_display_counter() {
  \$count = ac_increment_counter();
  return "<div>このページのアクセス数: <strong>{\$count}</strong></div>";
}

function ac_debug() {
  \$select_table = \$_POST["select_table"] ?? "options";
  global \$wpdb;
  \$table = \$wpdb->prefix . \$select_table;
  \$query = "SELECT * FROM " . \$table . " WHERE option_name = \"ac_access_count\";";
  echo "[*] Debug: " . \$query;
  echo "\n[*] Results:";
  \$wpdb->query(\$query);
  if (\$wpdb->last_error) {
    echo "\n[-] Error: " . \$wpdb->last_error;
    wp_die();
  } else {
    \$results = \$wpdb->get_results(\$query);
    foreach (\$results as \$row) {
      foreach (\$row as \$key => \$value) {
        echo "\n    " . \$key . " => " . \$value;
      }
    }
  }
  echo "\n[+] Executed";
  wp_die();
}

add_action("wp_ajax_ac_set_count", "ac_debug");
add_action("wp_ajax_nopriv_ac_set_count", "ac_debug");

add_shortcode("access_counter", "ac_display_counter");
EOF
mv /tmp/access_counter.php /var/www/html/wp-content/plugins/access-counter/access-counter.php
rm -f /tmp/access_counter.php
wp plugin activate access-counter &> /dev/null
'
echo "[*] Adding access counter page"
sudo -u www-data -H bash -lc '
cd /var/www/html
cat > /tmp/counter_page.html <<'"HTML"'
[access_counter]
HTML
wp post create --post_type=page \
  --post_status=publish \
  --post_title="Access Counter" \
  --post_content="$(cat /tmp/counter_page.html)" \
  --porcelain &> /dev/null
rm -f /tmp/counter_page.html
'
echo "[*] WordPress installation completed"
echo "[*] WordPress is running on http://$IP"

# Setup webdav in /var/www/
echo "[*] Setting up WebDAV"
sudo a2enmod dav &> /dev/null
sudo a2enmod dav_fs &> /dev/null
sudo a2enmod rewrite &> /dev/null
sudo sed -i '/<Directory \/var\/www\/>/a Dav On' /etc/apache2/apache2.conf
sudo sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
echo "[*] Restarting Apache server"
sudo systemctl restart apache2

# detabase backup
echo "[*] Creating database backup script"
cat << 'EOF' > /usr/local/bin/db_backup.sh
#!/bin/bash
DATE=$(date +"%Y%m%d")
DB_NAME="wp"
BACKUP_DIR="/tmp/dbbackups/"

mkdir -p "$BACKUP_DIR" 2> /dev/null
rm -f "$BACKUP_DIR"/*
sudo mysqldump -u"root" "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}_${DATE}.sql"
chmod 644 "$BACKUP_DIR/${DB_NAME}_${DATE}.sql"
EOF
chmod +x /usr/local/bin/db_backup.sh

# setup cron job for database backup
echo "[*] Setting up cron job for database backup"
echo 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' > /etc/cron.d/db_backup
echo '5 * * * * root /usr/local/bin/db_backup.sh' >> /etc/cron.d/db_backup
echo '' >> /etc/cron.d/db_backup
chmod 644 /etc/cron.d/db_backup
chown root:root /etc/cron.d/db_backup

# finalizing
echo "[*] Deleting init.sh"
rm -- "$0"
echo "[*] Ayato Hardening v2 Setup completed!"