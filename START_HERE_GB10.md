# EdgeGuardian — START HERE (HP ZGX Nano / NVIDIA GB10, the lab machine)

Same code as the PC package. On the Nano every model runs locally: HP **ZRT** (vLLM) serves the
vision-language model on `http://127.0.0.1:8080/v1`, and the app (detectors, pose, whisper, CLIP, the agent,
the console) runs in its own venv on the same GPU. No cloud AI anywhere — it works with the network unplugged.

## 1. Connect (ZTK, as in the HP walkthrough video)
VS Code → *Z Toolkit* → **ZTK Device Manager** → *Add New Device* (host/IP from Tailscale, user `hpX`,
password `edgehack`) → *Connect*. You now have a VS Code window + terminal on the Nano.
If ZRT is not installed: `sudo zrt setup`.

## 2. Install the app (once, ≈10 min; needs internet for the model weights and demo clips)
```bash
# copy this package to the Nano (drag it into the VS Code explorer, or scp), then:
cd ~/Desktop && unzip -q EdgeGuardian-GB10.zip && cd edge-guardian
bash scripts/setup_gb10.sh
```
This creates `.venv-gb10`, installs CUDA-13 PyTorch + ultralytics + faster-whisper + CLIP, downloads the
models and the public example recordings, runs the tests (fixture profile — **no GPU time used**),
exports TensorRT engines, and installs **`./EdgeGuardian`** (executable launcher + entry in the application grid).

## 3. Serve the model with ZRT (≈2–5 min the first time)
```bash
zrt status                          # is another model already served (e.g. Nemotron)?  zrt stop <name> frees its memory
bash scripts/launch_gb10_llm.sh     # zrt serve Qwen/Qwen2.5-VL-7B-Instruct --gpu-memory-fraction 0.35 → http://127.0.0.1:8080/v1
                                    # (pulls the model once, ~16 GB; waits until the API is healthy)
curl http://127.0.0.1:8080/v1/models   # must print the model id
```
If it stops with **"Free memory on device … is less than desired GPU memory utilization"**, something else holds the
128 GB pool: `zrt status` → `zrt stop <service>`, or `nvidia-smi` → kill a stale `vllm`/`python` of yours, then rerun
(`GPU_FRACTION=0.25 bash scripts/launch_gb10_llm.sh` for an even smaller reservation).
(Other vision models work too: `MODEL=Qwen/Qwen3-VL-8B-Instruct bash scripts/launch_gb10_llm.sh` and
`export GUARDIAN_LLM__MODEL=Qwen/Qwen3-VL-8B-Instruct`.)

## 4. Run
* On the Nano's own screen: **`./EdgeGuardian`** (or *EdgeGuardian* in the application grid). Native window;
  it starts ZRT itself if nothing is served yet.
* From your laptop over SSH: `WEB=1 bash scripts/run_gb10.sh` on the Nano, then on the laptop
  `ssh -L 8600:127.0.0.1:8600 hpX@<tailscale-ip>` and open http://127.0.0.1:8600 (the VS Code *Ports* tab
  forwards it as well — exactly like the web app in the HP video).
* CLI: `python -m edge_guardian analyze data/demo/urfd_fall_01.mp4 --profile gb10 --answer ""`

## 5. Demo flow (2-min video / 5-min live / pitch)
**Speed on the Nano (v3.4):** all perception models are loaded once at start and stay resident (header pill
"models resident in memory"), so every clip after the first starts instantly. The **Reasoning** switch under
*Investigate* picks **Fast** (policy planner drives; 3 model calls: vision check → critic → report; ~30-40 s for a
5-s clip) or **Deep** (the model plans every step with its thinking streamed; ~10 calls). Use Fast for the timing/cost
comparison against the PC (same 3 calls, GB10 ≈ 8× faster) and Deep once to show the live reasoning.
Drop a recording (or *Example recordings*) → **Investigate** → scene understanding → events → red weapon
boxes + evidence replay → live thought/action/observation trace with the model's thinking → question to the
person (answer or stay silent) → simulated dispatch → **CLEAR / WATCH / ALERT** verdict + written report →
telemetry (tokens/s, frames skipped, GPU, cloud-equivalent $ vs local energy, edge/cloud placement table).
Suggested order: normal clip (CLEAR, no VLM spent) → fall (ask → silence → 911) → gun in car (no question,
police + location) → Spanish threat voicemail (translated, ALERT) → your baby clip (toy, CLEAR).
`docs/DEMO_SCRIPT.md` and `docs/PRESENTATION_OUTLINE.md` have the narration and slide plan.

## 6. Optional: fine-tune on the Nano (stop the served model first: `zrt stop <service>`)
```bash
python scripts/train_weapon_yolo.py --fetch handguns --out data/weapons_yolo && \
python scripts/train_weapon_yolo.py --train data/weapons_yolo/dataset.yaml --epochs 30 --imgsz 960 --device 0 --export-trt
python scripts/train_fall_tcn.py --extract data/demo --out data/fall_windows.npz && python scripts/train_fall_tcn.py --train data/fall_windows.npz --device cuda
python scripts/benchmark.py --profile gb10 --manifest data/eval/real_cases.jsonl     # real-model numbers for the pitch
```

## 7. Rules compliance (hackathon PDF)
Core inference local (ZRT/vLLM + in-process models) · no cloud AI client in the code · explicit edge/cloud
placement log in every report · all consequential actions simulated · public datasets with attribution
(`data/demo/library.json`, `docs/DATASETS_AND_MODELS.md`) · code Apache-2.0 (Ultralytics AGPL-3.0 noted).
Full details: `docs/GB10_RUNBOOK.md`, `docs/THREAT_MODEL.md`, `docs/EVALUATION.md`.
