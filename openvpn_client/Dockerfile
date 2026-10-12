FROM alpine:3.22
ARG BUILD_VERSION
ARG BUILD_ARCH
LABEL io.hass.version="${BUILD_VERSION}" io.hass.type="app" io.hass.arch="${BUILD_ARCH}"
RUN apk add --no-cache bash jq openvpn iproute2
COPY run.sh /run.sh
RUN chmod 755 /run.sh
CMD ["/run.sh"]
