FROM docker.io/library/debian:12.8

WORKDIR /IARA

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip

COPY IARA_ecs.sh .

RUN chmod +x IARA_ecs.sh

CMD ["./IARA_ecs.sh"]