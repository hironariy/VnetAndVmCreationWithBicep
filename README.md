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
        - VMイメージ: microsoft-dsvm:ubuntu-hpc:2204:22.04.2024102301
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
    4. 各VMログイン用のキーペアの作成 (未作成の場合)

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

```shell
git clone https://github.com/hironariy/VnetAndVmCreationWithBicep.git
```

### 1-ii. リソースグループの作成

Azure CLIにログインします。

```shell
az login
```

必要に応じて作業対象のサブスクリプションに移動します。

```shell
# ログインしたアカウントで利用可能なサブスクリプションの表示
az account show --output table

# アクティブなサブスクリプションの設定
az account set --subscription <サブスクリプション名 or サブスクリプションID>
```

サブスクリプション内にリソースグループを作成します。

```shell
az group create --name <任意のリソースグループ名> --location <任意のリージョン>
# 代表的なリージョン
# japaneast 東日本
# australiaeast オーストラリア東部
# westeurope ヨーロッパ西部
```
### 1-iii. VNet及び各VM用のサブネット、ストレージアカウントの作成

本リポジトリのコードを使ってVNet、その中のサブネット、ストレージアカウントを作成します。

```shell
az deployment group create -g <リソースグループ名> --template-file VnetAndSaCreation.bicep --name vnetDeployment
```

コマンド実行後にサブネット作成数を入力します。後に作成するVMと同じ数にします。

```shell
#  作成するサブネットの数を入力。最小 1、最大 10
Please provide int value for 'subnetCount' (? for help): <1から10までの任意の整数>
```

VNetとストレージアカウントが作成されたことを確認します。
サブネットはVNetのプロパティのため、リソースが表示されるここでは表示されません。

```shell
az resource list -g <リソースグループ名> -o table

#表示例
Name                ResourceGroup    Location       Type                               Status
------------------  ---------------  -------------  ---------------------------------  --------
storeexample        exampleRg    region-name  Microsoft.Storage/storageAccounts
BicepVNet           exampleRg    region-name  Microsoft.Network/virtualNetworks
```

作成したストレージアカウントとBlob Storageのコンテナの名前を確認します。

```shell
az deployment group show --resource-group <リソースグループ名> --name vnetDeployment --query properties.outputs
```
出力例
```json
{
  "blobContainerName": {
    "type": "String",
    "value": "<BlobStorageコンテナ名>"
  },
  "blobServiceName": {
    "type": "String",
    "value": "<BlobStorageサービス名>"
  },
  "storageAccountName": {
    "type": "String",
    "value": "<ストレージアカウント名>"
  }
}

```

あとでBlobfuse2でVMからBlob Storageをマウントするときに利用するので、Blob Storageの接続文字列を出力し、メモしておきます。

```shell
az storage account show-connection-string -g competitionRg -n <ストレージアカウント名>
#出力例
{
  "connectionString": "DefaultEndpointsProtocol=https;EndpointSuffix=core.windows.net;AccountName=xxxxxxxxxx;AccountKey=Jixxxxxxxxxxxxxxx;BlobEndpoint=https://xxxxxxxxxx.blob.core.windows.net/;FileEndpoint=https://xxxxxxxxxx.file.core.windows.net/;QueueEndpoint=https://xxxxxxxxxx.queue.core.windows.net/;TableEndpoint=https://xxxxxxxxxx.table.core.windows.net/"
}
```

### 1-iv.　各VMログイン用のキーペアの作成 (未作成の場合)

VMの管理者アカウント用のsshキーペアを作成していない場合は作成します。

```shell
ssh-keygen -t rsa -b 4096  
```

## VM作成作業

### 2-i. VMの作成、パブリックIPの割当、データディスクのアタッチ

VM作成用のBicepを利用してVMやディスク、PublicIPを作成します。

```shell
az deployment group create -g <リソースグループ名> --template-file VmCreation.bicep --name vmDeployment   
```

```shell
Please provide string value for 'vmType' (? for help): 
 [1] General
 [2] HPC
 [3] HPC2
Please enter a choice [Default choice(1)]:  <作成するVM Type番号>
Please provide int value for 'vmCount' (? for help): <サブネットと同じ整数>
Please provide string value for 'adminUsername' (? for help): <管理者アカウント名>
Please provide string value for 'authenticationType' (? for help): 
 [1] sshPublicKey
 [2] password
Please enter a choice [Default choice(1)]: 1 #本サンプルでは公開鍵を利用
Please provide securestring value for 'adminPasswordOrKey' (? for help): <登録する公開鍵の文字列>
```

作成されたリソースを確認します。

```shell
az resource list -g <リソースグループ名> -o table
```
### 2-ii. ログイン確認

先ほど利用したデプロイメントからoutputsを確認します。

```shell
az deployment group show --resource-group <リソースグループ名> --name vmDeployment --query properties.outputs
```

出力例

```json
{
  "adminUsername": {
    "type": "String",
    "value": "<管理者アカウント名>"
  },
  "hostname": {
    "type": "Array",
    "value": [
      "<vm1名>.<リージョン名>.cloudapp.azure.com",
      "<vm2名>.<リージョン名>.australiaeast.cloudapp.azure.com"
    ]
  },
  "sshCommand": {
    "type": "Array",
    "value": [
      "<VM1接続用sshコマンド>",
      "<VM2接続用sshコマンド>"
    ]
  }
}
```

outputsに出力されるssh接続コマンドを使って各VMに接続します。

```shell
#出力されたコマンドに-iオプションを付与し秘密鍵を指定します。
ssh <管理者アカウント名>@<VM名> -i <ssh接続用秘密鍵>
```

## 通常のVMとしての作業

### 3-i. データディスクのフォーマットとマウント

sshでVMにログインし、ディスクがアタッチされていることを確認します。
下記の例だとsdbという名前で接続されています。

```shell
rootAccountName@vmName:~$ lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0   30G  0 disk 
├─sda1    8:1    0   29G  0 part /
├─sda14   8:14   0    4M  0 part 
├─sda15   8:15   0  106M  0 part /boot/efi
└─sda16 259:0    0  913M  0 part /boot
sdb       8:16   0    1T  0 disk 
sr0      11:0    1  628K  0 rom 
```

今回はパーティション分割せずにディスクにファイルシステムを作成します。

```shell
rootAccountName@vmName:~$ sudo mkfs.ext4 /dev/sdb
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 268435456 4k blocks and 67108864 inodes
Filesystem UUID: 51a34127-b69b-4c53-a9c7-c0431b90367a
Superblock backups stored on blocks: 
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208, 
        4096000, 7962624, 11239424, 20480000, 23887872, 71663616, 78675968, 
        102400000, 214990848

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (262144 blocks): done
Writing superblocks and filesystem accounting information: done  
```

データディスクをマウントします。

```shell
rootAccountName@vmName:~$ sudo mkdir /mnt/datadrive
rootAccountName@vmName:~$ sudo mount /dev/sdb /mnt/datadrive
```

マウントされたことを確認します。

```shell
rootAccountName@vmName:~$ lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0   30G  0 disk 
├─sda1    8:1    0   29G  0 part /
├─sda14   8:14   0    4M  0 part 
├─sda15   8:15   0  106M  0 part /boot/efi
└─sda16 259:0    0  913M  0 part /boot
sdb       8:16   0    1T  0 disk /mnt/datadrive
sr0      11:0    1  628K  0 rom  
```

再起動後にドライブがマウントされるようにそのドライブを/etc/fstabファイルに追加します。事前作業としてblkidでディスクのUUIDを取得します。

```shell
sudo -i blkid
```

出力例

```shell
/dev/sda16: LABEL="BOOT" UUID="a1f941e3-782c-4e21-ba31-97e0f6fcb50c" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="fa54c6a9-6293-42d8-8453-11079fe5eec1"
/dev/sda15: LABEL_FATBOOT="UEFI" LABEL="UEFI" UUID="C30D-3EEB" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="7ccbd9ff-7523-46a4-b138-68a3c6efcb31"
/dev/sda1: LABEL="cloudimg-rootfs" UUID="61bdcf85-9086-4bfd-9faf-225cb7bf06be" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="8be7931c-8315-4344-95d4-bcbd379998fb"
/dev/sdb: UUID="51a34127-b69b-4c53-a9c7-c0431b90367a" BLOCK_SIZE="4096" TYPE="ext4"
/dev/sda14: PARTUUID="be23fb2f-458b-4d03-aef4-fb30182ba8ea"
```

テキストエディタで/etc/fstabファイルを開きます。

```shell
sudo vim /etc/fstab
```

次のような行をファイルに追記します。UUIDは環境に合わせて変更します。

```shell
UUID=51a34127-b69b-4c53-a9c7-c0431b90367a   /mnt/datadrive  ext4    defaults,nofail   1  2
```





    

