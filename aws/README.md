# AWS Hardening Exercise Infrastructure

Ubuntu 24.04ベースのハードニング演習用Terraformインフラストラクチャー

## 概要

このTerraform設定は、セキュリティハードニング演習用のAWSインフラを自動構築します。

### 構成要素

- **Bastion Server**: 踏み台サーバー（パブリックサブネット）
- **Internal Servers**: 内部サーバー x 2（プライベートサブネット）
- **Scoreboard/Attack Server**: スコアボード・攻撃サーバー（プライベートサブネット）

## 使用方法

### 1. 初期化

```bash
terraform init

export AWS_ACCESS_KEY_ID="AKIAxxxxxxxxxxxx"
export AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxx"
export AWS_DEFAULT_REGION="ap-northeast-1"
```

### 2. 変数設定

`terraform.tfvars.example`を参照してファイルを編集して、必要な変数を設定します。

### 3. デプロイ

```bash
terraform plan
terraform apply
```

### 4. 接続

デプロイ完了後、出力されるBastionサーバーのPublic IPに接続：

```bash
ssh ubuntu@<bastion-public-ip>
```

### 5. 利用後

```bash
terraform destroy
```
