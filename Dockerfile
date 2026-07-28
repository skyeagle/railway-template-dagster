FROM python:3.12.11-slim-bookworm@sha256:519591d6871b7bc437060736b9f7456b8731f1499a57e22e6c285135ae657bf7

ENV DAGSTER_HOME=/opt/dagster/dagster_home \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /opt/dagster/app

COPY requirements.txt .
RUN pip install --no-cache-dir --requirement requirements.txt

COPY app ./app
COPY dagster.yaml workspace.yaml ./
COPY scripts/daemon_health.py scripts/start.sh ./scripts/
RUN chmod 0555 ./scripts/daemon_health.py ./scripts/start.sh \
    && mkdir -p "${DAGSTER_HOME}" \
    && cp dagster.yaml "${DAGSTER_HOME}/dagster.yaml"

EXPOSE 3000

CMD ["./scripts/start.sh", "webserver"]
