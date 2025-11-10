# AWS Hardening演習環境 Terraform構成

このディレクトリには、Hardening演習用のAWSインフラストラクチャをTerraformで構築するための設定ファイルが含まれています。

## アーキテクチャ概要

```
┌─────────────────────────────────────────────┐
│              Internet                        │
└──────────────────┬──────────────────────────┘
                   │
         ┌─────────▼─────────┐
         │  Internet Gateway  │
         └─────────┬─────────┘
                   │
    ┌──────────────▼───────────────┐
    │   Public Subnet (10.0.1.0/24) │
    │  ┌──────────────────────┐     │
    │  │  Bastion Server      │     │
    │  │  (t3.medium)         │     │
    │  │  Public IP: xxx      │     │
    │  └──────────────────────┘     │
    │  ┌──────────────────────┐     │
    │  │   NAT Gateway        │     │
    │  └──────────────────────┘     │
    └──────────────┬───────────────┘
                   │
    ┌──────────────▼────────────────┐
    │  Private Subnet (10.0.2.0/24) │
    │  ┌──────────────────────┐     │
    │  │  Internal Instances  │     │
    │  │  (WordPress/Flask)   │     │
    │  │  × 9台 (t3.small)    │     │
    │  └──────────────────────┘     │
    │  ┌──────────────────────┐     │
    │  │  Scoreboard/Attack   │     │
    │  │  Server (t3.small)   │     │
    │  └──────────────────────┘     │
    └───────────────────────────────┘
```

### 特徴

- **踏み台サーバー (Bastion)**: 外部からSSH接続可能、パブリックサブネットに配置
- **内部インスタンス**: プライベートサブネット内、踏み台経由でのみアクセス可能
- **NAT Gateway**: 内部インスタンスからの外部接続（パッケージダウンロード等）を可能にする
- **自動初期化**: 内部インスタンスは起動時に指定したGitスクリプトを自動実行
- **スナップショット機能**: 初期化完了後にスナップショットを作成し、リカバリー可能

## 必要なツール

- Terraform >= 1.0
- AWS CLI >= 2.0
- jq (スクリプト実行時に必要)

**注意**: SSH鍵ペアは不要です。すべてのインスタンスにパスワード認証で接続できます。

## セットアップ手順

### 1. 変数ファイルの作成

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`を編集して以下を設定：

- `default_password`: インスタンスのubuntuユーザーのパスワード
- `init_script_url`: 初期化スクリプトのURL
- `internal_instance_count`: 内部インスタンスの数（1-10）

### 2. AWS認証情報の設定

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-northeast-1"
```

または、`aws configure`コマンドで設定。

### 3. Terraformの初期化

```bash
terraform init
```

### 4. インフラストラクチャの作成

```bash
# プランの確認
terraform plan

# 実行
terraform apply
```

適用が完了すると、以下の情報が出力されます：

- 踏み台サーバーのパブリックIP
- 各インスタンスのプライベートIP
- SSH接続コマンド

## 接続方法

### 踏み台サーバーへの接続

```bash
# パスワード認証で接続
ssh ubuntu@<bastion-public-ip>
# パスワード: terraform.tfvarsで設定したもの
```

**注意**: すべてのインスタンスはパスワード認証が有効化されています。SSH鍵は不要です。

### 内部インスタンスへの接続

踏み台サーバーから：

```bash
ssh ubuntu@<internal-private-ip>
```

## スナップショット管理

### 初期スナップショットの作成

初期化スクリプトの実行完了を確認後：

```bash
# スクリプトに実行権限を付与
chmod +x create_snapshots.sh

# スナップショット作成
./create_snapshots.sh
```

### スナップショットからのリストア

```bash
# スクリプトに実行権限を付与
chmod +x restore_from_snapshot.sh

# リストア対象のインスタンスIDを確認
./restore_from_snapshot.sh

# リストア実行
./restore_from_snapshot.sh <instance-id>
```

## 初期化スクリプトの確認

内部インスタンスで初期化スクリプトの実行状況を確認：

```bash
# user-dataの実行ログ
sudo cat /var/log/cloud-init-output.log

# 完了マーカーの確認
cat /var/log/userdata-completion.log
```

## リソース情報の確認

```bash
# すべての出力を表示
terraform output

# 特定の出力を表示
terraform output bastion_public_ip
terraform output internal_instance_ips
```

## カスタマイズ

### インスタンス数の変更

`terraform.tfvars`の`internal_instance_count`を変更：

```hcl
internal_instance_count = 5  # 1-10の範囲
```

変更後に以下を実行：

```bash
terraform plan
terraform apply
```

### インスタンスタイプの変更

`terraform.tfvars`で変更可能：

```hcl
bastion_instance_type  = "t3.large"
internal_instance_type = "t3.medium"
```

## クリーンアップ

すべてのリソースを削除：

```bash
terraform destroy
```

**注意**: スナップショットは自動削除されません。

```bash
# スナップショット一覧
aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[?contains(Description, `Hardening exercise`)]'

# 削除
aws ec2 delete-snapshot --snapshot-id <snapshot-id>
```

## コスト概算

おおよそのコスト（東京リージョン、月額）：

- Bastion (t3.medium): ~$30
- Internal instances (t3.small × 9): ~$135
- Scoreboard (t3.small): ~$15
- NAT Gateway: ~$32
- EBS volumes: ~$10
- **合計: 約$222/月**

