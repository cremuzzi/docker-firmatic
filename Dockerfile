FROM openjdk:8-jdk-alpine3.9 as builder

LABEL maintainer="Carlos Remuzzi carlosremuzzi@gmail.com"

ARG GITLAB_SHA=a3657070

RUN apk add --no-cache --virtual .build-deps \
        curl \
    && curl -fsL https://gitlab.softwarelibre.gob.bo/api/v4/projects/369/repository/archive.tar.gz\?sha\=$GITLAB_SHA -o firmatic.tar.gz \
    && tar -xf firmatic.tar.gz \
    && mv agetic-dss-firmador-servidor-* firmatic \
    && cd firmatic \
    && ./gradlew build

FROM alpine:3.12

LABEL maintainer="Carlos Remuzzi carlosremuzzi@gmail.com"

COPY entrypoint.sh /usr/local/bin/entrypoint
COPY --from=builder /firmatic/build/libs/ /usr/lib/firmatic

WORKDIR /usr/lib/firmatic

RUN apk add --no-cache \
        ccid \
        opensc \
        openjdk8-jre \
        pcsc-lite \
        ttf-dejavu \
        tzdata \
    && adduser -u 1000 -D firmatic \
    && mkdir -p /run/pcscd \
    && chown -R firmatic:firmatic /run/pcscd

USER firmatic

ENTRYPOINT ["entrypoint"]

CMD ["java","-jar","firmador-servidor.jar"]
