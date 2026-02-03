ARG RESTY_BASE_IMAGE_TAG="3.22.3"
FROM alpine:${RESTY_BASE_IMAGE_TAG}
ARG RESTY_BASE_IMAGE_TAG

# Docker Build Arguments
ARG RESTY_VERSION="1.27.1.2"

# https://github.com/openresty/openresty-packaging/blob/master/alpine/openresty-openssl3/APKBUILD
ARG RESTY_OPENSSL_VERSION="3.4.3"
ARG RESTY_OPENSSL_PATCH_VERSION="3.4.1"
ARG RESTY_OPENSSL_URL_BASE="https://github.com/openssl/openssl/releases/download/openssl-${RESTY_OPENSSL_VERSION}"
ARG RESTY_OPENSSL_BUILD_OPTIONS="enable-camellia enable-rfc3779 enable-ktls enable-fips \
    disable-md2 disable-rc5 disable-weak-ssl-ciphers disable-ssl3 disable-ssl3-method"

# https://github.com/openresty/openresty-packaging/blob/master/alpine/openresty-pcre2/APKBUILD
ARG RESTY_PCRE_VERSION="10.44"
ARG RESTY_PCRE_SHA256="86b9cb0aa3bcb7994faa88018292bc704cdbb708e785f7c74352ff6ea7d3175b"
ARG RESTY_PCRE_BUILD_OPTIONS="--enable-jit --enable-pcre2grep-jit --disable-bsr-anycrlf --disable-coverage --disable-ebcdic --disable-fuzz-support \
    --disable-jit-sealloc --disable-never-backslash-C --enable-newline-is-lf --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32 \
    --enable-pcre2grep-callout --enable-pcre2grep-callout-fork --disable-pcre2grep-libbz2 --disable-pcre2grep-libz --disable-pcre2test-libedit \
    --enable-percent-zt --disable-rebuild-chartables --enable-shared --disable-static --disable-silent-rules --enable-unicode --disable-valgrind \
    "

ARG RESTY_J="1"
ARG RESTY_STRIP_BINARIES="1"
ARG RESTY_GEOIP2_VERSION="3.4"

# These are not intended to be user-specified
ARG RESTY_CONFIG_OPTIONS="\
    --with-compat \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_realip_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-ipv6 \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-threads \
    --http-client-body-temp-path=/var/tmp/nginx-client \
    --http-proxy-temp-path=/var/tmp/nginx-proxy \
    --http-fastcgi-temp-path=/var/tmp/nginx-fastcgi \
    --http-uwsgi-temp-path=/var/tmp/nginx-uwsgi \
    --http-scgi-temp-path=/var/tmp/nginx-scgi \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-log-path=/var/log/openresty/access.log \
    --error-log-path=/var/log/openresty/error.log \
    "

ARG RESTY_CONFIG_OPTIONS_MORE="--add-module=/tmp/ngx_http_geoip2_module-${RESTY_GEOIP2_VERSION}"
ARG RESTY_LUAJIT_OPTIONS="--with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT'"
ARG RESTY_PCRE_OPTIONS="--with-pcre-jit"


# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-pcre \
    --with-cc-opt='-DNGX_LUA_ABORT_AT_PANIC -I/usr/local/openresty/pcre2/include -I/usr/local/openresty/openssl3/include' \
    --with-ld-opt='-L/usr/local/openresty/pcre2/lib -L/usr/local/openresty/openssl3/lib -Wl,-rpath,/usr/local/openresty/pcre2/lib:/usr/local/openresty/openssl3/lib' \
    "

LABEL resty.version="${RESTY_VERSION}" \
      resty.base_image="alpine:${RESTY_BASE_IMAGE_TAG}" \
      resty.openssl_version="${RESTY_OPENSSL_VERSION}" \
      resty.openssl_patch_version="${RESTY_OPENSSL_PATCH_VERSION}" \
      resty.pcre_version="${RESTY_PCRE_VERSION}" \
      resty.pcre_sha256="${RESTY_PCRE_SHA256}" \
      resty.geoip2_version="${RESTY_GEOIP2_VERSION}" \
      resty.config_options="${RESTY_CONFIG_OPTIONS}"

# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Cleanup

RUN set -x && apk update && apk add --no-cache --virtual .build-deps \
    build-base \
    binutils \
    coreutils \
    curl \
    gd-dev \
    libmaxminddb-dev \
    linux-headers \
    make \
    perl-dev \
    readline-dev \
    zlib-dev \
    && apk add --no-cache \
    gd \
    libgcc \
    libmaxminddb \
    tzdata \
    zlib \
    && cd /tmp \
    && curl -fSL "${RESTY_OPENSSL_URL_BASE}/openssl-${RESTY_OPENSSL_VERSION}.tar.gz" -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && cd openssl-${RESTY_OPENSSL_VERSION} \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-2) = "3." ] ; then \
    echo 'patching OpenSSL 3.x for OpenResty' \
    && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-${RESTY_OPENSSL_PATCH_VERSION}-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-5) = "1.1.1" ] ; then \
    echo 'patching OpenSSL 1.1.1 for OpenResty' \
    && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-${RESTY_OPENSSL_PATCH_VERSION}-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-5) = "1.1.0" ] ; then \
    echo 'patching OpenSSL 1.1.0 for OpenResty' \
    && curl -s https://raw.githubusercontent.com/openresty/openresty/ed328977028c3ec3033bc25873ee360056e247cd/patches/openssl-1.1.0j-parallel_build_fix.patch | patch -p1 \
    && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-${RESTY_OPENSSL_PATCH_VERSION}-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && ./config \
    shared zlib -g \
    --prefix=/usr/local/openresty/openssl3 \
    --libdir=lib \
    -Wl,-rpath,/usr/local/openresty/openssl3/lib \
    ${RESTY_OPENSSL_BUILD_OPTIONS} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install_sw \
    && cd /tmp \
    && curl -fSL "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${RESTY_PCRE_VERSION}/pcre2-${RESTY_PCRE_VERSION}.tar.gz" -o pcre2-${RESTY_PCRE_VERSION}.tar.gz \
    && echo "${RESTY_PCRE_SHA256}  pcre2-${RESTY_PCRE_VERSION}.tar.gz" | shasum -a 256 --check \
    && tar xzf pcre2-${RESTY_PCRE_VERSION}.tar.gz \
    && cd /tmp/pcre2-${RESTY_PCRE_VERSION} \
    && CFLAGS="-g -O3" ./configure \
    --prefix=/usr/local/openresty/pcre2 \
    --libdir=/usr/local/openresty/pcre2/lib \
    ${RESTY_PCRE_BUILD_OPTIONS} \
    && CFLAGS="-g -O3" make -j${RESTY_J} \
    && CFLAGS="-g -O3" make -j${RESTY_J} install \
    && cd /tmp \
    && curl -sfSL https://github.com/leev/ngx_http_geoip2_module/archive/${RESTY_GEOIP2_VERSION}.tar.gz -o ngx_http_geoip2_module-${RESTY_GEOIP2_VERSION}.tar.gz \
    && tar xzf ngx_http_geoip2_module-${RESTY_GEOIP2_VERSION}.tar.gz \
    && cd /tmp \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && eval ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} ${RESTY_LUAJIT_OPTIONS} ${RESTY_PCRE_OPTIONS} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && rm -rf \
    openssl-${RESTY_OPENSSL_VERSION}.tar.gz openssl-${RESTY_OPENSSL_VERSION} \
    pcre2-${RESTY_PCRE_VERSION}.tar.gz pcre2-${RESTY_PCRE_VERSION} \
    openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
    ngx_http_geoip2_module-${RESTY_GEOIP2_VERSION}.tar.gz ngx_http_geoip2_module-${RESTY_GEOIP2_VERSION} \
    && if [ -n "${RESTY_STRIP_BINARIES}" ]; then \
    echo 'stripping OpenResty binaries' \
    && rm -Rf /usr/local/openresty/openssl3/bin/c_rehash /usr/local/openresty/openssl3/lib/*.a /usr/local/openresty/openssl3/include \
    && find /usr/local/openresty/openssl3 -type f -perm -u+x -exec strip --strip-unneeded '{}' \; \
    && rm -Rf /usr/local/openresty/pcre2/bin /usr/local/openresty/pcre2/share \
    && find /usr/local/openresty/pcre2 -type f -perm -u+x -exec strip --strip-unneeded '{}' \; \
    && rm -Rf /usr/local/openresty/luajit/lib/*.a /usr/local/openresty/luajit/share/man \
    && find /usr/local/openresty/luajit -type f -perm -u+x -exec strip --strip-unneeded '{}' \; \
    && find /usr/local/openresty/nginx -type f -perm -u+x -exec strip --strip-unneeded '{}' \; ; \
    fi \
    && apk del .build-deps \
    && rm -f /etc/periodic/weekly/libmaxminddb /etc/libmaxminddb.cron.conf \
    && mkdir -p /var/log/openresty \
    && ln -sf /dev/stdout /var/log/openresty/access.log \
    && ln -sf /dev/stderr /var/log/openresty/error.log

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin

# Copy nginx configuration files
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

ENTRYPOINT ["openresty", "-g", "daemon off;"]
CMD ["-c", "/usr/local/openresty/nginx/conf/nginx.conf"]

EXPOSE 80

# Use SIGQUIT instead of default SIGTERM to cleanly drain requests
# See https://github.com/openresty/docker-openresty/blob/master/README.md#tips--pitfalls
STOPSIGNAL SIGQUIT

