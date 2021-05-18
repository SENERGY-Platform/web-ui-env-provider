FROM nginx
RUN apt-get update && apt-get install -y curl
ADD nginx.conf /etc/nginx/conf.d/default.conf
ADD build-env.sh /
RUN chmod -R a+r /usr/share/nginx/html
CMD ["/bin/sh",  "-c",  "/build-env.sh && exec nginx -g 'daemon off;'"]
