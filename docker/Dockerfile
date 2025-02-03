FROM docker.io/library/debian:12.8

WORKDIR /IARA

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    zip \
    unzip

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip

COPY IARA_ecs.sh .

ARG IARA_URL
RUN curl -o iara.zip $IARA_URL \ 
    && unzip -qo iara.zip -d iara_model \ 
    && rm iara.zip \ 
    && mkdir /root/.julia \ 
    && ln -s /IARA/iara_model/share/julia/artifacts/ /root/.julia/  

ENV IARA_PATH=/IARA/iara_model/bin

RUN chmod +x IARA_ecs.sh

CMD ["./IARA_ecs.sh"]

