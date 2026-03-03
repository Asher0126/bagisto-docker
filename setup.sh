#!/bin/bash

# export user id and user name
export HOST_UID=$(id -u)
export HOST_USER=$(id -un)

# just to be sure that no traces left
docker-compose down -v

# building and running docker-compose file
docker-compose build && docker-compose up -d

# container id by image name
apache_container_id=$(docker ps -aqf "name=bagisto-php-apache")
db_container_id=$(docker ps -aqf "name=bagisto-mysql")

echo "Cloning bagisto on host into ./workspace/bagisto ..."
mkdir -p ./workspace
if [ ! -d "./workspace/bagisto/.git" ]; then
  git clone git@github.com:Asher0126/bagisto.git ./workspace/bagisto
else
  echo "Repo already exists, fetching latest..."
  (cd ./workspace/bagisto && git fetch --all --prune)
fi

# checking connection
echo "Please wait... Waiting for MySQL connection..."
while ! docker exec ${db_container_id} mysql --user=root --password=root -e "SELECT 1" >/dev/null 2>&1; do
    sleep 1
done

# creating empty database for bagisto
echo "Creating empty database for bagisto..."
while ! docker exec ${db_container_id} mysql --user=root --password=root -e "CREATE DATABASE IF NOT EXISTS bagisto CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null 2>&1; do
    sleep 1
done

# creating empty database for bagisto testing
echo "Creating empty database for bagisto testing..."
while ! docker exec ${db_container_id} mysql --user=root --password=root -e "CREATE DATABASE IF NOT EXISTS bagisto_testing CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" >/dev/null 2>&1; do
    sleep 1
done

# setting up bagisto
echo "Now, setting up Bagisto..."

# setting bagisto stable version
echo "Now, setting up Bagisto stable version..."
(cd ./workspace/bagisto && git reset --hard 2.3)

# installing composer dependencies inside container
docker exec -i ${apache_container_id} bash -c "cd /var/www/html/bagisto && composer install"

cp .configs/.env ./workspace/bagisto/.env
cp .configs/.env.testing ./workspace/bagisto/.env.testing

# executing final commands
docker exec -i ${apache_container_id} bash -c "cd /var/www/html/bagisto && php artisan bagisto:install --skip-env-check --skip-admin-creation"
