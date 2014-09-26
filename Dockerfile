FROM ubuntu:14.04
 
RUN apt-get update

#Runit
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y runit 
CMD /usr/sbin/runsvdir-start

#SSHD
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server &&	mkdir -p /var/run/sshd && \
    echo 'root:root' |chpasswd
RUN sed -i "s/session.*required.*pam_loginuid.so/#session    required     pam_loginuid.so/" /etc/pam.d/sshd
RUN sed -i "s/PermitRootLogin without-password/#PermitRootLogin without-password/" /etc/ssh/sshd_config

#Utilities
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y vim less net-tools inetutils-ping curl git telnet nmap socat dnsutils netcat tree htop unzip sudo software-properties-common

#Add runit services
ADD sv /etc/service 

#******************************* Installing Azkaban requirements ********************************************************
#MySQL
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server && \
    sed -i -e "s|127.0.0.1|0.0.0.0|g" -e "s|max_allowed_packet.*|max_allowed_packet = 1024M|" /etc/mysql/my.cnf

#Install Oracle Java 7
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python-software-properties && \
    add-apt-repository ppa:webupd8team/java -y && \
    DEBIAN_FRONTEND=noninteractive apt-get update && \
    echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y oracle-java7-installer

#Azkaban Web Server
RUN wget https://s3.amazonaws.com/azkaban2/azkaban2/2.5.0/azkaban-web-server-2.5.0.tar.gz && \
    tar xf azkaban-web-server-*.tar.gz && \
    rm azkaban-web-server-*.tar.gz

#Azkaban Executor Server
RUN wget https://s3.amazonaws.com/azkaban2/azkaban2/2.5.0/azkaban-executor-server-2.5.0.tar.gz && \
    tar xf azkaban-executor-server-*.tar.gz && \
    rm azkaban-executor-server-*.tar.gz

#Azkaban MySQL scripts
RUN wget https://s3.amazonaws.com/azkaban2/azkaban2/2.5.0/azkaban-sql-script-2.5.0.tar.gz && \
    tar xf azkaban-sql-script-*.tar.gz && \
    rm azkaban-sql-script-*.tar.gz

#MySQL JDBC driver
RUN wget -O /azkaban-web-2.5.0/extlib/mysql-connector-java-5.1.26.jar http://search.maven.org/remotecontent?filepath=mysql/mysql-connector-java/5.1.26/mysql-connector-java-5.1.26.jar && cp /azkaban-web-2.5.0/extlib/mysql-connector-java-5.1.26.jar /azkaban-executor-2.5.0/extlib/mysql-connector-java-5.1.26.jar

#Configure
RUN mkdir /tmp/web && sed -i -e "s|^tmpdir=|tmpdir=/tmp/web|" -e "s|&||" /azkaban-web-2.5.0/bin/azkaban-web-start.sh && \
    mkdir /tmp/executor && sed -i -e "s|^tmpdir=|tmpdir=/tmp/executor|" -e "s|&||" /azkaban-executor-2.5.0/bin/azkaban-executor-start.sh && \
    sed -i -e "s|^executor.global.properties.*|executor.global.properties=/azkaban-executor-2.5.0/conf/global.properties|" -e "s|^user.manager.xml.file.*|user.manager.xml.file=/azkaban-web-2.5.0/conf/azkaban-users.xml|" /azkaban-web-2.5.0/conf/azkaban.properties &&\
    sed -i -e "s|^executor.global.properties.*|executor.global.properties=/azkaban-executor-2.5.0/conf/global.properties|" -e "s|azkaban2|azkaban|" /azkaban-executor-2.5.0/conf/azkaban.properties &&\
    sed -i -e "s|azkaban.project.dir.*|azkaban.project.dir=/docker/projects|" /azkaban-web-2.5.0/conf/azkaban.properties &&\
    sed -i -e "s|azkaban.project.dir.*|azkaban.project.dir=/docker/projects|" /azkaban-executor-2.5.0/conf/azkaban.properties &&\
    cd /etc/service/azkaban-web && \
    keytool -keystore keystore -alias jetty -genkey -keyalg RSA -keypass password -storepass password -dname "CN=Unknown, OU=Unknown, O=Unknown,L=Unknown, ST=Unknown, C=Unknown" && \
    cp -r keystore /azkaban-web-2.5.0/

#Personalization
RUN sed -i -e "s|azkaban.name.*|/azkaban.name=Data Worker|" -e "s|azkaban.label.*|azkaban.label=Power Your Data Scripts|" /azkaban-web-2.5.0/bin/azkaban-web-start.sh

#Init MySql
ADD /azkaban/mysql.ddl mysql.ddl
RUN mysqld & sleep 3 && \
    mysql < mysql.ddl && \
    mysql --database=azkaban < /azkaban-2.5.0/create-all-sql-2.5.0.sql && \
    mysqladmin shutdown



## ************************** Installing Python requirements ****************************************************
##Required by Python packages
#RUN DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential python-dev python-pip liblapack-dev libatlas-dev gfortran libfreetype6 libfreetype6-dev libpng12-dev python-lxml libyaml-dev g++ libffi-dev pkg-config
#
##Upgrade pip
#RUN pip install -U setuptools
#RUN pip install -U pip
##matplotlib needs latest distribute
#RUN pip install -U distribute
#
##Pandas
#RUN pip install pandas
##Optional
#RUN pip install cython
#RUN pip install jinja2 pyzmq tornado
#RUN pip install numexpr bottleneck scipy pygments matplotlib sympy pymc
#RUN pip install patsy
#RUN pip install statsmodels
#RUN pip install beautifulsoup4 html5lib
##Pattern
#RUN pip install --allow-external pattern
##NLTK
#RUN pip install pyyaml nltk
##Networkx
#RUN pip install networkx
##Biopython
#RUN pip install biopython
#
##Install R 3+
#RUN echo 'deb http://cran.rstudio.com/bin/linux/ubuntu trusty/' > /etc/apt/sources.list.d/r.list
#RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
#RUN apt-get update
#RUN apt-get install -y r-base
##Rmagic
#RUN pip install rpy2
#
##Vincent
#RUN pip install vincent
#
##Scikit-learn
#RUN pip install -U scikit-learn
##PyMongo
#RUN pip install pymongo
#
EXPOSE 22 8443


