FROM node:14.2.0-alpine3.11 as api-compiler

ARG GITLAB_SHA=f93e3932

RUN apk add --no-cache \
        curl \
    && npm -g config set user root \
    && npm -g install apidoc \
    && curl -fsL https://gitlab.softwarelibre.gob.bo/api/v4/projects/64/repository/archive.tar.gz\?sha\=$GITLAB_SHA -o jacobitus.tar.gz \
    && tar -xf jacobitus.tar.gz \
    && mv jacobitus-$GITLAB_SHA-* jacobitus \
    && apidoc -i /jacobitus/source/Fido/src/main/java/gob/adsib/fido/server/end_points/ -o /jacobitus/source/Fido/apidoc/

FROM openjdk:8-jdk-alpine3.9 as builder

WORKDIR /jacobitus

COPY --from=api-compiler /jacobitus ./

RUN apk add --no-cache --virtual .build-deps \
        maven \
    && sed -i 's~/usr/lib/ePass2003-Linux-x64/redist/libcastle.so.1.0.0~/usr/lib/pkcs11/opensc-pkcs11.so~g' /jacobitus/source/FidoMonitor/drivers.json \
    && sed -i 's~/usr/lib/ePass2003-Linux-x64/redist/libcastle.so.1.0.0~/usr/lib/pkcs11/opensc-pkcs11.so~g' /jacobitus/instaladores/linux/files_agencia/fido_files/drivers.json \
    && cd /jacobitus/source/FidoModuleAbstract \
    && mvn clean install \
    && cd /jacobitus/source/Fido \
    && mvn clean install \
    && cd /jacobitus/source/FidoMonitor \
    && mvn clean install \
    && mkdir -p /usr/Fido-build \
    && cd /usr/Fido-build \
    && cp /jacobitus/source/Fido/application.properties application.properties \
    && cp /jacobitus/source/Fido/firmadigital_bo.pem firmadigital_bo.pem \
    && cp /jacobitus/source/Fido/target/fido.jar fido.jar \
    && cp /jacobitus/source/FidoMonitor/drivers.json drivers.json \
    && cp /jacobitus/source/FidoMonitor/fido.properties fido.properties \
    && cp /jacobitus/source/FidoMonitor/perfiles_certificado.json perfiles_certificado.json \
    && cp /jacobitus/source/FidoMonitor/target/monitor.jar monitor.jar \
    && cp -r /jacobitus/source/Fido/apidoc/ apidoc/

FROM alpine:3.12

LABEL maintainer="Carlos Remuzzi carlosremuzzi@gmail.com"

COPY entrypoint.sh /usr/local/bin/entrypoint
COPY --from=builder /usr/Fido-build /usr/lib/fido

WORKDIR /usr/lib/fido

RUN apk add --no-cache \
        ccid \
        opensc \
        openjdk8-jre \
        pcsc-lite \
        ttf-dejavu \
        tzdata \
    && sed -i 's~jre\/bin\/java~/usr/bin/java~g' fido.properties \
    && sed -i 's~opensc\.driver_enabled=false~opensc.driver_enabled=true~g' application.properties \
    && adduser -u 1000 -D fido \
    && mkdir -p /run/pcscd \
    && chown -R fido:fido /run/pcscd

USER fido

ENTRYPOINT ["entrypoint"]

CMD ["java","-jar","monitor.jar"]
