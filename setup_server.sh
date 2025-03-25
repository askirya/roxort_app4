#!/bin/bash

# Обновление системы
echo "Обновление системы..."
apt update
apt upgrade -y

# Установка базовых инструментов
echo "Установка базовых инструментов..."
apt install -y curl wget gnupg

# Добавление репозитория MongoDB
echo "Добавление репозитория MongoDB..."
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list

# Добавление репозитория Node.js
echo "Добавление репозитория Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -

# Обновление списка пакетов
apt update

# Установка системных зависимостей
echo "Установка системных зависимостей..."
while read -r line; do
    if [[ ! "$line" =~ ^#.*$ ]] && [ ! -z "$line" ]; then
        echo "Установка $line..."
        apt install -y "$line"
    fi
done < system_requirements.txt

# Установка PM2 глобально
echo "Установка PM2..."
npm install -g pm2

# Запуск и включение MongoDB
echo "Настройка MongoDB..."
systemctl start mongod
systemctl enable mongod

# Создание директории для приложения
echo "Настройка директорий..."
mkdir -p /var/www/roxort-coin
chown -R www-data:www-data /var/www/roxort-coin

# Настройка Nginx
echo "Настройка Nginx..."
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

cat > /etc/nginx/sites-available/roxort-coin << 'EOL'
server {
    listen 80;
    server_name d3aef028639d.vps.myjino.ru;

    location / {
        root /var/www/roxort-coin/public;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /ws {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }
}
EOL

# Активация конфигурации Nginx
ln -sf /etc/nginx/sites-available/roxort-coin /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Перезапуск Nginx
systemctl restart nginx

# Установка Node.js зависимостей
echo "Установка Node.js зависимостей..."
cd /var/www/roxort-coin
npm install

# Запуск приложения через PM2
echo "Запуск приложения..."
cd /var/www/roxort-coin/server
pm2 start server.js --name "roxort-coin-api"
pm2 save
pm2 startup

echo "Настройка сервера завершена!" 