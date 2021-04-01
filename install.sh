echo "setup development enviroment"
yum install -y vim wget net-tools
yum install -y git gcc gcc-c++ make cmake autoconf
yum install -y bison ncurses-devel zlib-devel libevent-devel openssl-devel

parse_arg()
{
    echo $1 | sed -e 's/^[^=]*=//'
}
parse_args()
{
  for arg
  do
    case $arg in
      --database=*) database=`parse_arg "$arg"`;;
      --master=*) master=`parse_arg "$arg"`;;
    esac
  done
}

configure_vim()
{
  echo "configure vim for root & $master"
  cd $srcroot
  cp etc/.vimrc /root/.vimrc -f
  cp etc/.vimrc /home/$master/.vimrc -f
}

create_daemon()
{
  groupadd $daemon
  useradd -r -g $daemon -s /bin/false $daemon
}

create_defins()
{
  mkdir -p $insdir
  mkdir -p $datadir
  chown $daemon:$daemon $insdir
  chmod 750 $insdir

  mkdir -p $cnfdir
  cat > $cnfdir"/my.cnf" <<EOF
[mysqld]
bind-address        = 0.0.0.0
port                = 3306
user                = ${daemon}

basedir             = ${basedir}
datadir             = ${datadir}
socket              = ${insdir}/mysql.sock
pid-file            = ${insdir}/mysql.pid

general-log         = 1
general-log-file    = ${insdir}/general.log
log-error           = ${insdir}/error.log
slow-query-log      = 1
log-queries-not-using-indexes = 1
long-query-time     = 2
slow-query-log-file = ${insdir}/slow.log


[mysql]
port=3306
socket=${insdir}/mysql.sock
EOF
}

install_mysql()
{
  # optional: cyrus-sasl openldap
  # yum install -y cyrus-sasl-devel
  # yum install -y openldap-devel
  #################################
  yum install -y libtirpc-devel
  tar zxvf boost* && rm boost*.tar.gz && cd boost* && ./bootstrap.sh && ./b2 && cd ../ && mv boost* /usr/local/boost
  tar xvJf rpcsvc* && rm rpcsvc*.tar.xz && cd rpcsvc* && ./configure --sysconfdir=/etc && make && make install && cd ..
  unzip mysql* && rm mysql*.zip && cd mysql-* && mkdir bld && cd bld && cmake -DWITH_BOOST=/usr/local/boost .. && make && make install

  echo "init mysql data"
  create_daemon
  create_defins
  /usr/local/mysql/bin/mysqld --initialize
  /usr/local/mysql/bin/mysql_ssl_rsa_setup
}

install_maria()
{
  tar zxvf mariadb* && rm mariadb*.tar.gz && cd mariadb-* && mkdir bld && cd bld && 
  cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/maria \
  -DDEFAULT_SYSCONFDIR=/usr/local/maria/etc && make && make install

  echo "init mariadb data"
  create_daemon
  create_defins
  /usr/local/maria/scripts/mariadb-install-db
}

install_db()
{
  local daemon=$database
  local basedir="/usr/local/${database}"
  local cnfdir="${basedir}/etc"
  local insdir="/data/${database}db"
  local datadir="${insdir}/data"

  echo "installing ${database}"
  cd ${srcroot}/db
  install_${database}
}


install_php()
{
  echo "installing php"
  cd ${srcroot}/lang
  yum install -y libxml2-devel
  yum install -y sqlite-devel
  tar zxvf php-*.tar.gz && rm php-*.tar.gz && cd php-* && ./configure --prefix=/usr/local/php \
  --enable-fpm \
  --enable-openssl \
  --enable-zlib && make && make install
  cp php.ini-development /usr/local/php/lib/php.ini
  cp /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf
  cp /usr/local/php/etc/php-fpm.d/www.conf.default /usr/local/php/etc/php-fpm.d/www.conf
}

install_python()
{
  echo "installing python"
  cd ${srcroot}/lang
  tar zxvf Python-*.tgz && rm Python-*.tgz && cd Python-* && ./configure --prefix=/usr/local/python && make && make install
}

install_nginx()
{
  echo "installing nginx"
  cd ${srcroot}/httpd
  yum install -y pcre-devel
  tar zxvf nginx*.tar.gz && rm nginx*.tar.gz && cd nginx-* && ./configure --prefix=/usr/local/nginx && make && make install
  cp ../../etc/nginx.conf /usr/local/nginx/conf/nginx.conf
  mkdir -p /data/www
  cp /usr/local/nginx/html/* /data/www/
}

configure_services()
{
echo "start servers & add them to the rc.local for boot running"
cat > /tmp/services <<EOF
/usr/local/${1}/bin/mysqld_safe &
/usr/local/php/sbin/php-fpm
/usr/local/nginx/sbin/nginx
EOF

  sh /tmp/services
  cat /tmp/services >> /etc/rc.local
  chmod +x /etc/rc.local
}

configure_env_vars () {
echo "set sys env vars"
cat > /etc/profile.d/pathmunge.sh <<EOF
pathmunge () {
  case ":\${PATH}:" in
    *:"\$1":*)
      ;;
    *)
    if [ "\$2" = "after" ] ; then
      PATH=\$PATH:\$1
    else
      PATH=\$1:\$PATH
    fi
  esac
}

pathmunge /usr/local/nginx/sbin
pathmunge /usr/local/${1}/bin
pathmunge /usr/local/php/bin
pathmunge /usr/local/python/bin
EOF
}

database="maria"
master="jing"
srcroot=$(cd `dirname $0`; pwd)
parse_args $@
configure_vim
install_db
install_php
install_python
install_nginx
configure_services $database
configure_env_vars $database


firewall-cmd --add-port=80/tcp --permanent
firewall-cmd --reload
