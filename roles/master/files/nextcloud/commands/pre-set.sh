#master

k -n database exec -it deploy/postgres -- psql -U postgres -c "CREATE USER nextcloud WITH PASSWORD 'PASSWORD';" -c "CREATE DATABASE nextcloud OWNER nextcloud;"

#mac
sudo mkdir -p /mnt/nas/nextcloud

#mac t oset the GUI on zotac and keep mount on mac 
sudo apt install nfs-kernel-server
sudo mkdir -p /mnt/nas/nextcloud-data
sudo chown 33:33 /mnt/nas/nextcloud-data
echo '/mnt/nas/nextcloud-data <zotac.ip>(rw,sync,no_subtree_check,no_root_squash)' | sudo tee -a /etc/exports
sudo exportfs -ra