#!/bin/bash

echo "This process is split into parts"
echo "Task 1 executing"
sudo apt-get update
echo "update completed"
sudo apt-get install -y apache2 mysql-server php libapache2-mod-php php-mysql git
yes | sudo add-apt-repository ppa:ondrej/php
sudo apt update
sudo apt install php8.3 php8.3-curl php8.3-dom php8.3-mbstring php8.3-xml php8.3-mysql php8.3-sqlite3 zip unzip -y
sudo apt-get purge php7.4 php7.4-common -y
sudo apt-get update
sudo a2enmod rewrite
sudo a2enmod php8.3
sudo service apache2 restart
echo "Task 1 done"
echo "--------------------------------------"

MYSQL_COMMANDS=$(cat <<EOF

CREATE USER 'titus'@'localhost' IDENTIFIED BY '12435687';
GRANT ALL PRIVILEGES ON laraveldb . * TO 'titus'@'localhost';
CREATE DATABASE laraveldb;
SHOW DATABASES;
FLUSH PRIVILEGES;
EOF
)
echo "$MYSQL_COMMANDS" | sudo mysql -u root

cd /usr/bin
curl -sS https://getcomposer.org/installer | sudo php
sudo mv composer.phar composer
composer

cd /var/www/
sudo git clone https://github.com/laravel/laravel.git
cd laravel
composer install --optimize-autoloader --no-dev
yes | sudo composer update
sudo cp .env.example .env

DB_HOST="localhost"
DB_DATABASE="laraveldb"
DB_USERNAME="titus"
DB_PASSWORD="12435687"

# Set the path to your .env file
ENV_FILE="/var/www/laravel/.env"

# Alter the .env file
sed -i "s/DB_HOST=.*/DB_HOST=${DB_HOST}/" ${ENV_FILE}
sed -i "s/DB_DATABASE=.*/DB_DATABASE=${DB_DATABASE}/" ${ENV_FILE}
sed -i "s/DB_USERNAME=.*/DB_USERNAME=${DB_USERNAME}/" ${ENV_FILE}
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD}/" ${ENV_FILE}

sudo php artisan key:generate
ps aux | grep "apache" | awk '{print $1}' | grep -v root | head -n 1
sudo chown -R www-data storage
sudo chown -R www-data bootstrap/cache

cd /etc/apache2/sites-available/
sudo touch laravel.conf
sudo chown vagrant:vagrant laravel.conf
chmod +w laravel.conf
sudo cat<<EOF >laravel.conf
<VirtualHost *:80>
ServerName titus@localhost
DocumentRoot /var/www/laravel/public

    <Directory /var/www/laravel/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/laravel-error.log
    CustomLog ${APACHE_LOG_DIR}/laravel-access.log combined

</VirtualHost>
EOF

sudo a2dissite 000-default.conf
sudo a2ensite laravel.conf
apache2ctl -t
sudo systemctl restart apache2

sudo touch /var/www/laravel/database/database.sqlite
sudo chown www-data:www-data /var/www/laravel/database/database.sqlite
cd /var/www/laravel/
sudo php artisan migrate
sudo php artisan db:seed
sudo systemctl restart apache2
