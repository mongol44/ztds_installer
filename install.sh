#!/bin/bash

ztds_version='ztds_v0.7.3'

clear

read -p 'Enter domain name (e.g. site.ru) and press [ENTER]: ' domain </dev/tty

firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload

yum install -y epel-release
yum install -y p7zip nginx php-fpm php-cli php-gd php-ldap php-odbc php-pdo php-pecl-memcache php-pear php-xml php-xmlrpc php-mbstring php-snmp php-soap

/bin/cat <<EOM >/etc/nginx/nginx.conf
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
	worker_connections 1024;
}

http {
	# Cloudflare https://www.cloudflare.com/ips
	set_real_ip_from   103.21.244.0/22;
	set_real_ip_from   103.22.200.0/22;
	set_real_ip_from   103.31.4.0/22;
	set_real_ip_from   104.16.0.0/12;
	set_real_ip_from   108.162.192.0/18;
	set_real_ip_from   131.0.72.0/22;
	set_real_ip_from   141.101.64.0/18;
	set_real_ip_from   162.158.0.0/15;
	set_real_ip_from   172.64.0.0/13;
	set_real_ip_from   173.245.48.0/20;
	set_real_ip_from   188.114.96.0/20;
	set_real_ip_from   190.93.240.0/20;
	set_real_ip_from   197.234.240.0/22;
	set_real_ip_from   198.41.128.0/17;
	#set_real_ip_from   2400:cb00::/32;
	#set_real_ip_from   2606:4700::/32;
	#set_real_ip_from   2803:f800::/32;
	#set_real_ip_from   2405:b500::/32;
	#set_real_ip_from   2405:8100::/32;
	#set_real_ip_from   2c0f:f248::/32;
	#set_real_ip_from   2a06:98c0::/29;
	real_ip_header      CF-Connecting-IP;

	log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
					  '\$status \$body_bytes_sent "\$http_referer" '
					  '"\$http_user_agent" "\$http_x_forwarded_for"';

	#access_log  /var/log/nginx/access.log  main;

	sendfile			on;
	tcp_nopush			on;
	tcp_nodelay			on;
	keepalive_timeout	65;
	types_hash_max_size 2048;

	include				/etc/nginx/mime.types;
	default_type		application/octet-stream;

	# Load modular configuration files from the /etc/nginx/conf.d directory.
	# See http://nginx.org/en/docs/ngx_core_module.html#include
	# for more information.
	include /etc/nginx/conf.d/*.conf;

	server {
		listen 80 default_server;
		server_name  _;
		root /usr/share/nginx/html;
	}

	server {
		# server IP and port
		listen 80;

		# domain name
		server_name $domain www.$domain;

		# root path
		set \$root_path /var/www/html/$domain;

		root \$root_path;

		charset utf-8;
		index index.php;

		location ~* \.(jpg|jpeg|gif|png|js|css|txt|zip|ico|gz|csv)\$ {
			access_log off;
			expires max;
		}

		location ~* /(database|ini|keys|lib|log)/.*\$ {
			return 403;
		}

		location ~* \.(htaccess|ini|txt|db)\$ {
			return 403;
		}

		location ~ \.php\$ {
			include /etc/nginx/fastcgi_params;
			fastcgi_pass 127.0.0.1:9000;
			#fastcgi_pass unix:/var/run/php5-fpm.sock;
			fastcgi_index index.php;
			fastcgi_param SCRIPT_FILENAME \$root_path\$fastcgi_script_name;
		}

		location / {
			try_files \$uri \$uri/ /index.php?\$args;
		}
	}
}
EOM

systemctl enable nginx php-fpm.service
systemctl restart nginx php-fpm.service

mkdir -m 777 /var/lib/php/session
mkdir -m 777 /var/www/html/$domain

rm -rf /tmp/ztds
rm -f /tmp/ztds.7z
curl -L -o /tmp/ztds.7z https://github.com/spartanetsru/ztds_installer/blob/master/$ztds_version.7z?raw=true
7za x -o/tmp/ztds /tmp/ztds.7z
cp -a /tmp/ztds/$ztds_version/. /var/www/html/$domain
chmod 777 -R /var/www/html/$domain
chown -R nginx:nginx /var/www/html/$domain
rm -rf /tmp/ztds
rm -f /tmp/ztds.7z

password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
password_md5=$(echo -n "$password" | md5sum | cut -f1 -d' ')
api_key=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)
postback_key=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)
new_admin_php=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)

mv /var/www/html/$domain/admin.php /var/www/html/$domain/$new_admin_php.php

/bin/cat <<EOM >/var/www/html/$domain/config.php
<?php
/********************************************\
| Telegram-канал: https://t.me/z_tds         |
| Вход в админку: admin.php (admin/admin)    |
| Сгенерировать хэш MD5: application/md5.php |
\********************************************/
if(!defined("INDEX")){header('HTTP/1.1 403 Forbidden'); die('403 Forbidden');}
date_default_timezone_set('Europe/Moscow');//временная зона (http://php.net/manual/ru/timezones.php)
\$login = 'admin';//логин
\$pass = '$password_md5';//пароль в md5
\$ip_allow = '';//разрешить доступ к админке только с этого IP (IP в md5). Оставьте пустым если блокировка по IP не нужна
\$auth = 1;//использовать для авторизации куки или сессии (0/1)
\$language = 'ru';//язык (ru/uk/en)
\$api_key = '$api_key';//API ключ ([a-Z0-9] (не забудьте его прописать в api.php)
\$postback_key = '$postback_key';//postback ключ
\$trash = 'http://www.ru';//url куда будем сливать весь мусор (переходы в несуществующие группы). Если \$trash = ''; то будет показана пустая страница
\$ini_folder = 'ini';//название папки с файлами .ini
\$admin_page = '$new_admin_php.php';//название файла админки (если будете менять не забудьте переименовать сам файл!)
\$folder = '';//для работы zTDS в папке укажите ее название, например \$folder = 'folder'; или \$folder = 'folder1/folder2'; если папка в папке
\$keys_folder = 'keys';//название папки для сохранения ключевых слов (http://tds.com/keys)
\$log_folder = 'log';//название папки с логами (http://tds.com/log)
\$log_days = 15;//показывать в админке ссылки на логи за последние 15 дней (должно быть не больше чем \$log_save)
\$log_save = 15;//хранить в БД логи за последние 15 дней
\$log_limit = 500;//показывать первые 500 записей при просмотре логов
\$log_bots = 1;//сохранять в логах ботов (0/1)
\$log_out = 'api,iframe,javascript,show_page_html,show_text';//не сохранять в логах ауты для этих типов редиректа
\$log_ref = 1;//сохранять в логах рефереры (0/1)
\$log_ua = 1;//сохранять в логах юзерагенты (0/1)
\$log_fs = 15;//размер шрифта в логах
\$chart_days = 15;//показывать график за последние 15 дней (должно быть не больше чем \$log_save)
\$chart_weight = 200;//высота графика в пикселях
\$chart_bots = 1;//показывать статистику ботов в графиках (0/1)
\$stat_uniq = 1;//показывать в статистике хиты или уники (0/1)
\$stat_rm = 1;//показывать правое меню (0/1)
\$stat_op = 1;//типы статистики в "Источниках" (0 - хиты+уники+WAP; 1 - хиты+уники+устройства+WAP;)
\$n_cookies = 'cu';//название cookies
\$caplen = 6;//количество букв в каптче (0 - каптча отключена)
\$ipgrabber_token = '';//API ключ от IPGrabber
\$ipgrabber_update = 0;//каждые 360 минут обновлять список ботов IPGrabber (0 - обновление отключено)
\$curl_ua = 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:56.0) Gecko/20100101 Firefox/56.0';//useragent для CURL
\$disable_tds = 0;//отключить TDS (0/1)
\$error_log = 1;//сохранение ошибок PHP в файле php_errors.log (0/1)
\$display_errors = 0;//вывод ошибок PHP на экран (0/1)
\$cid_length = 10;//длина CID для постбэка
/*Ниже ничего не изменяйте*/
\$timeout = 60000;
\$debug = 0;
\$empty = '-';
\$version = 'v.0.7.3';
?>
EOM

echo ''
echo '-------------------------------------------------'
echo ''

echo "url: http://$domain/$new_admin_php.php"
echo "username: admin"
echo "password: $password"
echo "api_key: $api_key"
echo "postback_key: $postback_key"

echo ''
echo '-------------------------------------------------'
echo ''
echo 'Done'