#!/bin/bash
set -euo pipefail

replay_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
python=/opt/mujina-isaac/bin/python
kit_home="$HOME/.local/share/mujina-isaac"
project=/opt/mujina-source/mujina_isaac_lab
script=("$replay_dir/play-exported.py")

if [[ $# -gt 0 && $1 != -* ]]; then
  if [[ ! -f $1 ]]; then
    printf 'チェックポイントが見つかりません: %s\n' "$1" >&2
    exit 2
  fi
  checkpoint=$(realpath -- "$1")
  shift
  project=/workspace/mujina_isaac_lab
  script=(scripts/rsl_rl/play.py --task Isaac-Velocity-Rough-Mujina-Play-v0
    --num_envs 1 --real-time --checkpoint "$checkpoint")
else
  for argument in "$@"; do
    if [[ $argument == *.pt ]]; then
      printf '自分のチェックポイントは最初の引数に指定してください。例: bash play-mujina.sh model.pt --headless\n' >&2
      exit 2
    fi
  done
fi

mkdir -p -- "$kit_home"
cd -- "$project"
export PYTHONPATH="$project/source/mujina_isaac_lab${PYTHONPATH:+:$PYTHONPATH}"
kit_args="--kit_args=--portable-root $kit_home"
for option in "$@"; do
  if [[ $option == --headless || $option == --help || $option == -h ]]; then
    exec "$python" "${script[@]}" "$kit_args" "$@"
  fi
done
export __NV_PRIME_RENDER_OFFLOAD=1
exec mujina-display "$python" "${script[@]}" "$kit_args" "$@"
