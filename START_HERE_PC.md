# EdgeGuardian — START HERE (your Windows PC, CPU test rig)

Goal of this package: prove the whole system works on your own PC **before** touching the GB10, so no lab
GPU time or storage is spent on debugging. Same code as the GB10 package; only the profile differs.

## 1. One-time setup (≈15 min, ≈3 GB downloads, internet needed only now)
1. Install **Python 3.11** (python.org, tick *Add to PATH*) or use your Anaconda prompt.
2. Install **Ollama** from https://ollama.com/download, then in any terminal: `ollama pull qwen3.5:4b`
3. Install **ffmpeg**: `winget install Gyan.FFmpeg` (then open a *new* PowerShell).
4. Unzip this package, open PowerShell **in the unzipped `edge-guardian` folder** and run:
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\scripts\setup_windows.ps1 -Compute CPU
   ```
   (NVIDIA card with ≥ 8 GB? use `-Compute CUDA` and `ollama pull qwen3.5:9b`.)
   The script installs everything, downloads the models and the public example recordings, runs the tests,
   builds **`EdgeGuardian.exe`** and puts a **EdgeGuardian** shortcut on your Desktop.

## 2. Run
* Double-click **EdgeGuardian.exe** (or the Desktop shortcut). A native window opens — no browser, no URL.
  The app starts Ollama itself if it is not running. Close the window to quit.
* Prefer to see logs? `.\scripts\run_windows.ps1` — same app in a console; `-Web` gives the browser UI at
  http://127.0.0.1:8600 instead.
* Rehearsal without models (instant): `EdgeGuardian.exe fixture`.

## 3. Demo flow (what to show)
1. Drop **any** video / audio / image into the left panel (or click *Example recordings*).
   Optional: one line of context, e.g. "rear-seat camera of a robotaxi" — the scene itself is inferred.
2. Press **Investigate**. Watch, in order: scene understanding (environment + who is present + a second
   opinion on every weapon-like box) → structured events → evidence frames (red boxes = weapon candidates with
   confidence and size) → the live reasoning trace (thought → action → observation, model thinking expandable)
   → the question to the person (answer with a chip or stay silent) → simulated dispatch cards → the
   **CLEAR / WATCH / ALERT** verdict with a written closing report → telemetry footer (tokens, frames skipped,
   cloud-equivalent cost vs local energy).
3. Switch the media tab to **Evidence replay** to play the annotated window (boxes + skeletons).
4. Ask a follow-up in the verdict card ("why not call 911?", "what did the person say?").
5. Turn Wi-Fi off and run again: the header pill says *internet: off — still fully operational*.

Timing on a CPU-only PC: 1–3 min per 10–20 s clip (`pc_cpu` calls the model only for VLM verification, the
critic and the closing report). The GB10 does the same in ~10–20 s with the full LLM planner.

## 3b. If something looks wrong
`.\.venv-win\Scripts\python.exe scripts\selftest_models.py --profile pc_cpu` prints OK/FAIL for every model with the
exact error; `runs\desktop.log` has the same tracebacks. Send me that output.

## 4. Checklist before you go to the lab
See `docs/WINDOWS_RUNBOOK.md` → "Verify with real models" (fall clip → ALERT; normal clip → CLEAR;
gun-in-car → ALERT without asking; your baby clip → CLEAR with *toy* second opinion; Spanish voicemail →
translated + ALERT). If any of these misbehaves, send the folder `runs\<run-id>\` (report.json +
reasoning_trace.jsonl + evidence) and the fix goes into both packages.

## 5. Where things are
`edge_guardian/` code · `ui/` console · `config/` profiles · `scripts/` setup/run/fetch/train ·
`data/demo/` real public clips (with `library.json` attribution) · `runs/` every investigation (report.json,
reasoning_trace.jsonl, evidence frames, annotated clips, telemetry.json, actions.jsonl) · `docs/` proposal,
architecture, evaluation, demo script, presentation outline, runbooks.
