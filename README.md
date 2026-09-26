# EdgeGuardian — edge-native autonomous safety investigator

**HP ZGX Nano (NVIDIA GB10) · Track: Local Agentic Systems · SJSU Edge AI Hackathon 2026**

**Team PowerPuffGirls** — Soroor Ghandali, Mamta Jha, Shreya Akotiya, Shristi Kumar, Rohini Ramasheshu.
Submission map: `PROJECT_BRIEF.md` (one page) · `docs/BENCHMARKS.md` (metrics) · `docs/ARCHITECTURE.md` ·
`START_HERE_PC.md` / `START_HERE_GB10.md` (replicate on a laptop or on the Nano) · `Dockerfile`.

EdgeGuardian takes *any* recording — a room or nursery camera, a driverless-car cabin, a shop, a street,
a voicemail — and when something goes wrong it does what a good human supervisor would do, entirely on the
device (it keeps working with the network cable unplugged):

0. **Understands the scene before it judges** — a local CLIP model infers *where* this is (home, nursery,
   vehicle cabin, shop, street…), *who* is present (baby / child / adult / elderly) and gives every
   weapon-like detector box a zero-shot second opinion (real firearm/blade vs toy / phone / household
   object) — so a toddler crawling with a toy is never treated like an armed passenger.
1. **Perceives only what is necessary** — cheap frame triage → YOLO11 + gun/knife detector + ByteTrack →
   YOLO11-pose fall / slump state machine → faster-whisper transcription + any-language→English translation →
   threat/hate text classifiers → CLAP acoustic events. Dense inspection only inside candidate windows, with
   an annotated **evidence-replay clip** (red weapon boxes with confidence and size, skeletons) per window.
2. **Builds structured events** (`PERSON_01 SLUMPED_UNRESPONSIVE @ 8.0–23.5 s, conf 0.90`) and an
   event/evidence graph with personalized PageRank to rank what is worth an expensive look.
3. **Investigates visibly** — a master **ReAct agent** (Qwen2.5-VL-7B served by HP ZRT/vLLM on the GB10, or
   Ollama on a PC) thinks out loud, calls tools (inspect frames, run the VLM, read the transcript, retrieve the
   operator policy, query memory, ask the person, run the critic) and the UI streams every Thought → Action →
   Observation plus the model's own reasoning tokens. Identical tool calls are rejected, the last steps are
   reserved for the critic and the verdict, and every run ends with a **CLEAR / WATCH / ALERT** verdict and a
   model-written closing report — never with "ran out of steps".
4. **Verifies before acting** — an adversarial **critic agent** must review the hypothesis; a transparent
   **risk-aware policy** (belief × severity vs. cost-if-wrong, consent, harm asymmetry) gates every action.
5. **Acts** (simulated dispatch records): asks the pregnant passenger in Spanish whether she wants the ER and
   reroutes + calls 911 if she does not answer; never talks to a passenger with a gun — alerts police with the
   live location; notifies the parents when a caregiver strikes the baby; translates a threatening Spanish
   voicemail and files a police report; continues the route when the person says *estoy bien*.
6. **Remembers** (episodic / semantic / procedural memory with reflection) and **accounts for every joule and
   token** (frames skipped, tokens/s, GPU, cloud-equivalent cost vs. local energy) with an explicit,
   logged **edge-vs-cloud placement decision** for each computation.

Everything consequential is **simulated** in the hackathon build (no real 911/police calls, no vehicle control) —
the dispatch record shows exactly what would be sent to whom.

---

## Quick start

Two ways to run it: as a **desktop application** (`EdgeGuardian.exe` on Windows, `./EdgeGuardian` on the
GB10 — a native window, no browser, no URL) or as a local web app. Step-by-step: `START_HERE_PC.md`
(your PC, CPU or GPU) and `START_HERE_GB10.md` (the lab machine).

### A. Anywhere, no models (rehearsal mode, 2 minutes)
```bash
pip install -r requirements/base.txt && pip install -e . --no-deps
python scripts/make_synthetic_scenarios.py --out tests/.fixtures   # software test fixtures only (not demo material)
python -m pytest -q                                  # 15 tests: the five scenarios + negative control
python -m edge_guardian serve --profile fixture      # → http://127.0.0.1:8600
```
The fixture profile replays annotated synthetic clips through the *real* agent loop, policy, memory, graph,
telemetry and UI, so the whole product can be exercised on any laptop.

### B. Windows PC with real models — desktop app
```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\setup_windows.ps1 -Compute CPU        # or -Compute CUDA; builds EdgeGuardian.exe + Desktop shortcut
# then double-click EdgeGuardian.exe  (or: .\scripts\run_windows.ps1 to see the logs; -Web for the browser UI)
```


### C. HP ZGX Nano / GB10 (final, all inference local) — desktop app
```bash
bash scripts/setup_gb10.sh                    # app env (CUDA-13 torch, ultralytics, faster-whisper, CLIP) + ./EdgeGuardian launcher
bash scripts/launch_gb10_llm.sh               # ZRT serves Qwen/Qwen2.5-VL-7B-Instruct on http://127.0.0.1:8080/v1
./EdgeGuardian                                # desktop window on the GB10 (also in the application grid)
WEB=1 bash scripts/run_gb10.sh                # or the browser UI on :8600 (ssh -L 8600:127.0.0.1:8600 from a laptop)
```
See `docs/GB10_RUNBOOK.md` (ZTK/ZRT commands from the HP walkthrough, ports, memory budget, troubleshooting).

### D. Colab GPU functional test
`notebooks/EdgeGuardian_Colab.ipynb` — same code. Portability check only.

---

## How local / hybrid inference is implemented (hackathon requirement)

* **Every model runs on the device**: detectors/pose/ASR/classifiers in the app process (PyTorch/CTranslate2),
  the VLM/LLM through the OpenAI-compatible endpoint that ZRT/vLLM exposes on the same GB10
  (`config/gb10.yaml: llm.base_url = http://127.0.0.1:8080/v1`). No cloud AI client exists in the code.
* **Explicit placement policy** (`edge_guardian/edge_cloud.py`): each computation is classified
  *local* or *cloud-eligible* with reasons (privacy — video/audio/transcript/location never leave; latency
  budget; bandwidth; offline reliability; cost). In `local_only` mode (default) everything is local; in
  `hybrid` mode only non-sensitive tasks listed in `edge_cloud.cloud_allowed_for` (e.g. model updates,
  non-sensitive batch enrichment) may be marked cloud-eligible. The decision table is in every report and
  in the UI footer.
* **Measured, not claimed**: `telemetry.json` records tokens, model calls, latency, frames processed/skipped,
  GPU utilisation/memory (when sampled), the cloud-equivalent cost of the same tokens/video minutes and the
  local energy cost. Unmeasurable quantities (memory bandwidth) are reported as `null`, never invented.

## Repository map
```
edge_guardian/
  perception/   detector.py (YOLO11 + weapon + fallen, ByteTrack), pose.py (fall/slump/striking state machines),
                audio.py (faster-whisper, translate, threat/hate classifiers, CLAP), triage.py + qdirp.py
                (QDiRP-CompassNet stage-1 classifier), pipeline.py (scan → windows → dense), fixtures.py
  events/       builder.py (perception → Events/Evidence), graph.py (event graph + personalized PageRank)
  agent/        master.py (ReAct loop + heuristic planner/advisor), tools.py (MRKL tool registry), critic.py,
                policy.py (risk-aware gate, ask-user VOI), actions.py (simulated executors), safety.py (permissions,
                injection guard, audit), llm.py (OpenAI-compatible client: Ollama / vLLM / ZRT; fixture)
  memory/       store.py (episodic/semantic/procedural, hybrid retrieval, reflection), semantic_cache.py, cache.py
  server/app.py FastAPI: upload, SSE stream, answer, report, follow-up chat
  evaluation.py 4-layer metrics (model/application/process/business) + G-Eval judge + ablation variants
  telemetry.py, edge_cloud.py, video.py, schema.py, config.py, runner.py, cli.py
  desktop.py    desktop application mode (native window, auto-starts the local model server)
  perception/scene.py  CLIP zero-shot scene understanding (environment, age groups, weapon second opinion)
ui/             operator console (drop any recording · scene card · evidence replay · live reasoning · verdict · telemetry)
installer/      EdgeGuardian.cs (native Windows launcher, compiled by setup_windows.ps1) + icons
config/         base / fixture / pc_cpu / pc_gpu / colab / gb10 profiles (YAML, env overrides GUARDIAN_<SEC>__<KEY>)
scripts/        setup_windows.ps1, setup_gb10.sh, launch_gb10_llm.sh, run_gb10.sh, download_models.py,
                install_gb10.sh, fetch_real_demo_clips.py (real public clips + attribution), download_demo_media.py,
                make_spanish_voicemail.py, make_synthetic_scenarios.py, benchmark.py,
                train_weapon_yolo.py, train_fall_tcn.py, train_triage_qdirp.py, minitest.py
docs/           ARCHITECTURE, PROPOSAL (all 56 requested sections + 50 questions), RELATED_WORK_AND_NOVELTY,
                DATASETS_AND_MODELS, EVALUATION, THREAT_MODEL, DEMO_SCRIPT, PRESENTATION_OUTLINE, runbooks
research/       the literature / model / dataset / hackathon-rules research notes (verified 2026-09-22)
tests/          scenario + unit tests (fixture profile)
```

## Results (synthetic suite, fixture profile — software validation, not accuracy claims)
| variant | task success | false escalation | missed critical | ask correct | mean steps | model calls |
|---|---|---|---|---|---|---|
| full agent | 1.00 | 0.00 | 0.00 | 1.00 | 8.1 | 0.75 |
| no ask-user | 0.50 | 0.00 | 0.00 | 0.50 | 7.9 | 0.75 |
| fixed pipeline (no critic/ask/memory) | 0.50 | 0.00 | 0.00 | 0.50 | 5.3 | 0.75 |
| no VLM verification | 0.88 | 0.00 | 0.00 | 1.00 | 7.3 | 0.00 |

Run `python scripts/benchmark.py --profile gb10 --manifest data/eval/real_cases.jsonl` on the Nano for the
real-model numbers (see `docs/EVALUATION.md` for the protocol and the public datasets used).

## Licensing and data responsibility
Code: Apache-2.0. Ultralytics is AGPL-3.0; model weights and datasets keep their own licences
(`docs/DATASETS_AND_MODELS.md`). UR Fall is CC BY-NC-SA (research/demo only). No face recognition, no
identity inference, no biometrics. Only analyse media you are authorised to process.
