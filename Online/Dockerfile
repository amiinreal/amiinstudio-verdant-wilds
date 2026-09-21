FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY service.py .
RUN useradd --create-home amiin && chown amiin /app
USER amiin
CMD ["sh", "-c", "uvicorn service:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1 --ws-max-size 4194304 --ws-max-queue 16"]
