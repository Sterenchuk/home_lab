#master

k -n database exec -it deploy/postgres -- psql -U postgres -c "CREATE USER nextcloud WITH PASSWORD 'PASSWORD';" -c "CREATE DATABASE nextcloud OWNER nextcloud;"

#mac
sudo mkdir -p /mnt/nas/nextcloud