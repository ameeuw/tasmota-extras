FROM espressif/idf:latest
RUN apt-get update && apt-get install -y nodejs

COPY ulp2berry.js /opt/ulp2berry.js

ENTRYPOINT [ "/opt/esp/entrypoint.sh" ]
CMD [ "/bin/bash" ]