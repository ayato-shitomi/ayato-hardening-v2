
# EASYシナリオ

|攻撃|タイムテーブル|獲得ポイント|
|---|---|---|
|SSHブルートフォース攻撃|開始3分|100ポイント|
|バックドアの悪用|開始6分|50ポイント|
|MySQLブルートフォース攻撃|開始9分|100ポイント|
|WordPressブルートフォース攻撃|開始12分|100ポイント|
|WordPressプラグインLiteSpeed Cacheの悪用|開始15分|150ポイント|
|WordPressバックドアユーザーの悪用|開始18分|100ポイント|
|Flaskデバッグコンソールへの攻撃|開始21分|150ポイント|
|WebDavへの攻撃|開始24分|150ポイント|

## SSHブルートフォース攻撃

- `root`, `user1`, `user2`, `user3`, `user4`, `user5`, `user6`, `user7`, `user8`, `user9`, `user10`, `webadmin`へのブルートフォース攻撃を行います。
- 侵入された場合にはホームディレクトリに`hacked.txt`が生成されます。

## バックドアの悪用

- SSHブルートフォース攻撃にて作成されたバックドア（`backdooruser`, `srvadmin`）からの侵入を試みます。
- 侵入された場合にはホームディレクトリに`hacked_by_backdoor.txt`が生成されます。

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

## WordPressバックドアユーザーの悪用

- 上記3つのバックドアを利用してWEBSHELLプラグインをアップロードされます。
- プラグインがアップロードされた場合には、WEBSHELL経由でブログが作成されます。

## Flaskデバッグコンソールへの攻撃

- デバッグコンソールから任意のPythonコマンドを実行されます。
- PINが`000-000-000`のままの場合には、5000ポートで動いているFlaskの画面が赤くなります。

## WebDavへの攻撃

- WebDavが有効な場合には悪意のあるコンテンツを作成するPHPファイルが作成さます。
- `/wp.sql`にSQLのデータがリークされるようになっています。