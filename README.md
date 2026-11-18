# Lab Workspace Kit

Ubuntuで学生ごとのDocker環境を作り、同じ作業名で使い続けるためのキットです。共通の起動ファイルやコンテナを失ったときは、残っている作業データを見つけて接続し直します。[図入りの使い方](guide.html)

## 今日使うもの

| やりたいこと | どこで、何をするか |
| --- | --- |
| 起動中の環境を見る | Ubuntuの端末でリポジトリのフォルダーに入り、`./labctl doctor --html` |
| コンテナの端末だけ閉じる | コンテナ内でプロンプトが出ているときに `exit` |
| 学習やシミュレーターを止める | その処理を起動した端末で `Ctrl+C` |
| コンテナを停止する | Ubuntu側で `sudo docker stop mujina-gpu0-student01`。自分のコンテナ名を指定 |
| 同じ環境に戻る | Ubuntu側で `~/agent-lab/student-lab student01 --gpu 0` |

コンテナを停止すると、内部の学習やTensorBoardも終了します。ファイルや、同じコンテナに追加したパッケージは残ります。

## 前提

- Ubuntu 24.04（x86-64）、Python 3.12以上、Git、[Docker Engine](https://docs.docker.com/engine/install/ubuntu/) とローカルのDockerデーモン。Dockerへのアクセスには通常のユーザー権限か `sudo docker` を使用します。`labctl` 本体は作業ユーザーで起動します。
- GPU版はCUDA対応のNVIDIA GPU、ドライバー、[NVIDIA Container ToolkitのCDI](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html) と `nvidia.com/gpu=0` などのデバイス指定に対応するDockerが必要です。GUIはログイン済みのUbuntu Xorgとホストの `xauth` を使います。
- セットアップはインターネットから依存物を取得します。既存のプロキシが必要な場合は、実行前にシェルの `http_proxy` と `https_proxy` を設定します。GPUイメージの初回ビルドには十分な空きディスクと時間が必要です。

Docker Hubに届かないネットワークでは、用意済みのUbuntu 24.04ベースイメージを環境変数 `LAB_KIT_UBUNTU_BASE` で指定できます。例 `LAB_KIT_UBUNTU_BASE=local-ubuntu:24.04 ./labctl setup`。

## 新規セットアップ

```bash
git clone https://github.com/robotics-lab-workspaces/lab-workspace-kit.git
cd lab-workspace-kit
./labctl
```

メニューで「セットアップ」を選びます。通常版は `./labctl setup` でも作成できます。GPU版は、[NVIDIAの条件](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/common/licenses-isaac-sim.html) を読み、同意する場合に `./labctl --accept-isaac-eula setup --gpu` を実行します。Ubuntu本体のパッケージ・ドライバー・Dockerデーモン設定は前提条件として用意します。

```bash
~/agent-lab/student-lab student01
~/agent-lab/student-lab student01 --gpu 0
```

各行は用途に応じて個別に実行します。GPU番号を省くと通常版です。毎回同じ作業名とGPU番号を使うと同じコンテナに戻ります。`exit` はターミナルだけ閉じます。停止後に開き直しても、残っているコンテナの追加パッケージや設定は引き継がれます。

## 復旧

作業データが既定の `~/agent-lab/students/` に残っている場合、クローン後に次の1コマンドを実行します。

```bash
./labctl repair
```

別の保存場所では `./labctl --root /path/to/agent-lab repair` を使います。既存のGPU環境を作り直し、同意済みの設定が残っていない場合は、条件確認後に `./labctl --accept-isaac-eula repair` を使います。別の名前空間を使用していた環境では同じ `--namespace` を指定します。オプションはサブコマンドより前に指定します。

1. `students/<作業名>/workspace` と `state` / `state-gpu*` を検出します。
2. 壊れた起動ファイルを復元します。異なる起動スクリプトがあった場合は最初の1つを `.lab-kit/previous-student-lab` に退避します。
3. 同名コンテナがあれば、作業フォルダーとホームの両方が一致することを確認して引き継ぎます。欠けたコンテナだけ、必要なイメージを準備して作成します。再開はいつもの `student-lab` で行います。

標準の名前空間では、従来の学生用イメージがローカルに残っていれば再利用します。イメージも失った場合は、公式配布元から組み立てる標準イメージを使います。修復後に再利用したイメージも削除したときは、`--base-image lab-workspace-kit:base-v1` や `--sim-image lab-workspace-kit:sim-v1` で標準を選び直せます。

`workspace` だけがある場合は作業名を表示します。使用するモードを指定して `student-lab` を開くと、そのモードのホームを作成します。移行元は同じ `mujina-student-*` / `mujina-gpu*-*` の名前と `/workspace` / `/home/lab` のバインドを使う学生環境です。

| 保存場所 | 何が残るか |
| --- | --- |
| `students/<作業名>/workspace` | コード・学習ログ・チェックポイント。通常版とGPU版で共通 |
| 同じ作業名の `state` / `state-gpu*` | 各モードのコンテナのホーム。設定・認証など |
| コンテナ本体 | 手動で `apt` などで追加したもの。コンテナ本体を失った場合は、Dockerfileや作業メモをもとに再インストール |

以前から動いている環境のAIコマンドは、そのコンテナを引き継ぐことで残ります。新しいイメージの標準はUbuntuツールと、GPU版ではMuJinaのシミュレーションです。各AIエージェントは選択した提供元の手順で導入します。追加ソフトウェアも一緒に復旧したい場合は、管理するDockerfileでイメージを作成して `--base-image` / `--sim-image` を指定できます。指定したイメージはローカルに用意します。

## 状態確認とバックアップ

```bash
./labctl doctor
./labctl backup --output /mnt/backup/lab-students.tar.gz
```

ブラウザーで稼働状況を見たい場合は、Ubuntuの端末で次を実行します。

```bash
./labctl doctor --html && xdg-open "$HOME/.cache/lab-workspace-kit/status.html"
```

HTMLには取得時刻、起動状態、使用中のCPU・RAM、GPU指定、TensorBoardの割り当て先が表示されます。状況を更新するときは、そのページの生成コマンドをもう一度実行します。HTMLはこのPCのユーザー専用キャッシュに保存されます。

バックアップには学生のホームや認証ファイルが含まれる場合があります。ファイルは権限 `0600` で作成し、作業を保存・停止した状態で外部ストレージなどへ退避します。学習中のファイルの整合性が必要な場合は停止後に取ります。配布先やGitには置きません。

空の保存先へ復元する例です。同じマシンに既存環境がある場合は名前空間を分けます。

```bash
./labctl --root "$HOME/recovered-lab" --namespace recovered repair --archive /mnt/backup/lab-students.tar.gz
```

## 開発者向け

テスト用のコピーには一意な `--root` と `--namespace` を使います。Dockerイメージを取り替えて検証するときは `--base-image` / `--sim-image` でローカルのイメージを選べます。テスト手順は [tests/recovery.sh](tests/recovery.sh) を参照してください。

本リポジトリのライセンスは [MIT](LICENSE) です。外部依存物は [THIRD_PARTY.md](THIRD_PARTY.md) を参照してください。
