FROM micropython/unix
RUN apt-get update && apt-get install -y git

RUN echo "\
import mip\n\
mip.install('github:micropython/micropython-esp32-ulp')\n\
" > install.py

RUN micropython install.py

RUN git clone -n --depth=1 --filter=tree:0 https://github.com/espressif/esp-idf
RUN cd esp-idf && git sparse-checkout init --no-cone && git sparse-checkout set components/soc/esp32 && git checkout

RUN micropython -m esp32_ulp.parse_to_db esp-idf/components/soc/esp32/include/soc/*.h

CMD ["micropython"]