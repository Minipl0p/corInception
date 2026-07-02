FROM debian:bookworm

RUN apt update -y && apt upgrade -y && apt install -y nginx openssl && apt install vim -y && apt install curl -y 

RUN mkdir -p /etc/nginx/ssl
RUN openssl req -x509 -nodes -out /etc/nginx/ssl/certificate.crt -keyout /etc/nginx/ssl/certificate.key -subj "/C=FR/ST=NA/L=Angouleme/O=42/OU=42/CN=pchazalm.42.fr/UID=pchazalm"

RUN mkdir -p /var/run/nginx
COPY ./conf/nginx.conf /etc/nginx/conf.d

#SET PORT 443 FOR INTERNET LIKE SUBJECT ASK
EXPOSE 443

RUN chmod 755 /var/www/html
RUN chown -R www-data:www-data /var/www/html

#LAUNCH NGINX ("-g" ALLOW FOR EDIT THE MAIN FILE CONFIG ; "daemon off" ALLOW NGINX TO RUN IN THE FOREGROUND)
CMD ["nginx", "-g", "daemon off;"]
