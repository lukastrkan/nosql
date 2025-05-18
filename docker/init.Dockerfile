FROM ghcr.io/lukastrkan/redis8

RUN apt-get update && apt-get install -y python3-pip python3-venv
COPY init /init
WORKDIR /init

RUN python3 -m venv venv && chmod +x venv/bin/activate && ./venv/bin/pip install -r requirements.txt

ENTRYPOINT [ "/bin/bash", "/init/init-cluster.sh" ]