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
sudo apt install apache2 php libapache2-mod-php mysql-server php-mysql wget -y &> /dev/null

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

# set up flask app
echo "[*] Setting up flask app"
mkdir /home/webadmin/app
# create a simple flask app
echo "[*] Creating flask app"
cat << 'EOF' > /home/webadmin/app/app.py
from flask import Flask, request, jsonify
import subprocess

app = Flask(__name__)
app.config['DEBUG'] = True

@app.route('/')
def hello():
	return "Welcome to server api!"

@app.route('/api/ping', methods=['POST', 'GET'])
def ping():
	if request.method == 'GET':
		return jsonify({'message': 'Send a POST request with JSON body {"target": "hostname or IP"}'}), 200
	data = request.get_json()
	if not data or 'target' not in data:
		return jsonify({'error': 'No target provided'}), 400
	target = data['target']
	cmd = f"ping -c 1 {target}"
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

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF
# set ownership to webadmin
chown -R webadmin:webadmin /home/webadmin/app
chmod 755 /home/webadmin/app
echo "[*] Installing flask to webadmin user"
sudo -u webadmin -H bash -lc '
cd /home/webadmin/
python3 -m venv .venv
. .venv/bin/activate
pip install flask gunicorn &> /dev/null
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
<p>コンテンツを編集するには <a href="/wp-admin/">管理画面</a> にログインしてくださいね。</p>
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
<p>簡単にサーバーログを保存することが可能となりサーバーをよりセキュアに保つことが可能です。</p>
HTML
wp post update "$POST_ID" \
  --post_title="プラグインアップデート" \
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
# 新規投稿を作成
wp post create \
  --post_type=post \
  --post_status=publish \
  --post_title="ブログ公開のお知らせ" \
  --post_author=1 \
  --post_content="$(cat /tmp/new_post.html)" &> /dev/null
rm -f /tmp/new_post.html
'
sudo chown -R www-data:www-data /var/www/html
sudo a2enmod rewrite &> /dev/null
sudo systemctl restart apache2
# install a vulnerable plugin
echo "[*] Installing a vulnerable plugin: "

sudo -u www-data -H bash -lc '
cd /var/www/html/wp-content/plugins
mkdir easy-log-viewer
cd easy-log-viewer

echo "[*] WordPress installation completed"


echo "[*] WordPress is running on http://$IP"