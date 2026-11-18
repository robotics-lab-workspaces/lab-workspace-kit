#!/bin/bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
temporary=$(mktemp -d)
name="kitc-$(date +%s)-$$"
student=student01
root="$temporary/lab"
restored="$temporary/restored"
docker=(docker)
if ! docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
  docker=(sudo -n docker)
  "${docker[@]}" version --format '{{.Server.Version}}' >/dev/null
fi
cleanup() {
  for container in "$name-student-$student" "$name-gpu0-$student" "${name}b-student-$student"; do
    if "${docker[@]}" container inspect "$container" >/dev/null 2>&1; then
      "${docker[@]}" rm -f "$container" >/dev/null
    fi
  done
  rm -rf -- "$temporary"
}
trap cleanup EXIT
container="$name-student-$student"
lab=(./labctl --root "$root" --namespace "$name")
if [[ -n ${LAB_TEST_BASE_IMAGE:-} ]]; then
  lab+=(--base-image "$LAB_TEST_BASE_IMAGE")
fi

"${lab[@]}" setup
"$root/student-lab" "$student" <<'BASH'
set -eu
mkdir -p /workspace/logs "$HOME/.config"
printf 'source\n' >/workspace/code.txt
printf 'learning log\n' >/workspace/logs/example.txt
printf 'settings\n' >"$HOME/.config/example.txt"
ln -s code.txt /workspace/code-link
printf 'container layer\n' >/tmp/runtime-marker
BASH
id=$("${docker[@]}" inspect --format '{{.Id}}' "$container")
"${docker[@]}" stop "$container" >/dev/null
"$root/student-lab" "$student" <<'BASH'
set -eu
test "$(cat /tmp/runtime-marker)" = 'container layer'
BASH
test "$("${docker[@]}" inspect --format '{{.Id}}' "$container")" = "$id"
printf 'PASS same container and writable layer after restart\n'

if ./labctl --root "$temporary/elsewhere" --namespace "$name" open "$student"; then
  printf 'ERROR: accepted a container attached to another root\n' >&2
  exit 1
fi

"${docker[@]}" stop "$container" >/dev/null
"${docker[@]}" rm "$container" >/dev/null
rm -- "$root/student-lab" "$root/.lab-kit/current/kit/AGENTS.md"
"${lab[@]}" repair
test "$("${docker[@]}" inspect --format '{{.Id}}' "$container")" != "$id"
test -s "$root/.lab-kit/current/kit/AGENTS.md"
"$root/student-lab" "$student" <<'BASH'
set -eu
test "$(cat /workspace/code.txt)" = source
test "$(cat /workspace/logs/example.txt)" = 'learning log'
test "$(cat "$HOME/.config/example.txt")" = settings
test -L /workspace/code-link
BASH
printf 'PASS missing runtime and container recovered with original work and settings\n'

"${docker[@]}" stop "$container" >/dev/null
"${lab[@]}" backup --output "$temporary/students.tar.gz"
test "$(stat -c '%a' "$temporary/students.tar.gz")" = 600
restore=(./labctl --root "$restored" --namespace "${name}b")
if [[ -n ${LAB_TEST_BASE_IMAGE:-} ]]; then
  restore+=(--base-image "$LAB_TEST_BASE_IMAGE")
fi
"${restore[@]}" repair --archive "$temporary/students.tar.gz"
cmp "$root/students/$student/workspace/code.txt" "$restored/students/$student/workspace/code.txt"
cmp "$root/students/$student/state/.config/example.txt" "$restored/students/$student/state/.config/example.txt"
test -L "$restored/students/$student/workspace/code-link"
if "${restore[@]}" repair --archive "$temporary/students.tar.gz"; then
  printf 'ERROR: restored over existing data\n' >&2
  exit 1
fi
printf 'PASS isolated backup restored without overwriting existing data\n'

if [[ ${LAB_TEST_GPU:-0} == 1 ]]; then
  # Run this only after reading and agreeing to the Isaac Sim license.
  gpu=("${lab[@]}" --accept-isaac-eula)
  if [[ -n ${LAB_TEST_SIM_IMAGE:-} ]]; then
    gpu+=(--sim-image "$LAB_TEST_SIM_IMAGE")
  fi
  "${gpu[@]}" setup --gpu
  "$root/student-lab" "$student" --gpu 0 <<'BASH'
set -eu
nvidia-smi -L
test -s /workspace/mujina_isaac_lab/scripts/rsl_rl/play.py
test -s /workspace/policies/play-mujina.sh
printf 'gpu settings\n' >"$HOME/gpu-settings"
BASH
  "${docker[@]}" stop "$name-gpu0-$student" >/dev/null
  "${docker[@]}" rm "$name-gpu0-$student" >/dev/null
  "${gpu[@]}" repair
  "$root/student-lab" "$student" --gpu 0 <<'BASH'
set -eu
test "$(cat "$HOME/gpu-settings")" = 'gpu settings'
test "$(cat /workspace/code.txt)" = source
mujina-isaac preview --headless --steps 3
BASH
  "${docker[@]}" port "$name-gpu0-$student" 6006/tcp | grep -q '^127\.0\.0\.1:'
  printf 'PASS GPU environment restored and Isaac Lab preview launched\n'
fi
