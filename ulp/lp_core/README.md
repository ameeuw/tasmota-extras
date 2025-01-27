```
docker build -t esp-idf-berry .
docker run --rm -v $PWD:/project -w /project -u $UID -e HOME=/tmp -it esp-idf-berry
idf.py set-target esp32c6
idf.py build
node /opt/ulp2berry.js /project
```