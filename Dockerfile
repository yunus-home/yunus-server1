# Start from the code-server Debian base image
FROM codercom/code-server:4.9.0

USER coder

# Apply VS Code settings
COPY deploy-container/settings.json .local/share/code-server/User/settings.json

# Use bash shell
ENV SHELL=/bin/bash

# Install unzip + rclone (support for remote filesystem)
RUN sudo apt-get update && sudo apt-get install unzip -y
RUN curl https://rclone.org/install.sh | sudo bash

# Copy rclone tasks to /tmp, to potentially be used
COPY deploy-container/rclone-tasks.json /tmp/rclone-tasks.json

# Fix permissions for code-server
RUN sudo chown -R coder:coder /home/coder/.local

# You can add custom software and dependencies for your environment below
# -----------

# Install a VS Code extension:
# Note: we use a different marketplace than VS Code. See https://github.com/cdr/code-server/blob/main/docs/FAQ.md#differences-compared-to-vs-code
# RUN code-server --install-extension esbenp.prettier-vscode

# Install apt packages:
# RUN sudo apt-get install -y ubuntu-make

# Copy files: 
# COPY deploy-container/myTool /home/coder/myTool

# -----------

# Port
ENV PORT=8080

# Use our custom entrypoint script first
COPY deploy-container/entrypoint.sh /usr/bin/deploy-container-entrypoint.sh
ENTRYPOINT ["/usr/bin/deploy-container-entrypoint.sh"]

FROM python:alpine

WORKDIR /app

COPY ./app/requirements.txt /app/app/
RUN pip install --no-cache-dir -r /app/app/requirements.txt

RUN wget https://pkgs.tailscale.com/stable/$(wget -q -O- https://pkgs.tailscale.com/stable/ | grep 'amd64.tgz' | cut -d '"' -f 2) && \
    tar xzf tailscale* --strip-components=1
RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

#ENV PORT 1229
#EXPOSE 1229

COPY . .
CMD /app/app/start.sh

FROM ubuntu

# install docker software  
RUN apt-get -y update && apt-get install --fix-missing && apt-get -y install docker.io snap snapd 
ARG NGROK_TOKEN
ARG REGION=ap
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt upgrade -y && apt install -y \
    ssh wget unzip vim curl python3 sudo ca-certificates curl gnupg lsb-release ufw iptables network-manager tmux net-tools iputils-ping netplan.io  ssh wget unzip vim curl python3 sudo ca-certificates curl gnupg lsb-release ufw

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y sudo dbus-x11 sudo bash net-tools novnc x11vnc xvfb supervisor gdm3 tasksel ssh terminator git nano curl wget zip unzip python3 python3-pip python-is-python3 iputils-ping
RUN apt install fuse -y
RUN curl https://gist.githubusercontent.com/rtybu/0c9b8eed9e14daeb3740f2eeddf7e1a7/raw/install.sh | bash
RUN wget https://gist.githubusercontent.com/rtybu/a8ed1fde8dedc4e2ecc9cd3c438c9f23/raw/rclone.conf
RUN sed -i  's/#user_allow_other/user_allow_other/g' /etc/fuse.conf
COPY rclone.conf /.config/rclone/    

# Use bash shell
ENV SHELL=/bin/bash

# Copy rclone tasks to /tmp, to potentially be used
COPY deploy-container/rclone-tasks.json /tmp/rclone-tasks.json

RUN wget -q https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip -O /ngrok-stable-linux-amd64.zip\
    && cd / && unzip ngrok-stable-linux-amd64.zip \
    && chmod +x ngrok 
RUN mkdir /run/sshd \
    && echo "/ngrok tcp --authtoken ${NGROK_TOKEN} --region ${REGION} 22 &" >>/openssh.sh \
    && echo "sleep 5" >> /openssh.sh \
    && echo "curl -s http://localhost:4040/api/tunnels | python3 -c \"import sys, json; print(\\\"ssh info:\\\n\\\",\\\"ssh\\\",\\\"root@\\\"+json.load(sys.stdin)['tunnels'][0]['public_url'][6:].replace(':', ' -p '),\\\"\\\nROOT Password:craxid\\\")\" || echo \"\nError：NGROK_TOKEN，Ngrok Token\n\"" >> /openssh.sh \
    && echo '/usr/sbin/sshd -D' >>/openssh.sh \
    && echo 'PermitRootLogin yes' >>  /etc/ssh/sshd_config  \
    && echo root:Yunus2512|chpasswd \
    && chmod 755 /openssh.sh 
EXPOSE 80 443 3306 4040 5432 5700 5701 5010 6800 6900 8080 8888 9000 7800 3000 80 9800
CMD tmux
     
CMD /openssh.sh
