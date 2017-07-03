FROM jcsilva/docker-kaldi-gstreamer-server
MAINTAINER Animesh Koratana <koratana@stanford.edu>

RUN apt-get update && apt-get install -y  \
    autoconf \
    automake \
    bzip2 \
    g++ \
    git \
    gstreamer1.0-plugins-good \
    gstreamer1.0-tools \
    gstreamer1.0-pulseaudio \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-ugly  \
    libatlas3-base \
    libgstreamer1.0-dev \
    libtool-bin \
    make \
    python2.7 \
    python-pip \
    python-yaml \
    python-simplejson \
    python-gi \
    subversion \
    wget \
    unzip \
    gcc \
    ffmpeg \
    espeak \
    zlib1g-dev && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    pip install ws4py==0.3.2 && \
    pip install tornado && \
    pip install numpy && \
    pip install kafka-python && \
    pip install python-rake && \
    pip install Cython && \
    pip install BeautifulSoup4 && \
    pip install lxml && \
    pip install pymongo && \
    ln -s /usr/bin/python2.7 /usr/bin/python ; ln -s -f bash /bin/sh

RUN cd /opt && git clone https://github.com/AnimeshKoratana/OpenSpeech.git && \
    cd OpenSpeech && sh install_aeneas_deps.sh && \
    pip install aeneas && \
    python -m aeneas.diagnostics

ADD /media/kaldi_models /opt/models

RUN git clone https://github.com/s3fs-fuse/s3fs-fuse /s3fs
RUN cd /s3fs && ./autogen.sh && ./configure --prefix=/usr --with-openssl && make && make install
RUN rm -rf /s3fs
RUN mkdir -p /mnt/s3


