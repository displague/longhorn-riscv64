# longhorn-ui: upstream's image, byte for byte, except /usr/sbin/nginx is replaced with a fixed nginx.
# Upstream builds on SLE BCI 15.7 and installs its nginx package (1.21.5-150600.10.27.1); SUSE's fixed
# package (10.30.1) is not in the public BCI repository. Same libc/openssl/pcre2 as the base, so the
# binary links against the image's own libraries. UI files, nginx.conf.template, start script, user: untouched.
ARG BASE=docker.io/longhornio/longhorn-ui:v1.13.0@sha256:f22fb0254ae50195c1635ce428dfae26375956b3d7bd39640fae8fe33a236023
ARG BUILDER=registry.suse.com/bci/bci-base:15.7@sha256:8cd100ae2ec5ab23d6ec7aa1c0fe2dc30ca852c609406097797c9d298b7decdd
ARG NGINX_VERSION=1.30.7
ARG NGINX_SHA256=2565b5c837050e958f70fb0f73c48e2bca4542ad349fd356f46fb0c72610bc6e

FROM ${BUILDER} AS build
ARG NGINX_VERSION
ARG NGINX_SHA256
RUN zypper -n install gcc make tar gzip curl pcre2-devel libopenssl-devel zlib-devel
RUN curl -fsSL -o nginx.tar.gz https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
 && echo "${NGINX_SHA256}  nginx.tar.gz" | sha256sum -c - \
 && tar xzf nginx.tar.gz
# Same paths as the distro build; only what the Longhorn UI config uses plus TLS, no HTTP/2, HTTP/3, mail or stream.
RUN cd nginx-${NGINX_VERSION} && ./configure \
      --prefix=/usr/ --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules \
      --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log \
      --http-log-path=/var/log/nginx/access.log --pid-path=/run/nginx.pid --lock-path=/run/nginx.lock \
      --http-client-body-temp-path=/var/lib/nginx/tmp/ --http-proxy-temp-path=/var/lib/nginx/proxy/ \
      --http-fastcgi-temp-path=/var/lib/nginx/fastcgi/ --http-uwsgi-temp-path=/var/lib/nginx/uwsgi/ \
      --http-scgi-temp-path=/var/lib/nginx/scgi/ --user=nginx --group=nginx \
      --with-threads --with-file-aio --with-http_ssl_module --with-http_realip_module \
      --with-http_sub_module --with-http_gunzip_module --with-http_gzip_static_module \
      --with-http_stub_status_module --with-pcre --with-pcre-jit \
 && make -j"$(nproc)" && make install DESTDIR=/out && /out/usr/sbin/nginx -V 2>&1 | head -1

FROM ${BASE}
COPY --from=build /out/usr/sbin/nginx /usr/sbin/nginx
