FROM python:3.13-alpine
RUN pip install --no-cache-dir PyMySQL==1.1.2
WORKDIR /app
COPY mcp_server.py seed_demo.py /app/
ENTRYPOINT ["python", "/app/mcp_server.py"]
