FROM python:3.11-alpine

WORKDIR /app
COPY requirements.txt /app
COPY manifest.json /app
COPY src/* /app
RUN pip install -r requirements.txt
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "main:app", "--access-logfile", "'-'", "--log-level", "debug"]