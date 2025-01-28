# Bicepを使ったAzure Virtual NetworkとVirtual Machineの作成手順例

本リポジトリのコードを使って、Azureの任意のリージョンにVNetを1つ、そのなかにサブネットを10こ、ストレージアカウントを1つ作成し、各サブネットにVMを1台ずつ、それぞれにPublic IPを付与した状態で作成する手順を示します。

## 前提条件、利用ツール

### 前提条件

本リポジトリで示す手順はサブスクリプションの所有者ロールを割り当てられたアカウントで実行することを前提としています。

本作業例はmacOS 15.2のzshで動作を確認しています。

本作業ではVMを作成し管理者アカウントでログイン、データディスクのフォーマットとマウント、Infinibandドライバーのインストール、IP over InfinibandでのVM間相互通信までを行います。

すべてのVMで同じ公開鍵を登録します。

管理者以外のアカウントの作成やその他の設定は対象外です。

### 利用ツール

ツールは以下のものを利用します。
- [Git](https://git-scm.com/)
- [Visual Studio Code](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/install#azure-cli)
- [Azure CLI](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/install#azure-cli)
- [Bicep CLI](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/install#azure-cli)

作業に入る前にあらかじめAzureサブスクリプションの作成、利用するリージョンおよびVMのSKUのクォータを確保しておいてください。本リポジトリのコードでは以下の値でVMを作成します。

- リージョン: リソースグループを作成する際に指定
- vmType (Bicepのパラメータとして設定された変数で以下の2種類があり、この値によってVM SKU、VMイメージが決定される):
    - General: 
        - VM SKU: [Dasv5シリーズ Standard_D2as_v5](https://learn.microsoft.com/ja-jp/azure/virtual-machines/sizes/general-purpose/dasv5-series?tabs=sizebasic)
        - VMイメージ: Canonical:ubuntu-24_04-lts:server:latest
    - HPC:
        - VM SKU: [NDv2シリーズ Standard_ND40rs_v2](https://learn.microsoft.com/ja-jp/azure/virtual-machines/sizes/gpu-accelerated/ndv2-series?tabs=sizebasic)
        - VMイメージ: microsoft-dsvm:ubuntu-hpc:2204:22.04.2024102301
    - HPC2:
        - VM SKU: [ND-H100-v5シリーズ Standard_ND96isr_H100_v5](https://learn.microsoft.com/ja-jp/azure/virtual-machines/sizes/gpu-accelerated/ndh100v5-series?tabs=sizebasic)
- OSディスク: Premium SSD LRS
- データディスク: Premium SSD LRS 1TB
- NIC: Public IPを付加

本リポジトリのコードを修正し、任意のVMのSKU、イメージを利用することが可能です。

## 作業の流れ

作業は以下の順に実行します。

1. VM作成事前作業 (ここまではAzureの費用なしに可能)
    1. 本リポジトリのクローン
    2. リソースグループの作成
    3. VNet及び各VM用のサブネット、ストレージアカウントの作成
    4. 各VMログイン用のキーペアの作成

2. VM作成作業 (ここから費用が発生)
    1. VMの作成、パブリックIPの割当、データディスクのアタッチ
    2. ログイン確認

3. 通常のVMとしての作業
    1. データディスクのフォーマットとマウント
    2. Blobfuse2を使ったBlob Storageのマウント

3. HPC用作業
    1. Infinibandドライバーのインストール、有効化
    2. IP over InfinibandでのVM相互通信テスト

## VM作成事前作業

### 1-i. 本リポジトリのクローン

作業端末で本リポジトリをクローンします。

```zsh
git clone https://github.com/hironariy/VnetAndVmCreationWithBicep.git
```

### 1-ii. リソースグループの作成

Azure CLIにログインします。

```Azure CLI
az login
```

必要に応じて作業対象のサブスクリプションに移動します。

```Azure CLI
# ログインしたアカウントで利用可能なサブスクリプションの表示
az account show --output table

# アクティブなサブスクリプションの設定
az account set --subscription <サブスクリプション名 or サブスクリプションID>
```

サブスクリプション内にリソースグループを作成します。

```Azure CLI
az group create --name <任意のリソースグループ名> --location <任意のリージョン>
# 代表的なリージョン
# japaneast 東日本
# australiaeast オーストラリア東部
# westeurope ヨーロッパ西部
```
### 1-iii. VNet及び各VM用のサブネット、ストレージアカウントの作成

本リポジトリのコードを使ってVNet、その中のサブネット、ストレージアカウントを作成します。

```Azure CLI
az deployment group create -g <リソースグループ名> --template-file VnetAndSaCreation.bicep
```

コマンド実行後にサブネット作成数を入力します。後に作成するVMと同じ数にします。

```zsh
#  作成するサブネットの数を入力。最小 1、最大 10
Please provide int value for 'subnetCount' (? for help): <1から10までの任意の整数>
```




    

