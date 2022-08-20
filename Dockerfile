FROM arm32v7/node:18-alpine3.15 AS frontend-builder
COPY frontend/ /app
RUN apk add --update python3 make gcc g++ git && rm -rf /var/cache/apk/*
RUN cd /app && npm install && npm run build

FROM golang:1.19 AS backend-builder
RUN go install github.com/gobuffalo/packr/v2/packr2@latest
COPY --from=frontend-builder /app/static /app/frontend/static
COPY . /app
RUN apt-get update && apt-get install -y gcc-aarch64-linux-gnu
RUN cd /app && packr2 && env CC=aarch64-linux-gnu-gcc CGO_ENABLED=1 GOOS=linux GOARCH=arm64 go build -a -tags netgo -ldflags '-linkmode external -extldflags -static -s -w' -o ovpn-admin && packr2 clean

FROM alpine:3.14
WORKDIR /app
COPY --from=backend-builder /app/ovpn-admin /app
RUN apk add --update bash easy-rsa openssl openvpn  && \
    ln -s /usr/share/easy-rsa/easyrsa /usr/local/bin && \
    wget https://github.com/flant/ovpn-admin/releases/download/1.7.5/ovpn-admin-linux-arm.tar.gz -O - | tar xz -C /usr/local/bin && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*
