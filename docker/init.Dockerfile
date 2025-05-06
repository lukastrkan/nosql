FROM ghcr.io/lukastrkan/redis8

RUN apt-get update && apt-get install -y python3-pip python3-venv
COPY python /python
WORKDIR /python

RUN python3 -m venv venv && source venv/bin/activate

RUN pip install --upgrade pip && pip install -r requirements.txt