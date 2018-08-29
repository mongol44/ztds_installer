#!/bin/bash

ztds_version = 'ztds_v0.7.3'

read -p 'Enter domain name (e.g. site.ru) and press [ENTER]:' domain </dev/tty

firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload

yum install -y epel-release p7zip nginx php-fpm php-cli php-gd php-ldap php-odbc php-pdo php-pecl-memcache php-pear php-xml php-xmlrpc php-mbstring php-snmp php-soap

sh -c 'user nginx;\nworker_processes auto;\nerror_log /var/log/nginx/error.log;\npid /run/nginx.pid;\n\ninclude /usr/share/nginx/modules/*.conf;\n\nevents {\n	worker_connections 1024;\n}\n\nhttp {\n	# Cloudflare https://www.cloudflare.com/ips\n	set_real_ip_from   103.21.244.0/22;\n	set_real_ip_from   103.22.200.0/22;\n	set_real_ip_from   103.31.4.0/22;\n	set_real_ip_from   104.16.0.0/12;\n	set_real_ip_from   108.162.192.0/18;\n	set_real_ip_from   131.0.72.0/22;\n	set_real_ip_from   141.101.64.0/18;\n	set_real_ip_from   162.158.0.0/15;\n	set_real_ip_from   172.64.0.0/13;\n	set_real_ip_from   173.245.48.0/20;\n	set_real_ip_from   188.114.96.0/20;\n	set_real_ip_from   190.93.240.0/20;\n	set_real_ip_from   197.234.240.0/22;\n	set_real_ip_from   198.41.128.0/17;\n	#set_real_ip_from   2400:cb00::/32;\n	#set_real_ip_from   2606:4700::/32;\n	#set_real_ip_from   2803:f800::/32;\n	#set_real_ip_from   2405:b500::/32;\n	#set_real_ip_from   2405:8100::/32;\n	#set_real_ip_from   2c0f:f248::/32;\n	#set_real_ip_from   2a06:98c0::/29;\n	real_ip_header      CF-Connecting-IP;\n\n	log_format  main  '$remote_addr - $remote_user [$time_local] \"$request\" '\n					  '$status $body_bytes_sent \"$http_referer\" '\n					  '\"$http_user_agent\" \"$http_x_forwarded_for\"';\n\n	#access_log  /var/log/nginx/access.log  main;\n\n	sendfile			on;\n	tcp_nopush			on;\n	tcp_nodelay			on;\n	keepalive_timeout	65;\n	types_hash_max_size 2048;\n\n	include				/etc/nginx/mime.types;\n	default_type		application/octet-stream;\n\n	# Load modular configuration files from the /etc/nginx/conf.d directory.\n	# See http://nginx.org/en/docs/ngx_core_module.html#include\n	# for more information.\n	include /etc/nginx/conf.d/*.conf;\n\n	server {\n		listen 80 default_server;\n		server_name  _;\n		root /usr/share/nginx/html;\n	}\n\n	server {\n		# server IP and port\n		listen 80;\n\n		# domain name\n		server_name $domain www.$domain;\n\n		# root path\n		set $root_path /var/www/html/$domain;\n\n		root $root_path;\n\n		charset utf-8;\n		index index.php;\n\n		location ~* \.(jpg|jpeg|gif|png|js|css|txt|zip|ico|gz|csv)$ {\n			access_log off;\n			expires max;\n		}\n\n		location ~* /(database|ini|keys|lib|log)/.*$ {\n			return 403;\n		}\n\n		location ~* \.(htaccess|ini|txt|db)$ {\n			return 403;\n		}\n\n		location ~ \.php$ {\n			include /etc/nginx/fastcgi_params;\n			fastcgi_pass 127.0.0.1:9000;\n			#fastcgi_pass unix:/var/run/php5-fpm.sock;\n			fastcgi_index index.php;\n			fastcgi_param SCRIPT_FILENAME $root_path$fastcgi_script_name;\n		}\n\n		location / {\n			try_files $uri $uri/ /index.php?$args;\n		}\n	}\n}" > /etc/nginx/nginx.conf'

systemctl enable nginx php-fpm.service

systemctl start nginx php-fpm.service

mkdir -m 777 /var/lib/php/session
mkdir -m 777 /var/www/html/$domain

curl -L -o /tmp/ztds.7z https://github.com/spartanetsru/ztds_installer/blob/master/$ztds_version?raw=true

7za x -o/tmp/ztds /tmp/ztds.7z

rsync -r /tmp/ztds/$ztds_version /var/www/html/$domain

chmod 777 -R /var/www/html/$domain
chown -R nginx:nginx /var/www/html/$domain

rm -rf /tmp/ztds
rm -f /tmp/ztds.7z

echo 'Done'