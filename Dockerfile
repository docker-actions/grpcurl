FROM ubuntu:bionic as build

ARG VERSION="1.0.0"
ARG SHA256_SUM="c147339b562315c0bde39f1c2960d63c281724f35677ee5d80723cad731fe5d2"

ENV ROOTFS /build/rootfs
ENV BUILD_DEBS /build/debs
ENV DEBIAN_FRONTEND=noninteractive
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=true

SHELL ["bash", "-ec"]

# Build pre-requisites
RUN mkdir -p ${BUILD_DEBS} ${ROOTFS}/{opt,sbin,usr/bin,usr/local/bin,opt/grpc}

# Fix permissions
RUN chown -Rv 100:root $BUILD_DEBS

# Install pre-requisites
RUN apt-get update \
        && apt-get -y install apt-utils curl gpg ca-certificates

RUN set -Eeuo pipefail; \
    cd ${ROOTFS}/opt/grpc \
      && curl -L -o grpcurl.tar.gz https://github.com/fullstorydev/grpcurl/releases/download/v${VERSION}/grpcurl_${VERSION}_linux_x86_64.tar.gz \
      && echo "$SHA256_SUM grpcurl.tar.gz" | sha256sum -c - \
      && tar -xzf grpcurl.tar.gz \
      && rm -f grpcurl.tar.gz \
      && ln -s /opt/grpc/grpcurl ${ROOTFS}/usr/bin/grpcurl

# Move /sbin out of the way
RUN mv ${ROOTFS}/sbin ${ROOTFS}/sbin.orig \
      && mkdir -p ${ROOTFS}/sbin \
      && for b in ${ROOTFS}/sbin.orig/*; do \
           echo 'cmd=$(basename ${BASH_SOURCE[0]}); exec /sbin.orig/$cmd "$@"' > ${ROOTFS}/sbin/$(basename $b); \
           chmod +x ${ROOTFS}/sbin/$(basename $b); \
         done

COPY entrypoint.sh ${ROOTFS}/usr/local/bin/entrypoint.sh
RUN chmod +x ${ROOTFS}/usr/local/bin/entrypoint.sh

FROM actions/bash:4.4.18-8
LABEL maintainer = "ilja+docker@bobkevic.com"

ARG ROOTFS=/build/rootfs

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

COPY --from=build ${ROOTFS} /

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]