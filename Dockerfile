# EdgeGuardian application container (CV + ASR + agent + UI). The LLM/VLM is served by ZRT/vLLM
# on the host (GB10) or by Ollama on a PC; point GUARDIAN_LLM__BASE_URL at it.
#   docker build -t edge-guardian .
#   docker run --rm --gpus all --network host -e GUARDIAN_LLM__BASE_URL=http://127.0.0.1:8080/v1 edge-guardian
# On the GB10 (ARM64 + CUDA 13) use the NVIDIA PyTorch base image instead of python:3.11:
#   docker build --build-arg BASE=nvcr.io/nvidia/pytorch:26.08-py3 -t edge-guardian .
ARG BASE=python:3.11-slim
FROM ${BASE}
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg libgl1 libglib2.0-0 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements/ requirements/
RUN pip install -r requirements/base.txt && \
    (python -c "import torch" 2>/dev/null || pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu) && \
    pip install -r requirements/vision.txt -r requirements/audio.txt
COPY . .
RUN pip install -e . --no-deps && python scripts/make_synthetic_scenarios.py --out data/synthetic
EXPOSE 8600
ENV GUARDIAN_PROFILE=pc_cpu
CMD ["sh", "-c", "python -m edge_guardian serve --profile ${GUARDIAN_PROFILE} --host 0.0.0.0 --port 8600"]
