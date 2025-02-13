FROM espressif/idf:latest
RUN apt-get update && apt-get install -y nodejs

COPY ulp2berry.js /opt/ulp2berry.js
COPY package.json /opt/package.json
COPY package-lock.json /opt/package-lock.json

RUN npm install

# Add an alias for ulp2berry to /etc/bash.bashrc which is sourced for all interactive shells
RUN echo 'alias ulp2berry="node /opt/ulp2berry.js /project"' >> /etc/bash.bashrc

ENTRYPOINT [ "/opt/esp/entrypoint.sh" ]
CMD [ "/bin/bash" ]