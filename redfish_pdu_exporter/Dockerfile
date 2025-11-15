FROM python:3.11-slim
WORKDIR /app
COPY exporter.py redfish_client.py /app/
RUN pip install --no-cache-dir aiohttp pyyaml prometheus-client
ENV CONFIG=/config/config.yaml
EXPOSE 9100
HEALTHCHECK CMD curl -fsS http://127.0.0.1:9100/-/healthz || exit 1
USER nobody
ENTRYPOINT ["python", "/app/exporter.py"]