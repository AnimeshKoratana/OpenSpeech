FROM jcsilva/docker-kaldi-gstreamer-server
MAINTAINER Animesh Koratana <koratana@stanford.edu>

RUN apt-get update && apt-get install -y  \
    unzip \
    gcc \
    espeak && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    pip install numpy && \
    pip install kafka-python && \
    pip install python-rake && \
    pip install Cython && \
    pip install BeautifulSoup4 && \
    pip install python-lxml && \
    pip install pymongo && \

RUN cd /opt && git clone https://github.com/AnimeshKoratana/OpenSpeech.git && \
    cd OpenSpeech && sh install_aeneas_deps.sh && \
    pip install aeneas && \
    python -m aeneas.diagnostics

ADD /media/kaldi_models /opt/models

RUN git clone https://github.com/s3fs-fuse/s3fs-fuse /s3fs
RUN cd /s3fs && ./autogen.sh && ./configure --prefix=/usr --with-openssl && make && make install
RUN rm -rf /s3fs
RUN mkdir -p /mnt/s3


