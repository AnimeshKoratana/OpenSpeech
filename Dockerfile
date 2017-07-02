FROM ubuntu:16.04
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

RUN cd /opt && wget http://www.digip.org/jansson/releases/jansson-2.7.tar.bz2 && \
    bunzip2 -c jansson-2.7.tar.bz2 | tar xf -  && \
    cd jansson-2.7 && \
    ./configure && make && make check &&  make install && \
    echo "/usr/local/lib" >> /etc/ld.so.conf.d/jansson.conf && ldconfig && \
    rm /opt/jansson-2.7.tar.bz2 && rm -rf /opt/jansson-2.7

RUN cd /opt && \
    git clone https://github.com/kaldi-asr/kaldi && \
    cd /opt/kaldi/tools && \
    make && \
    ./install_portaudio.sh && \
    cd /opt/kaldi/src && ./configure --shared && \
    sed -i '/-g # -O0 -DKALDI_PARANOID/c\-O3 -DNDEBUG' kaldi.mk && \
    make depend && make && \
    cd /opt/kaldi/src/online && make depend && make && \
    cd /opt/kaldi/src/gst-plugin && make depend && make && \
    cd /opt && \
    git clone https://github.com/alumae/gst-kaldi-nnet2-online.git && \
    cd /opt/gst-kaldi-nnet2-online/src && \
    sed -i '/KALDI_ROOT?=\/home\/tanel\/tools\/kaldi-trunk/c\KALDI_ROOT?=\/opt\/kaldi' Makefile && \
    make depend && make && \
    rm -rf /opt/gst-kaldi-nnet2-online/.git/ && \
    find /opt/gst-kaldi-nnet2-online/src/ -type f -not -name '*.so' -delete && \
    rm -rf /opt/kaldi/.git && \
    rm -rf /opt/kaldi/egs/ /opt/kaldi/windows/ /opt/kaldi/misc/ && \
    find /opt/kaldi/src/ -type f -not -name '*.so' -delete && \
    find /opt/kaldi/tools/ -type f \( -not -name '*.so' -and -not -name '*.so*' \) -delete && \
    cd /opt && git clone https://github.com/alumae/kaldi-gstreamer-server.git && \
    rm -rf /opt/kaldi-gstreamer-server/.git/ && \
    rm -rf /opt/kaldi-gstreamer-server/test/

COPY start.sh stop.sh /opt/

RUN chmod +x /opt/start.sh && \
    chmod +x /opt/stop.sh && \
    cd /opt && git clone https://github.com/AnimeshKoratana/OpenSpeech.git && \
    cd OpenSpeech && sh install_aeneas_deps.sh && \
    pip install aeneas && \
    python -m aeneas.diagnostics

ADD /media/kaldi_models /opt/models


