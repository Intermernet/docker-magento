# Apache, PHP, MySQL, Magento and SSHd installation
#
# Currently gets to working Magento installation without config

# Use Ubuntu 12.04 as base image
FROM ubuntu:precise

MAINTAINER Mike Hughes, intermernet@gmail.com

# Create a random password for root and MySQL and save to "/root/pw.txt"
RUN  < /dev/urandom tr -dc A-Za-z0-9 | head -c${1:-12} > /root/pw.txt

# Change the root password
RUN echo "root:$(cat /root/pw.txt)" | chpasswd

# Add Ubuntu mirrors
RUN echo 'deb mirror://mirrors.ubuntu.com/mirrors.txt precise main universe multiverse' > /etc/apt/sources.list

# Update package lists
RUN apt-get update

# Add MySQL root password to debconf
RUN bash -c "debconf-set-selections <<< 'mysql-server mysql-server/root_password password $(cat /root/pw.txt)'"
RUN bash -c "debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password $(cat /root/pw.txt)'"

# Install packages
RUN apt-get install -y mysql-server mysql-client apache2 php5 php5-curl php5-mcrypt php5-gd php5-mysql openssh-server

# Create the SSHd working directory
RUN mkdir /var/run/sshd

# Enable Apache rewrite module
RUN a2enmod rewrite

# Add the Apache virtual host file
ADD apache_default_vhost /etc/apache2/sites-available/default

# Download Magento
ADD http://www.magentocommerce.com/downloads/assets/1.8.1.0/magento-1.8.1.0.tar.gz /root/

# Extract files and cleanup
RUN tar xzf /root/magento-1.8.1.0.tar.gz -C /root/ && rm /root/magento-*.gz

# Delete old web root and move Magento to web root
RUN rm -fr /var/www && mv /root/magento /var/www

# Change owner of files in web root to "www-data:www-data"
RUN chown www-data:www-data -R /var/www

# Create "/root/run.sh" startup script
RUN bash -c "echo -e \"\x23\x21/bin/bash\nservice apache2 start\nmysqld --log --log-error \x26\n/usr/sbin/sshd -D \x26\nwait \x24\x7b\x21\x7d\n\" > /root/run.sh"

# Change "/root/run.sh" to be executable
RUN chmod +x /root/run.sh

# Create the "magento" database
RUN (mysqld &) ; sleep 5 && mysql -u root -p$(cat /root/pw.txt) -e "CREATE DATABASE magento;" ; kill -TERM $(cat /var/run/mysqld/mysqld.pid)

# Display the password and delete "/root/pw.txt"
RUN bash -c "echo -e \"\n*********************************\nRecord the root / MySQL Password\x21\";echo $(cat /root/pw.txt);echo -e \"*********************************\n\"; rm -f /root/pw.txt"

# Set the entry point to "/root/run.sh"
ENTRYPOINT ["/root/run.sh"]

# Expose SSH and HTTP ports
EXPOSE 22 80
