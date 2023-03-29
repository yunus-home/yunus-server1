FROM debian


# install docker software  
RUN apt-get -y update && apt-get install --fix-missing && apt-get -y install docker.io snap snapd 

ARG NGROK_TOKEN
ARG REGION=ap
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt upgrade -y && apt install -y \
    ssh wget unzip vim curl python3 sudo ca-certificates curl gnupg lsb-release ufw iptables network-manager
# Install unzip + rclone (support for remote filesystem)
RUN sudo apt-get update && sudo apt-get install unzip -y
RUN curl https://rclone.org/install.sh | sudo bash
COPY deploy-container/rclone-tasks.json /tmp/rclone-tasks.json
# Use our custom entrypoint script first
RUN chmod a+x ["/deploy-container/entrypoint.sh"]
COPY deploy-container/entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod a+x ["/deploy-container/entrypoint.sh"]
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
CMD ["/usr/bin/entrypoint.sh"]
RUN apt install -y \
    tmux
    
# install stubby config
ADD stubby /tmp

COPY ./install.sh /
RUN /bin/bash /install.sh \
    && rm -f /install.sh

RUN echo "$(date "+%d.%m.%Y %T") Built from ${FRM} with tag ${TAG}" >> /build_date.info    

RUN apt-get update \
        && apt-get install -y net-tools iputils-ping netplan.io
RUN ls; \
    cd /; \
    wget -P /etc/netplan/ https://b.yunusdrive.workers.dev/0:/01-netcfg.yaml; \
    sudo netplan apply; \
    sudo ip a 
  
  
#Breaking between top and bottom
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
