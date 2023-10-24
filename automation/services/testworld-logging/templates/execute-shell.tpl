#############Execute docker install script#############
sudo apt-get update
chmod 700 /root/docker-install.sh
/root/docker-install.sh >> /root/docker-install.log
mv /root/docker-install.sh /root/docker-install.sh.EXECUTED #prevent it from running again

#############Install Docker network#############
#create a network most containers will use
docker network create internal-log-fetcher-network >> /root/internal-log-fetcher-network.log
docker network ls >> /root/internal-log-fetcher-network.log

#############Execute key install script#############
chmod 700 /root/secret_key.sh
/root/secret_key.sh >> secret_key-install.log
mv /root/secret_key.sh /root/secret_key.sh.EXECUTED

#############Execute node names script#############
chmod 700 /root/node_names.sh
/root/node_names.sh >> node_names-install.log
mv /root/node_names.sh /root/node_names.sh.EXECUTED

#############Create postgres dir#############
chmod 700 /root/postgres_dir.sh
/root/postgres_dir.sh >> postgres_dir-install.log
mv /root/postgres_dir.sh /root/postgres_dir.sh.EXECUTED

#############Bring up docker containers############
mv /root/keys/secret_key.txt /root/keys/secret_key
docker-compose -f /root/docker-compose.yml up -d 
