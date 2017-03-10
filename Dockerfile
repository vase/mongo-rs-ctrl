FROM alpine:edge

RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories \
	&& apk add --no-cache mongodb curl \
	&& rm /usr/bin/mongos /usr/bin/mongoperf /usr/bin/mongosniff /usr/bin/mongod

COPY ctrl.sh /root
CMD /root/ctrl.sh
