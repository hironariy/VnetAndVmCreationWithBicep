# Bicepを使ったAzure Virtual NetworkとVirtual Machineの作成手順例

本リポジトリのコードを使って、Azureのオーストラリア東部リージョンにVNetを1つ、そのなかにサブネットを10こ作成し、各サブネットにVMを1台ずつ、それぞれにPublic IPを付与した状態で作成する手順を示します。

## 前提条件、利用ツール

本リポジトリで示す手順はサブスクリプションの所有者ロールを割り当てられたアカウントで実行することを前提としています。

ツールは以下のものを利用します。
- [Visual Studio Code](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/install#azure-cli)
- [Azure CLI](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/install#azure-cli)
- [Bicep CLI](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/bicep/install#azure-cli)
