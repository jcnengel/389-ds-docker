FROM alpine:latest
LABEL maintainer="j.engel@intero-consulting.de"

ENV VERSION 2.0.5
#COPY vendor.tar.gz /tmp/vendor.tar.gz
RUN apk add build-base wget nspr-dev nss-dev openldap-dev db-dev \
    cyrus-sasl-dev icu-dev pcre-dev cracklib-dev git \
    net-snmp-dev bzip2-dev zlib-dev openssl-dev \
    linux-pam-dev cargo rust pkgconfig autoconf automake libtool \
    cmocka-dev libevent-dev krb5-dev tar gzip \
    python3 py3-setuptools py3-pyldap py3-asn1 py3-dateutil py3-pip \
    python3-dev 
COPY 389-ds-base-389-ds-base-${VERSION}.tar.gz /tmp/389-ds-base-${VERSION}.tar.gz
RUN mkdir /tmp/389ds && \
    cd /tmp/389ds && \
    mkdir BUILD && \
    tar xvf /tmp/389-ds-base-${VERSION}.tar.gz && \
    rm /tmp/389-ds-base-${VERSION}.tar.gz && \
    mv 389-ds-base-389-ds-base-${VERSION} 389-ds-base && \
    cd 389-ds-base && \
    ./autogen.sh
#RUN  cd ../BUILD && \
#    tar xvf /tmp/vendor.tar.gz && \
#    rm /tmp/vendor.tar.gz

RUN cd /tmp/389ds/BUILD && \
    CFLAGS='-g -pipe -Wall -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic' \
    CXXFLAGS='-g -pipe -Wall -O2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic' \
    ../389-ds-base/configure --with-openldap --with-fhs \
      --enable-gcc-security --enable-rust --disable-cockpit \
      --enable-autobind --enable-auto-dn-suffix && \
      #--enable-rust-offline && \
#      --prefix=/usr --exec-prefix=/usr --bindir=/usr/bin \
#      --sbindir=/usr/sbin --sysconfdir=/etc --datadir=/usr/share \
#      --localstatedir=/var --sharedstatedir=/var/lib && \
    make -j4 install
RUN cd /tmp/389ds/389-ds-base/src/lib389 && \
    pip3 install argparse-manpage && \
    pip3 install argcomplete && \
    python3 setup.py build && \
    python3 setup.py install --prefix /usr
RUN apk del build-base nspr-dev nss-dev openldap-dev db-dev \
    cyrus-sasl-dev icu-dev pcre-dev cracklib-dev git \
    net-snmp-dev bzip2-dev zlib-dev openssl-dev \
    linux-pam-dev pkgconfig autoconf automake libtool \
    cmocka-dev libevent-dev krb5-dev py3-pip python3-dev && \
    apk add nspr nss openldap db cyrus-sasl icu pcre cracklib \
    net-snmp bzip2 zlib openssl linux-pam libevent krb5 python3 \
    nss-tools

ENV ROOT_PW 'Secret.123'
ENV INSTANCE_NAME localhost
ENV BASEDN dc=example,dc=org
ENV USERNAME dirsrv
ENV GROUP dirsrv

RUN addgroup -S ${GROUP} && adduser -S ${USERNAME} -h /etc/dirsrv -G ${GROUP}

RUN dscreate create-template /etc/dirsrv/ds.inf && \
    sed -i \
       -e "s/;instance_name = .*/instance_name = ${INSTANCE_NAME}/g" \
       -e "s/;root_password = .*/root_password = ${ROOT_PW}/g" \
       -e "s/;suffix = .*/suffix = ${BASEDN}/g" \
       -e "s/;self_sign_cert = .*/self_sign_cert = False/g" \
       /etc/dirsrv/ds.inf && \
    dscreate from-file /etc/dirsrv/ds.inf

USER ${USERNAME}
CMD ["dirsrv"]
