FROM alpine:latest
LABEL maintainer="j.engel@intero-consulting.de"

ENV VERSION 2.0.7
COPY 389-ds-base-389-ds-base-${VERSION}.tar.gz /tmp/389-ds-base-${VERSION}.tar.gz
RUN apk add nspr nss openldap db cyrus-sasl icu pcre cracklib \
    net-snmp bzip2 zlib openssl linux-pam libevent krb5 python3 \
    nss-tools supervisor

RUN apk add build-base nspr-dev nss-dev openldap-dev db-dev \
    cyrus-sasl-dev icu-dev pcre-dev cracklib-dev git \
    net-snmp-dev bzip2-dev zlib-dev openssl-dev \
    linux-pam-dev cargo rust pkgconfig autoconf automake libtool \
    cmocka-dev libevent-dev krb5-dev tar gzip \
    python3 py3-setuptools py3-pyldap py3-asn1 py3-dateutil py3-pip \
    python3-dev && \
# Start build
    mkdir /tmp/389ds && \
    cd /tmp/389ds && \
    mkdir BUILD && \
    tar xvf /tmp/389-ds-base-${VERSION}.tar.gz && \
    rm /tmp/389-ds-base-${VERSION}.tar.gz && \
    mv 389-ds-base-389-ds-base-${VERSION} 389-ds-base && \
    cd 389-ds-base && \
    ./autogen.sh && \
    cd /tmp/389ds/BUILD && \
    CFLAGS='-g -pipe -Wall -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic' \
    CXXFLAGS='-g -pipe -Wall -O2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic' \
    ../389-ds-base/configure --with-openldap --with-fhs \
      --enable-gcc-security --enable-rust --disable-cockpit \
      --enable-autobind --enable-auto-dn-suffix && \
    make -j12 && \
    make install && \
    cd /tmp/389ds/389-ds-base/src/lib389 && \
    pip3 install argparse-manpage && \
    pip3 install argcomplete && \
    python3 setup.py build && \
    python3 setup.py install --skip-build && \
# Remove devel packages again    
    apk del build-base nspr-dev nss-dev openldap-dev db-dev \
    cyrus-sasl-dev icu-dev pcre-dev cracklib-dev git \
    net-snmp-dev bzip2-dev zlib-dev openssl-dev \
    linux-pam-dev pkgconfig autoconf automake libtool \
    cmocka-dev libevent-dev krb5-dev py3-pip python3-dev && \
    rm -r /tmp/389ds && \
    rm -f /tmp/389-ds-base-${VERSION}.tar.gz

ENV ROOT_PW 'Secret.123'
ENV INSTANCE_NAME localhost
ENV BASEDN dc=example,dc=org
ENV USERNAME dirsrv
ENV GROUP dirsrv

VOLUME ["/etc/dirsrv", "/var/lib/dirsrv", "/var/log/dirsrv", "/certs"]

# Move config to temporary location until volume is ready
RUN mkdir /etc/dirsrv-tmpl && mv /etc/dirsrv/* /etc/dirsrv-tmpl/

EXPOSE 389 636

RUN addgroup -S ${GROUP} && adduser -S ${USERNAME} -h /etc/dirsrv -G ${GROUP}
RUN mkdir -p /var/lock/dirsrv && chown ${USERNAME}.${GROUP} /var/lock/dirsrv && \
    mkdir -p /run/lock/dirsrv && chown ${USERNAME}.${GROUP} /run/lock/dirsrv && \
    mkdir -p /etc/supervisor

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY run_server.sh /run_server.sh
COPY start.sh /start.sh
COPY dirsrv-dir /etc/systemctl/dirsrv-dir

RUN chmod a+x /start.sh && \
    chmod a+x /run_server.sh && \
    dscreate create-template > /tmp/ds.inf && \
    sed -i -e "s/;root_password = .*/root_password = ${ROOT_PW}/g" \
      -e "s/;instance_name = .*/instance_name = ${INSTANCE_NAME}/g" \
      -e "s/;suffix = .*/suffix = ${BASEDN}/g" \
      -e "s/;self_sign_cert = .*/self_sign_cert = False/g" /tmp/ds.inf && \
    dscreate from-file /tmp/ds.inf && \
    sed -i -e "s/slapd-dir/slapd-${INSTANCE_NAME}/g" /run_server.sh

CMD ["/start.sh"]
