FROM python:3.12-slim
# Create a non-root user with a specific UID
RUN useradd --create-home --uid 1000 appuser
WORKDIR /home/appuser/app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
# Ensure the user owns the app directory
RUN chown -R 1000:1000 /home/appuser/app
USER 1000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
