#!/bin/bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
temporary=$(mktemp -d)
name="kitc-$(date +%s)-$$"
student=student01
root="$temporary/lab"
restored="$temporary/restored"
legacy="$temporary/legacy"
docker=(docker)
if ! docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
  docker=(sudo -n docker)
  "${docker[@]}" version --format '{{.Server.Version}}' >/dev/null
fi
cleanup() {
  for container in "$name-student-$student" "$name-gpu0-$student" "${name}b-student-$student" "${name}c-student-$student"; do
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
mkdir -p "$root/students/$student/state/private" "$root/students/$student/workspace/.venv/bin"
chmod 700 "$root/students/$student/state/private"
ln -s /usr/bin/python3 "$root/students/$student/workspace/.venv/bin/python3"
mkdir -p "$root/students/$student/state/.local/share/mujina-ros/src"
ln -s /workspace/mujina_ros "$root/students/$student/state/.local/share/mujina-ros/src/mujina_ros"
mkfifo "$root/students/$student/workspace/test-fifo"
printf 'private\n' > "$root/students/$student/state/private/example.txt"
ln "$root/students/$student/workspace/code.txt" "$root/students/$student/workspace/code-hardlink"
printf '4\n' | script -q -e -c "./labctl --root '$root'" /dev/null
find "$root/backups" -name 'students-*.tar.gz' -type f | grep -q 'tar.gz$'
"${lab[@]}" backup --output "$temporary/students.tar.gz"
test "$(stat -c '%a' "$temporary/students.tar.gz")" = 600
cp "$temporary/students.tar.gz" "$temporary/expected.tar.gz"
if "${lab[@]}" backup --output "$temporary/students.tar.gz"; then
  printf 'ERROR: backup overwrote an existing file\n' >&2
  exit 1
fi
cmp "$temporary/students.tar.gz" "$temporary/expected.tar.gz"
tar -czf "$temporary/legacy.tar.gz" -C "$root" students
restore=(./labctl --root "$restored" --namespace "${name}b")
if [[ -n ${LAB_TEST_BASE_IMAGE:-} ]]; then
  restore+=(--base-image "$LAB_TEST_BASE_IMAGE")
fi
mkdir -m 700 "$root/students/$student/state-gpu0"
tar -czf "$temporary/gpu.tar.gz" -C "$root" students
if "${restore[@]}" repair --archive "$temporary/gpu.tar.gz" >"$temporary/gpu-error" 2>&1; then
  printf 'ERROR: GPU restore unexpectedly succeeded without consent\n' >&2
  exit 1
fi
grep -q -- '--accept-isaac-eula' "$temporary/gpu-error"
test ! -e "$restored/students"
test ! -e "$restored/student-lab"
rmdir "$root/students/$student/state-gpu0"
"${restore[@]}" repair --archive "$temporary/students.tar.gz"
legacy_restore=(./labctl --root "$legacy" --namespace "${name}c")
if [[ -n ${LAB_TEST_BASE_IMAGE:-} ]]; then
  legacy_restore+=(--base-image "$LAB_TEST_BASE_IMAGE")
fi
"${legacy_restore[@]}" repair --archive "$temporary/legacy.tar.gz"
test ! -L "$legacy/students/$student/workspace/.venv/bin/python3"
test ! -L "$legacy/students/$student/state/.local/share/mujina-ros/src/mujina_ros"
"$legacy/student-lab" "$student" <<'BASH'
test "$(cat /workspace/code.txt)" = source
BASH
cmp "$root/students/$student/workspace/code.txt" "$restored/students/$student/workspace/code.txt"
cmp "$root/students/$student/state/.config/example.txt" "$restored/students/$student/state/.config/example.txt"
test -L "$restored/students/$student/workspace/code-link"
test ! -L "$restored/students/$student/workspace/.venv/bin/python3"
test ! -L "$restored/students/$student/state/.local/share/mujina-ros/src/mujina_ros"
test ! -e "$restored/students/$student/workspace/test-fifo"
test "$(stat -c '%a' "$restored/students/$student/state/private")" = 700
test "$(stat -c '%a' "$restored/students/$student/state")" = 700
"$restored/student-lab" "$student" <<'BASH'
set -eu
test "$(cat /workspace/code.txt)" = source
test "$(cat /workspace/code-hardlink)" = source
test "$(cat /workspace/code-link)" = source
test "$(cat /workspace/logs/example.txt)" = 'learning log'
test "$(cat "$HOME/.config/example.txt")" = settings
test "$(cat "$HOME/private/example.txt")" = private
BASH
if "${restore[@]}" repair --archive "$temporary/students.tar.gz"; then
  printf 'ERROR: restored over existing data\n' >&2
  exit 1
fi
printf 'PASS isolated backup restored, reopened and read files inside the new container\n'

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
