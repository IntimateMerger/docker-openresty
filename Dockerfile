ARG RESTY_IMAGE_TAG="3.10"
FROM alpine:${RESTY_IMAGE_TAG}

# Docker Build Arguments
ARG RESTY_IMAGE_TAG
ARG RESTY_VERSION="1.15.8.2"
ARG RESTY_OPENSSL_VERSION="1.1.1c"
ARG RESTY_PCRE_VERSION="8.43"
ARG RESTY_GEOIP2_VERSION="3.2"
ARG RESTY_J="1"

# These are not intended to be user-specified
ARG _RESTY_CONFIG_OPTIONS="\
    --with-compat \
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_realip_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_v2_module \
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

ARG RESTY_CONFIG_OPTIONS=""
ARG RESTY_LUAJIT_OPTIONS="--with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT'"

ARG RESTY_ADD_PACKAGE_BUILDDEPS=""
ARG RESTY_ADD_PACKAGE_RUNDEPS=""
ARG RESTY_EVAL_PRE_CONFIGURE=""
ARG RESTY_EVAL_POST_MAKE=""

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-pcre \
    --with-cc-opt='-DNGX_LUA_ABORT_AT_PANIC -I/usr/local/openresty/pcre/include -I/usr/local/openresty/openssl/include' \
    --with-ld-opt='-L/usr/local/openresty/pcre/lib -L/usr/local/openresty/openssl/lib -Wl,-rpath,/usr/local/openresty/pcre/lib:/usr/local/openresty/openssl/lib' \
    "

LABEL resty.image="alpine:${RESTY_IMAGE_TAG}" \
      resty.version="${RESTY_VERSION}" \
      resty.openssl_version="${RESTY_OPENSSL_VERSION}" \
      resty.pcre_version="${RESTY_PCRE_VERSION}" \
      resty.config_options="${_RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS}" \
      resty.add_package_builddeps="${RESTY_ADD_PACKAGE_BUILDDEPS}" \
      resty.add_package_rundeps="${RESTY_ADD_PACKAGE_RUNDEPS}" \
      resty.eval_pre_configure="${RESTY_EVAL_PRE_CONFIGURE}" \
      resty.eval_post_make="${RESTY_EVAL_POST_MAKE}"

# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Cleanup

RUN set -x && apk update && apk add --no-cache --virtual .build-deps \
        build-base \
        coreutils \
        curl \
        gd-dev \
        libmaxminddb-dev \
        linux-headers \
        make \
        perl-dev \
        readline-dev \
        zlib-dev \
        ${RESTY_ADD_PACKAGE_BUILDDEPS} \
    && apk add --no-cache \
        gd \
        libgcc \
        libmaxminddb \
        zlib \
        ${RESTY_ADD_PACKAGE_RUNDEPS} \
    && cd /tmp \
    && if [ -n "${RESTY_EVAL_PRE_CONFIGURE}" ]; then eval $(echo ${RESTY_EVAL_PRE_CONFIGURE}); fi \
    && cd /tmp \
    && curl -sfSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && cd openssl-${RESTY_OPENSSL_VERSION} \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-5) = "1.1.1" ] ; then \
        echo 'patching OpenSSL 1.1.1 for OpenResty' \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-1.1.1c-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && if [ $(echo ${RESTY_OPENSSL_VERSION} | cut -c 1-5) = "1.1.0" ] ; then \
        echo 'patching OpenSSL 1.1.0 for OpenResty' \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/ed328977028c3ec3033bc25873ee360056e247cd/patches/openssl-1.1.0j-parallel_build_fix.patch | patch -p1 \
        && curl -s https://raw.githubusercontent.com/openresty/openresty/master/patches/openssl-1.1.0d-sess_set_get_cb_yield.patch | patch -p1 ; \
    fi \
    && ./config \
      no-threads shared zlib -g \
      enable-ssl3 enable-ssl3-method \
      --prefix=/usr/local/openresty/openssl \
      --libdir=lib \
      -Wl,-rpath,/usr/local/openresty/openssl/lib \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install_sw \
    && cd /tmp \
    && curl -sfSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && cd /tmp/pcre-${RESTY_PCRE_VERSION} \
    && ./configure \
        --prefix=/usr/local/openresty/pcre \
        --disable-cpp \
        --enable-jit \
        --enable-utf \
        --enable-unicode-properties \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && curl -sfSL https://github.com/leev/ngx_http_geoip2_module/archive/${RESTY_GEOIP2_VERSION}.tar.gz -o ngx_http_geoip2_module-${RESTY_GEOIP2_VERSION}.tar.gz \
    && tar xzf ngx_http_geoip2_module-${RESTY_GEOIP2_VERSION}.tar.gz \
    && cd /tmp \
    && curl -sfSL https://github.com/openresty/openresty/releases/download/v${RESTY_VERSION}/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && eval ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${_RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS} ${RESTY_LUAJIT_OPTIONS} \
             --add-module=/tmp/ngx_http_geoip2_module-${RESTY_GEOIP2_VERSION} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && if [ -n "${RESTY_EVAL_POST_MAKE}" ]; then eval $(echo ${RESTY_EVAL_POST_MAKE}); fi \
    && rm -rf \
        openssl-${RESTY_OPENSSL_VERSION}.tar.gz openssl-${RESTY_OPENSSL_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
        ngx_http_geoip2_module-${RESTY_GEOIP2_VERSION}.tar.gz ngx_http_geoip2_module-${RESTY_GEOIP2_VERSION} \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
    && strip /usr/local/openresty/nginx/sbin/nginx \
    && strip /usr/local/openresty/nginx/modules/*.so \
    && apk del .build-deps \
    && apk add --no-cache tzdata \
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

