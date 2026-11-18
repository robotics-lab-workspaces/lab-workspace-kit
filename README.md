# Lab Workspace Kit

Ubuntuで学生ごとのDocker環境を作り、同じ作業名で使い続けるためのキットです。

- セットアップ済みのPCを使う学生は、管理者から自分の作業名と起動コマンドを受け取ります。
- 新しいPCに入れる管理者は、[新規セットアップ](#新規セットアップ)から進みます。すでにDocker Composeで運用している場合は、先に別の保存先と名前空間で復旧を試します。

図とコピーボタンが付いた手順書を開くには、このリポジトリをクローンするか、GitHubの **Code → Download ZIP** から取得して展開します。展開先の [guide.html](guide.html) をブラウザーで開きます。

## 今日使うもの

| やりたいこと | どこで、何をするか |
| --- | --- |
| コンテナの稼働状況を見る | Ubuntuの端末でリポジトリのフォルダーに入り、`./labctl doctor` |
| コンテナの端末だけ閉じる | コンテナ内でプロンプトが出ているときに `exit` |
| 学習やシミュレーターを止める | その処理を起動した端末で `Ctrl+C` |
| コンテナを停止する | 先に作業を保存します。Ubuntu側で稼働状況の `NAMES` 欄を確認し、`sudo docker stop` に自分のコンテナ名を指定します。手順書のコピー欄では名前を入力してから実行します。 |
| 同じ環境に戻る | Ubuntu側で `~/agent-lab/student-lab 作業名 --gpu 0`。作業名とGPU番号は前回と同じものを使います。 |

コンテナを停止すると、内部の学習やTensorBoardも終了します。ファイルや、同じコンテナに追加したパッケージは残ります。

## 前提

- Ubuntu 24.04（x86-64）、Python 3.12以上、Git、[Docker Engine](https://docs.docker.com/engine/install/ubuntu/) とローカルのDockerデーモン。Dockerへのアクセスには通常のユーザー権限か `sudo docker` を使用します。`labctl` 本体は作業ユーザーで起動します。
- GPU版はRTコアを持つNVIDIA GPU、ドライバー、[Isaac Sim 5.1の動作要件](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/requirements.html)、[NVIDIA Container ToolkitのCDI](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html) に対応したDockerが必要です。GUIを使う場合は、Xorgとホストの `xauth` を用意し、Ubuntuデスクトップから最初のコンテナを作ります。標準イメージの `lab` ユーザーはUID 1000です。
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

各行は用途に応じて個別に実行し、`student01` は自分の作業名に置き換えます。GPU番号を省くと通常版、`--gpu 0`・`--gpu 1` は指定したGPU1枚、`--gpu all` はホストの全GPUをコンテナから使えるようにします。分散学習には別の起動設定が必要です。同じ作業名・GPU指定なら同じコンテナに戻ります。`/workspace` はモード間で共通で、ホームと追加パッケージはモードごとに残ります。

共用Ubuntuアカウントでの作業名は利用者同士のアクセス制限を提供しません。GPUの割り当ては予約を行いません。

## 復旧

作業データが既定の `~/agent-lab/students/` に残っている場合、クローン後に次の1コマンドを実行します。

```bash
./labctl repair
```

別の保存場所では `./labctl --root /path/to/agent-lab repair` を使います。既存のGPU環境を作り直し、同意済みの設定が残っていない場合は、条件確認後に `./labctl --accept-isaac-eula repair` を使います。別の名前空間を使用していた環境では同じ `--namespace` を指定します。オプションはサブコマンドより前に指定します。

1. `students/<作業名>/workspace` と `state` / `state-gpu*` を検出します。
2. 同名コンテナがあれば、作業フォルダーとホームの両方が一致することを確認して引き継ぎます。欠けたコンテナだけ作成します。作業フォルダーを付け替える前に対象のコンテナを停止してください。
3. 復旧が成功してから起動ファイルを切り替えます。異なる起動スクリプトがあった場合は最初の1つを `.lab-kit/previous-student-lab` に退避します。「起動ファイル」の行に表示されたパスから再開します。

標準の名前空間では、従来の学生用イメージがローカルに残っていれば再利用します。イメージも失った場合は、公式配布元から組み立てる標準イメージを使います。修復後に再利用したイメージも削除したときは、`--base-image lab-workspace-kit:base-v1` や `--sim-image lab-workspace-kit:sim-v1` で標準を選び直せます。

`workspace` だけがある場合は作業名を表示します。使用するモードを指定して `student-lab` を開くと、そのモードのホームを作成します。移行元は同じ `mujina-student-*` / `mujina-gpu*-*` の名前と `/workspace` / `/home/lab` のバインドを使う学生環境です。

| 保存場所 | 何が残るか |
| --- | --- |
| `students/<作業名>/workspace` | コード・学習ログ・チェックポイント。通常版とGPU版で共通 |
| 同じ作業名の `state` / `state-gpu*` | 各モードのコンテナのホーム。設定・認証など |
| コンテナ本体 | 管理者が追加したOSパッケージなど。本体を失った場合はDockerfileから再作成 |

公開版の普段のシェルは一般ユーザーです。OSパッケージは管理者がDockerfileに追加し、Pythonライブラリは各自の仮想環境で管理します。AIエージェントは各提供元の手順で導入します。独自イメージは `--base-image` / `--sim-image` で指定できます。既定タグのイメージは再利用するため、キットのGit更新とは別に、管理者がイメージのタグと切り替え先を確認します。

## 状態確認とバックアップ

```bash
./labctl doctor
./labctl backup
```

`./labctl doctor` は、停止中も含めたコンテナ一覧とポート、稼働中のコンテナのCPU・メモリ使用量を端末に表示します。Dockerの `STATUS` 列は `Up` が稼働中、`Exited` が停止中です。

作業を保存してコンテナを停止してからバックアップを取ります。対話メニューの4番からも同じ既定先 `~/agent-lab/backups/` に保存できます。表示された `.tar.gz` のパスを控えます。別の保存先には `--output` で書き込み可能な場所を指定してください。同名ファイルは保護されます。

バックアップにはホームや認証ファイルが含まれます。アクセス権を設定できる保存場所に限定して保管します。外部を指すリンクと特殊ファイルは除外名が表示されます。作業フォルダー内のリンクは保持します。システムPythonへのリンクが抜けた仮想環境は依存ファイルから作り直し、MuJoCoの作業用リンクは起動時に生成されます。

別の空の保存先へ復元する例です。表示に従って、控えたバックアップの絶対パスを入力します。

```bash
read -r -p "バックアップの絶対パス: " archive &&
  ./labctl --root "$HOME/recovered-lab" --namespace recovered repair --archive "$archive"
```

GPU版を含む場合は、[NVIDIAの条件](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/common/licenses-isaac-sim.html)を確認して同意したうえで、`repair` の前に `--accept-isaac-eula` を加えます。データ展開後にDocker側で失敗した場合は原因を直し、同じ `--root` と `--namespace` で `--archive` を外して `repair` を再実行します。

「起動ファイル」が表示されたら、復元先で入り直します。次はCPU版の例です。`student01` を復元した作業名に置き換え、GPU版には以前と同じGPU指定を末尾に加えます。コンテナ内で `ls /workspace` を実行してファイルを確認します。

```bash
~/recovered-lab/student-lab student01
```

## 開発者向け

テスト用のコピーには一意な `--root` と `--namespace` を使います。Dockerイメージを取り替えて検証するときは `--base-image` / `--sim-image` でローカルのイメージを選べます。テスト手順は [tests/recovery.sh](tests/recovery.sh) を参照してください。

本リポジトリのライセンスは [MIT](LICENSE) です。外部依存物は [THIRD_PARTY.md](THIRD_PARTY.md) を参照してください。
