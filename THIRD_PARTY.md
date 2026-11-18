# 外部ソフトウェアと素材

このリポジトリのコードと手順書は [MIT License](LICENSE) です。ビルド時に取得する各依存物にはそれぞれの条件が適用されます。取得したコードのライセンスファイルはビルド内にも残ります。

| 依存物 | 取得元と条件 |
| --- | --- |
| UbuntuとROS 2 Jazzy | [Ubuntu公式イメージ](https://hub.docker.com/_/ubuntu)、[ROS 2公式APT設定](https://github.com/ros-infrastructure/ros-apt-source)、各パッケージのライセンス |
| MuJina ROS | [RTの公式リポジトリとライセンス](https://github.com/rt-net/mujina_ros/tree/38ff97f12d0ef424dd7fc840d3ce7a1ebad2a49d)。モデルと素材の由来は同リポジトリのREADMEを参照 |
| MuJina Isaac Lab | [RTの公式リポジトリとライセンス](https://github.com/rt-net/mujina_isaac_lab/tree/98bf94e75ecf00c5f9d44d122fdc0f949d6b89dd) |
| Isaac Lab 2.3 | [固定コミットのライセンス](https://github.com/isaac-sim/IsaacLab/tree/3c6e67bb5c7ada942a6d1884ab69338f57596f77)。BSD-3-Clauseを中心に、コンポーネント別の条件があります |
| Isaac Sim 5.1 | [NVIDIA公式ライセンスと追加ソフトウェア・素材の条件](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/common/licenses-isaac-sim.html)。公開ソースと、公式Python配布物に含まれる追加依存物には異なる条件が適用されます |
| PyTorch・MuJoCo・ONNX Runtime・TensorBoard | それぞれの公式Python配布とパッケージ内のライセンスを参照 |

GitHubで配布する対象はこのキットのソースです。Isaac Simのパッケージ、ビルド済みイメージ、3D素材、チェックポイント、利用者データはリポジトリに含めません。GPU版を作る前に、利用者がNVIDIAの条件を読み、同意を明示します。MuJinaとNVIDIAの名称は対象ソフトウェアの識別に使用しています。

AIエージェントを追加する場合は、各提供元の配布手順と利用条件に従います。追加したパッケージや認証の扱いは [README](README.md) を参照してください。
