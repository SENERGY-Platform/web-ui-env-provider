FROM nginx:stable-alpine
RUN apk add curl bash
ADD nginx.conf /etc/nginx/conf.d/default.conf
ADD build-env.sh /opt
RUN chmod -R a+r /usr/share/nginx/html
CMD ["bash", "-c", "/opt/build-env.sh && exec nginx -g 'daemon off;'"]
