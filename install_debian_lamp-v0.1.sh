#!/bin/bash

#Change to username you want
siteuser="some_user"
sitepass="some_pass"

#installation of packages

export DEBIAN_FRONTEND=noninteractive
apt-get -y install mysql-server apache2 apache2-suexec-custom libapache2-mod-fcgid libapache2-mod-rpaf php5-cgi php5-mysql php5-common php5-gd php5-mcrypt php5-imap php5-ldap php5-odbc php5-xmlrpc  php5-curl libmysqlclient15-dev sqlite php5-sqlite libjpeg62 libjpeg62-dev libfreetype6 libfreetype6-dev zlib1g-dev libpng-dev imagemagick php5-imagick ffmpeg php5-ffmpeg unzip libdatetime-perl libdbi-perl libdbd-mysql-perl libclass-autouse-perl libhtml-template-perl libimage-size-perl libmime-lite-perl libmime-perl libnet-dns-perl liburi-perl libhtml-tagset-perl libhtml-parser-perl libwww-perl libwww-perl libgd-gd2-perl libmailtools-perl libunicode-maputf8-perl libxml-simple-perl libio-stringy-perl  libcaptcha-recaptcha-perl libdigest-hmac-perl  libgd-graph-perl librpc-xml-perl libsoap-lite-perl libxml-rss-perl libstring-crc32-perl libxml-atom-perl libmath-bigint-gmp-perl liburi-fetch-perl libcrypt-dh-perl perlmagick libclass-accessor-perl libclass-trigger-perl libclass-data-inheritable-perl libgnupg-interface-perl libmail-gnupg-perl libtext-vcard-perl

#enabling modules in apache

a2enmod rewrite suexec include fcgid actions rpaf
service apache2 restart

#enabling cgi in php.ini

sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=1/g' /etc/php5/cgi/php.ini

#adding php fix path info in fcgid.conf

cat > /etc/apache2/mods-available/fcgid.conf <<END
<IfModule mod_fcgid.c>
  AddHandler    fcgid-script .fcgi
  FcgidConnectTimeout 200
  FcgidMaxRequestLen 15728640
  FcgidFixPathinfo 1
</IfModule>
END

# PHP_Fix_Pathinfo_Enable 1

# creating /var/www/cgi-bin directory and setting permission to /var/www

mkdir -p /var/www/cgi-bin
groupadd $siteuser
useradd -s /bin/bash -d /var/www -m -g $siteuser $siteuser
chown -R $siteuser:$siteuser /var/www

#setting up password for user

cat >/tmp/$siteuser.passwd<<eof
$siteuser:$sitepass
eof

chpasswd < /tmp/$siteuser.passwd
rm -rf /tmp/$siteuser.passwd

#creating fcgi runner script

cat >> /var/www/cgi-bin/php.fcgi <<END
#!/bin/bash
PHP_CGI=/usr/bin/php-cgi
PHP_FCGI_CHILDREN=4
PHP_FCGI_MAX_REQUESTS=2000
export PHP_FCGI_CHILDREN
export PHP_FCGI_MAX_REQUESTS
exec PHP_CGI
END

sed -i 's/exec PHP_CGI/exec $PHP_CGI/g' /var/www/cgi-bin/php.fcgi

# setting permission on php.fcgi

chmod 755 /var/www/cgi-bin/php.fcgi
chown -R $siteuser:$siteuser /var/www/cgi-bin/php.fcgi

# creating apache virtual host configuration

cat > /etc/apache2/sites-available/default <<END
<VirtualHost *:80>
	ServerAdmin webmaster@localhost

	DocumentRoot /var/www
	DirectoryIndex index.html index.htm index.php index.phtml index.php5 default.html default.php default.phtml default.php5
	SuexecUserGroup $siteuser $siteuser

	<Directory /var/www>
		Options FollowSymLinks MultiViews +ExecCGI
		AllowOverride All
		AddHandler php5-fastcgi .php .phtml .php5
		Action php5-fastcgi /cgi-bin/php.fcgi
		Order allow,deny
		allow from all
	</Directory>

	ScriptAlias /cgi-bin/ /var/www/cgi-bin/
	<Directory "/var/www/cgi-bin">
		AllowOverride All
		Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
		Order allow,deny
		Allow from all
	</Directory>

	ErrorLog ${APACHE_LOG_DIR}/error.log

	# Possible values include: debug, info, notice, warn, error, crit,
	# alert, emerg.
	LogLevel warn

	CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
END

#installation of ioncube

cd /usr/local/src/
wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
tar xzvf ioncube_loaders_lin_x86-64.tar.gz
cd ioncube
mkdir /usr/local/ioncube
cp /usr/local/src/ioncube/ioncube_loader_lin_5.4.so /usr/local/ioncube/
cd ..
rm -rf /usr/local/src/ioncube_loaders_lin_x86-64.tar.gz
rm -rf /usr/local/src/ioncube
echo "zend_extension = /usr/local/ioncube/ioncube_loader_lin_5.4.so" >> /etc/php5/cgi/php.ini
/etc/init.d/apache2 restart

# php version check
sed -i 's/expose_php = On/expose_php = Off/g' /etc/php5/cgi/php.ini

# disable allow_url_fopen
sed -i 's/allow_url_fopen = On/allow_url_fopen = Off/g' /etc/php5/cgi/php.ini

# apache version check
sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf.d/security
sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf.d/security

/etc/init.d/apache2 restart

echo "========================================================================="
echo "Installation Completed for LAMP with PHP-CGI "
echo "========================================================================="
echo ""
echo "/var/www/"
echo "Username: $siteuser"
echo "Password: $sitepass"
echo ""
echo "========================================================================="
