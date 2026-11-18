"""Render a private, single-file snapshot of Docker workspace status."""

from datetime import datetime
from html import escape
from pathlib import Path
import re
import shlex


STATES = {
    "running": ("稼働中", "running"),
    "exited": ("停止中", "stopped"),
    "created": ("起動前", "stopped"),
    "paused": ("一時停止", "waiting"),
    "restarting": ("再起動中", "waiting"),
    "dead": ("異常終了", "waiting"),
    "missing": ("コンテナ未作成", "stopped"),
}


def copy_line(action, command):
    return (
        f'<div class="command"><span>{escape(action)}</span><code>{escape(command)}</code>'
        '<button type="button">コピー</button></div>'
    )


def render(root: Path, namespace, containers, usage, saved_modes, stats_ok, refresh):
    """Return the HTML for real Docker data. All dynamic values are escaped."""
    pattern = re.compile(rf"{re.escape(namespace)}-(student|gpu(?:all|[0-9]+))-([a-z0-9][a-z0-9-]{{0,23}})")
    names = {row["Names"] for row in containers}
    data_only = [
        {"Names": name, "State": "missing", "Status": "データを検出"}
        for name in saved_modes if name not in names
    ]
    rows = sorted(
        [*containers, *data_only],
        key=lambda row: (row["State"] != "running", row["Names"]),
    )
    running = sum(row["State"] == "running" for row in containers)
    cards = []
    for row in rows:
        name = row["Names"]
        state = row["State"]
        label, css = STATES.get(state, (state, "waiting"))
        match = pattern.fullmatch(name)
        gpu = match[1][3:] if match and match[1].startswith("gpu") else ""
        allocation = {"": "通常版", "all": "全GPU"}.get(gpu, f"GPU {gpu}")
        metrics = usage.get(name, {})
        port = re.search(r"127\.0\.0\.1:([0-9]+)->6006/tcp", row.get("Ports") or "")
        # Docker is queried read-only. Controls copy commands, they never run them.
        commands = ""
        if match:
            launch = [str(root / "student-lab"), match[2]]
            if gpu:
                launch.extend(("--gpu", gpu))
            commands = copy_line("Ubuntu側で開く", shlex.join(launch))
            if state == "running":
                commands += copy_line("Ubuntu側で停止", shlex.join(["sudo", "docker", "stop", name]))
            commands = f'<details><summary>この環境の操作コマンド</summary>{commands}</details>'
        board = "—"
        if port and state == "running":
            address = f"http://127.0.0.1:{port[1]}"
            board = f'<a href="{address}">{escape(address)}</a>'
        cards.append(
            f'<article><header><h2>{escape(name)}</h2><span class="pill {css}">{escape(label)}</span></header>'
            f'<p class="sub">起動モード {escape(allocation if match else "共用・その他")} · Docker表示 {escape(row.get("Status", ""))}</p>'
            f'<dl><div><dt>CPU使用率</dt><dd>{escape(metrics.get("CPUPerc", "—"))}</dd></div>'
            f'<div><dt>RAM使用量 / 上限</dt><dd>{escape(metrics.get("MemUsage", "—"))}</dd></div>'
            f'<div><dt>TensorBoardの割り当て先</dt><dd>{board}</dd></div></dl>{commands}</article>'
        )
    content = "\n".join(cards) or "<p>この名前空間に作業環境がありません。</p>"
    warning = "<p>CPU・RAMの使用量を取得できませんでした。起動状態は一覧に表示しています。</p>" if not stats_ok else ""
    data = len(data_only)
    timestamp = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
    return f"""<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>コンテナの稼働状況</title>
<style>
:root{{color-scheme:light;font-family:system-ui,-apple-system,"Hiragino Sans",sans-serif;color:#172d35;background:#f5f8f8}}
*{{box-sizing:border-box}} body{{margin:0;line-height:1.65}} main{{width:min(68rem,calc(100% - 2rem));margin:2rem auto}}
h1,h2,p,dl{{margin:0}} h1{{font-size:clamp(1.6rem,5vw,2.5rem);line-height:1.25}} h2{{font-size:1.05rem;overflow-wrap:anywhere}}
.sub,dt{{color:#49626b}} .facts{{display:flex;gap:.45rem 1rem;flex-wrap:wrap;margin:1rem 0}}
.facts b{{color:#075b50}} section{{display:grid;gap:.75rem;margin-top:1.15rem}}
article,.controls{{background:#fff;border:1px solid #cddcde;border-radius:.65rem;padding:1rem}}
article header{{display:flex;align-items:start;justify-content:space-between;gap:.5rem;flex-wrap:wrap}}
.pill{{border-radius:1rem;padding:.15rem .55rem;font-weight:700;background:#e8eef0;color:#37535d;white-space:nowrap}}
.running{{color:#075b50;background:#e1f2eb}} .waiting{{color:#8b3f14;background:#f9eee0}}
dl{{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));margin-top:.75rem;gap:.45rem}} dt{{font-size:.83rem}} dd{{margin:0;overflow-wrap:anywhere}}
details{{margin-top:.7rem}} summary{{cursor:pointer;font-weight:600}} button{{font:inherit;background:#e6f2ef;color:#124e45;border:1px solid #a9c6c3;border-radius:.35rem;padding:.22rem .6rem;cursor:pointer}}
button:focus-visible,a:focus-visible,summary:focus-visible{{outline:3px solid #ae671d;outline-offset:2px}}
.command{{margin:.45rem 0;display:flex;gap:.5rem;align-items:center;flex-wrap:wrap}} .command span{{font-size:.85rem;color:#49626b}} .command code{{font-size:.9rem;overflow-wrap:anywhere}} a{{color:#0a6257}}
@media(max-width:32rem){{dl{{grid-template-columns:1fr 1fr}} .command code{{flex-basis:100%}}}}
</style></head><body><main>
<h1>コンテナの稼働状況</h1>
<p class="sub">取得時刻 {escape(timestamp)} · このファイルはこのPCで確認するためのものです。</p>
<div class="facts"><span><b>{running}</b> 稼働中</span><span><b>{len(containers)-running}</b> 停止・起動前など</span><span><b>{data}</b> コンテナ未作成</span></div>
<div class="controls">
  <p>自分の作業名の行を探してください。端末を閉じるだけなら、コンテナ内で <code>exit</code>。コンテナを停止すると、その中の学習や実行中の処理も終了します。</p>
  <p class="sub">TensorBoardのURLは、そのコンテナでTensorBoardを起動すると開けます。</p>
  <p class="sub">最新の情報を見るにはUbuntu側の端末で、次のコマンドを実行してからページを再読み込みします。</p>
  {copy_line("一覧を更新", refresh)}
</div>
{warning}
<section aria-label="コンテナ一覧">{content}</section>
<div id="copy-status" role="status" aria-live="polite"></div>
</main><script>
document.addEventListener('click', async (event) => {{
  const button = event.target.closest('.command button');
  if (!button) return;
  const code = button.parentElement.querySelector('code');
  try {{
    await navigator.clipboard.writeText(code.textContent);
    button.textContent = 'コピー済み';
  }} catch {{
    const range = document.createRange();
    range.selectNodeContents(code);
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    button.textContent = '選択済み';
    document.getElementById('copy-status').textContent = '選択した範囲を Ctrl または Command + C でコピーしてください。';
  }}
}});
</script></body></html>
"""
