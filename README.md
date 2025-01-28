# Bicepを使ったAzure Virtual NetworkとVirtual Machineの作成手順例

本リポジトリのコードを使って、Azureのオーストラリア東部リージョンにVNetを1つ、そのなかにサブネットを10こ作成し、各サブネットにVMを1台ずつ、それぞれにPublic IPを付与した状態で作成する手順を示します。

## 前提条件、利用ツール

本リポジトリで示す手順はサブスクリプションの所有者ロールを割り当てられたアカウントで実行することを前提としています。

ツールは以下のものを利用します。
- [Visual Studio Code](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/install#azure-cli)
- [Azure CLI](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/install#azure-cli)
- [Bicep CLI](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/install#azure-cli)

以下の作業に入る前にあらかじめAzureサブスクリプションの作成、利用するリージョンおよびVMのSKUのクォータを確保しておいてください。本リポジトリのコードでは以下の値でVMを作成します。

- VmCreation.bicep
    - リージョン: オーストラリア東部(australiaeast)リージョン
    - VM SKU: [Dasv5シリーズ](https://learn.microsoft.com/ja-jp/azure/virtual-machines/sizes/general-purpose/dasv5-series?tabs=sizebasic)
- HpcVmCreation.bicep
    - リージョン: オーストラリア東部(australiaeast)リージョン
    - VM SKU: [NDv2シリーズ](https://learn.microsoft.com/ja-jp/azure/virtual-machines/sizes/gpu-accelerated/ndv2-series?tabs=sizebasic)

本リポジトリのコードを修正し、任意のリージョン、VMのSKUを利用することが可能です。

## 作業の流れ

作業は以下の順に実行します。

1. VM作成 事前作業 (ここまではAzureの費用なしに可能)
    1. リソースグループの作成
    2. VNet及び各VM用のサブネットの作成
    3. ストレージアカウントの作成
    4. 各VMログイン用のキーペアの作成

2. VM作成作業 (ここから費用が発生)
    1. VMの作成、パブリックIPの割当
    2. ログイン確認

3. HPC用作業
    1. Infinibandドライバーのインストール、有効化
    2. IP over InfinibandでのVM相互通信テスト
    
## 1-i. リソースグループの作成

最初にAzure CLIにログインします。

```Azure CLI
az login
```

必要に応じて作業対象のサブスクリプションに移動します。

```Azure CLI
# ログインしたアカウントで利用可能なサブスクリプションの表示
az account show --output table

# アクティブなサブスクリプションの設定
az account set --subscription *<サブスクリプション名 or サブスクリプションID>*
```

    

