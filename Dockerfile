FROM maven as builder
WORKDIR /build
RUN git clone https://github.com/veraPDF/veraPDF-rest.git
RUN cd veraPDF-rest && git checkout 3fdb3f230ba148a2045cd3da691b18831691e8f6 && mvn clean package

FROM digitalmarketplace/base-api:8.0.0

ENV CLAMAV_VERSION 0.
ENV VERAPDF_REST_VERSION=0.1.0-SNAPSHOT

# see debian bug #863199 regarding installing openjdk in docker
RUN mkdir -p /usr/share/man/man1

RUN echo "deb http://http.debian.net/debian/ buster main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://http.debian.net/debian/ buster-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://security.debian.org/ buster/updates main contrib non-free" >> /etc/apt/sources.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        build-essential \
        clamav-daemon=${CLAMAV_VERSION}* \
        clamav-freshclam=${CLAMAV_VERSION}* \
        libclamunrar9 \
        default-jre-headless \
        wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/veraPDF-rest/target/verapdf-rest-${VERAPDF_REST_VERSION}.jar /opt/verapdf-rest/verapdf-rest.jar

RUN wget -O /var/lib/clamav/main.cvd http://database.clamav.net/main.cvd && \
    wget -O /var/lib/clamav/daily.cvd http://database.clamav.net/daily.cvd && \
    wget -O /var/lib/clamav/bytecode.cvd http://database.clamav.net/bytecode.cvd && \
    chown clamav:clamav /var/lib/clamav/*.cvd

RUN mkdir /var/run/clamav && \
    chown clamav:clamav /var/run/clamav && \
    chmod 750 /var/run/clamav

RUN sed -i 's/^Foreground .*$/Foreground true/g' /etc/clamav/clamd.conf && \
    echo "TCPSocket 3310" >> /etc/clamav/clamd.conf

RUN usermod -a -G clamav www-data

COPY config/freshclam.conf /etc/clamav

RUN groupadd -r verapdf-rest && useradd --no-log-init -r -g verapdf-rest verapdf-rest

COPY config/verapdf-rest.yml /etc/verapdf-rest.yml

COPY config/additional-supervisord.conf /home/vcap/additional-supervisord.conf
RUN cat /home/vcap/additional-supervisord.conf >> /etc/supervisord.conf

COPY config/additional-awslogs.conf /home/vcap/additional-awslogs.conf
RUN cat /home/vcap/additional-awslogs.conf >> /etc/awslogs.conf
