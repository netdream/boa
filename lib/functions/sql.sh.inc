#
# Update innodb_log_file_size.
update_innodb_log_file_size() {
  msg "INFO: InnoDB log file will be set to ${_INNODB_LOG_FILE_SIZE_MB}..."
  mrun "service mysql stop" &> /dev/null
  mrun "sleep 5"
  if [ ! -e "/var/run/mysqld/mysqld.sock" ] \
    && [ ! -e "/var/run/mysqld/mysqld.pid" ]; then
    mkdir -p ${vBs}/old-sql-ib-log-${_NOW}
    mrun "sleep 5"
    mv -f /var/lib/mysql/ib_logfile0 ${vBs}/old-sql-ib-log-${_NOW}/ &> /dev/null
    mv -f /var/lib/mysql/ib_logfile1 ${vBs}/old-sql-ib-log-${_NOW}/ &> /dev/null
    sed -i "s/.*innodb_log_file_size.*/innodb_log_file_size    = ${_INNODB_LOG_FILE_SIZE_MB}/g" /etc/mysql/my.cnf
    mrun "sleep 5"
  fi
  mrun "service mysql start" &> /dev/null
}

#
# Update SQL Config.
update_sql_conf() {
  sed -i "s/.*check_for_crashed_tables/#check_for_crashed_tables/g" /etc/mysql/debian-start
  if [ "${_CUSTOM_CONFIG_SQL}" = "NO" ] \
    || [[ "${_THISHOST}" =~ ".host8." ]] \
    || [[ "${_THISHOST}" =~ ".boa.io" ]] \
    || [ "${_VMFAMILY}" = "VS" ]; then
    if [ "${_CUSTOM_CONFIG_SQL}" = "YES" ]; then
      _DO_NOTHING=YES
    else
      cp -af /etc/mysql/my.cnf ${vBs}/dragon/t/my.cnf-pre-${_X_VERSION}-${_NOW}
      cp -af ${locCnf}/my.cnf.txt /etc/mysql/my.cnf
      _INNODB_LOG_FILE_SIZE=${_INNODB_LOG_FILE_SIZE//[^0-9]/}
      if [ ! -z "${_INNODB_LOG_FILE_SIZE}" ]; then
        if [ "${_INNODB_LOG_FILE_SIZE}" -ge "10" ] \
          && [ "${_INNODB_LOG_FILE_SIZE}" -lt "501" ]; then
          _INNODB_LOG_FILE_SIZE_MB="${_INNODB_LOG_FILE_SIZE}M"
          _INNODB_LOG_FILE_SIZE_TEST=$(grep "^innodb_log_file_size" \
            ${vBs}/dragon/t/my.cnf-pre-${_X_VERSION}-${_NOW} 2>&1)
          if [[ "${_INNODB_LOG_FILE_SIZE_TEST}" =~ "= ${_INNODB_LOG_FILE_SIZE_MB}" ]]; then
            _INNODB_LOG_FILE_SIZE_SAME=YES
          else
            _INNODB_LOG_FILE_SIZE_SAME=NO
          fi
        fi
      fi
      sed -i "s/.*slow_query_log/#slow_query_log/g"           /etc/mysql/my.cnf
      sed -i "s/.*long_query_time/#long_query_time/g"         /etc/mysql/my.cnf
      sed -i "s/.*slow_query_log_file/#slow_query_log_file/g" /etc/mysql/my.cnf
      if [ ! -e "/etc/mysql/skip-name-resolve.txt" ]; then
        sed -i "s/.*skip-name-resolve/#skip-name-resolve/g"   /etc/mysql/my.cnf
      fi
    fi
  fi
  mv -f /etc/mysql/my.cnf-pre* ${vBs}/dragon/t/ &> /dev/null
  sed -i "s/.*default-table-type/#default-table-type/g" /etc/mysql/my.cnf
  sed -i "s/.*language/#language/g" /etc/mysql/my.cnf
  _THIS_DB_SERVER_TEST=$(mysql -V 2>&1)
  if [[ "${_THIS_DB_SERVER_TEST}" =~ "5.5." ]] \
    || [[ "${_THIS_DB_SERVER_TEST}" =~ "10.0" ]]; then
    _DO_NOTHING=YES
  else
    sed -i "s/.*lc_messages_dir /#lc_messages_dir /g" /etc/mysql/my.cnf
    sed -i "s/.*lc_messages /#lc_messages /g"         /etc/mysql/my.cnf
  fi
  if [[ "${_THIS_DB_SERVER_TEST}" =~ "MariaDB" ]]; then
    sed -i "s/.*innodb_lazy_drop_table /#innodb_lazy_drop_table /g" /etc/mysql/my.cnf
  fi
  if [ "${_CUSTOM_CONFIG_SQL}" = "NO" ]; then
    if [ "${_DB_BINARY_LOG}" = "NO" ]; then
      bash /var/xdrago/purge_binlogs.sh &> /dev/null
      sed -i "s/.*purge_binlogs.*//g" /var/spool/cron/crontabs/root
      sed -i "/^$/d"                  /var/spool/cron/crontabs/root
      sed -i "s/^log_bin/#log_bin/g"                   /etc/mysql/my.cnf
      sed -i "s/^expire_logs_days/#expire_logs_days/g" /etc/mysql/my.cnf
      sed -i "s/^max_binlog_size/#max_binlog_size/g"   /etc/mysql/my.cnf
    elif [ "${_DB_BINARY_LOG}" = "YES" ]; then
      sed -i "s/.*log_bin/log_bin/g"                   /etc/mysql/my.cnf
      sed -i "s/.*expire_logs_days/expire_logs_days/g" /etc/mysql/my.cnf
      sed -i "s/.*max_binlog_size/max_binlog_size/g"   /etc/mysql/my.cnf
    fi
    if [ "${_DB_ENGINE}" = "MyISAM" ] || [ "${_DB_ENGINE}" = "InnoDB" ]; then
      sed -i "s/^default_storage_engine.*/default_storage_engine  = ${_DB_ENGINE}/g" /etc/mysql/my.cnf
    fi
    if [ ! -z "${_INNODB_LOG_FILE_SIZE}" ]; then
      if [ "${_INNODB_LOG_FILE_SIZE}" -ge "10" ] \
        && [ "${_INNODB_LOG_FILE_SIZE}" -lt "501" ]; then
        _INNODB_LOG_FILE_SIZE_MB="${_INNODB_LOG_FILE_SIZE}M"
        _INNODB_LOG_FILE_SIZE_TEST=$(grep "^innodb_log_file_size" \
          /etc/mysql/my.cnf 2>&1)
        if [[ "${_INNODB_LOG_FILE_SIZE_TEST}" =~ "= ${_INNODB_LOG_FILE_SIZE_MB}" ]]; then
          _DO_NOTHING=YES
        else
          if [ "${_INNODB_LOG_FILE_SIZE_SAME}" = "YES" ]; then
            sed -i "s/.*innodb_log_file_size.*/innodb_log_file_size    = ${_INNODB_LOG_FILE_SIZE_MB}/g" /etc/mysql/my.cnf
          else
            update_innodb_log_file_size
          fi
        fi
      fi
    fi
  fi
}

#
# Tune memory limits for SQL server.
tune_sql_memory_limits() {
  urlDld="https://raw.githubusercontent.com/major/MySQLTuner-perl/master"
  pthTun="/var/opt/mysqltuner.pl"
  outTun="/var/opt/mysqltuner-${_X_VERSION}-${_NOW}.txt"
  if [ -e "/root/.mstr.clstr.cnf" ] \
    || [ -e "/root/.wbhd.clstr.cnf" ] \
    || [ -e "/root/.dbhd.clstr.cnf" ]; then
    _GALERA_COMP=NO
  fi
  if [ ! -e "${outTun}" ] \
    && [ "${_USE_MYSQLTUNER}" = "YES" ] \
    && [ "${_STATUS}" = "UPGRADE" ] \
    && [ -z "$_GALERA_COMP" ]; then
    msg "INFO: Running MySQLTuner check on all databases..."
    msg "NOTE! This step may take a LONG time, please wait..."
    _MYSQLTUNER_TEST_RESULT=OK
    rm -f /var/opt/mysqltuner*
    curl ${crlGet} "${urlDld}/mysqltuner.pl" -o ${pthTun}
    if [ ! -e "${pthTun}" ]; then
      curl ${crlGet} "${urlDev}/mysqltuner.pl" -o ${pthTun}
    fi
    if [ -e "${pthTun}" ]; then
      perl ${pthTun} > ${outTun} 2>&1
    fi
  fi
  if [ -e "${pthTun}" ] \
    && [ -e "${outTun}" ] \
    && [ "${_USE_MYSQLTUNER}" = "YES" ] \
    && [ "${_STATUS}" = "UPGRADE" ]; then
    _REC_MYISAM_MEM=$(cat ${outTun} \
      | grep "Data in MyISAM tables" \
      | cut -d: -f2 \
      | awk '{ print $1}' 2>&1)
    _REC_INNODB_MEM=$(cat ${outTun} \
      | grep "data size:" \
      | cut -d/ -f3 \
      | awk '{ print $1}' 2>&1)
    _MYSQLTUNER_TEST=$(cat ${outTun} 2>&1)
    cp -a ${outTun} ${pthLog}/
    if [ -z "$_REC_INNODB_MEM" ] \
      || [[ "$_MYSQLTUNER_TEST" =~ "Cannot calculate MyISAM index" ]] \
      || [[ "$_MYSQLTUNER_TEST" =~ "InnoDB is enabled but isn" ]]; then
      _MYSQLTUNER_TEST_RESULT=FAIL
      msg "ALRT! The MySQLTuner test failed!"
      msg "ALRT! Please review ${outTun}"
      msg "ALRT! We will use some sane SQL defaults instead, do not worry!"
    fi
    ###--------------------###
    if [ ! -z "$_REC_MYISAM_MEM" ] \
      && [ "$_MYSQLTUNER_TEST_RESULT" = "OK" ]; then
      _RAW_MYISAM_MEM=$(echo $_REC_MYISAM_MEM | sed "s/[A-Z]//g" 2>&1)
      if [[ "$_REC_MYISAM_MEM" =~ "G" ]]; then
        _RAW_MYISAM_MEM=$(( _RAW_MYISAM_MEM * 1024 ))
      fi
      if [ "$_RAW_MYISAM_MEM" -gt "${_USE_SQL}" ]; then
        _USE_MYISAM_MEM="${_USE_SQL}"
      else
        _USE_MYISAM_MEM="$_RAW_MYISAM_MEM"
      fi
      if [ "${_USE_MYISAM_MEM}" -lt "256" ] || [ -z "${_USE_MYISAM_MEM}" ]; then
        _USE_MYISAM_MEM="${_USE_SQL}"
      fi
      _USE_MYISAM_MEM="${_USE_MYISAM_MEM}M"
      sed -i "s/^key_buffer_size.*/key_buffer_size         = ${_USE_MYISAM_MEM}/g"  /etc/mysql/my.cnf
    else
      _USE_MYISAM_MEM="${_USE_SQL}M"
      if [ "$_MYSQLTUNER_TEST_RESULT" = "FAIL" ]; then
        msg "ALRT! _USE_MYISAM_MEM is ${_USE_MYISAM_MEM} because _REC_MYISAM_MEM was empty!"
      fi
      sed -i "s/^key_buffer_size.*/key_buffer_size         = ${_USE_MYISAM_MEM}/g"  /etc/mysql/my.cnf
    fi
    ###--------------------###
    if [ ! -z "$_REC_INNODB_MEM" ] && [ "$_MYSQLTUNER_TEST_RESULT" = "OK" ]; then
      _RAW_INNODB_MEM=$(echo $_REC_INNODB_MEM | sed "s/[A-Z]//g" 2>&1)
      if [[ "$_REC_INNODB_MEM" =~ "G" ]]; then
        _RAW_INNODB_MEM=$(echo "$_RAW_INNODB_MEM * 1024" | bc -l 2>&1)
      fi
      _RAW_INNODB_MEM=$(echo "($_RAW_INNODB_MEM+0.5)/1" | bc 2>&1)
      if [ "$_RAW_INNODB_MEM" -gt "${_USE_SQL}" ]; then
        _USE_INNODB_MEM="${_USE_SQL}"
      else
        _RAW_INNODB_MEM=$(echo "scale=2; ($_RAW_INNODB_MEM * 1.1)" | bc 2>&1)
        _USE_INNODB_MEM=$(echo "($_RAW_INNODB_MEM+0.5)/1" | bc 2>&1)
      fi
      _INNODB_BPI="0"
      _INNODB_BPI=$(echo "scale=0; ${_USE_INNODB_MEM}/1024" | bc 2>&1)
      if [ "$_INNODB_BPI" -gt "1" ]; then
        sed -i "s/innodb_file_per_table   = 1/innodb_file_per_table   = 1\ninnodb_buffer_pool_instances = $_INNODB_BPI/g" /etc/mysql/my.cnf
      fi
      if [ "${_USE_INNODB_MEM}" -lt "256" ] || [ -z "${_USE_INNODB_MEM}" ]; then
        _USE_INNODB_MEM="${_USE_SQL}"
      fi
      _USE_INNODB_MEM="${_USE_INNODB_MEM}M"
      sed -i "s/^innodb_buffer_pool_size.*/innodb_buffer_pool_size = ${_USE_INNODB_MEM}/g"  /etc/mysql/my.cnf
    else
      _USE_INNODB_MEM="${_USE_SQL}M"
      msg "ALRT! _USE_INNODB_MEM is ${_USE_INNODB_MEM} because _REC_INNODB_MEM was empty!"
      sed -i "s/^innodb_buffer_pool_size.*/innodb_buffer_pool_size = ${_USE_INNODB_MEM}/g"  /etc/mysql/my.cnf
    fi
  else
    _THIS_USE_MEM="${_USE_SQL}M"
    if [ "$_MYSQLTUNER_TEST_RESULT" = "FAIL" ] \
      && [ "${_STATUS}" = "UPGRADE" ] \
      && [ -z "$_GALERA_COMP" ]; then
      msg "ALRT! _USE_MYISAM_MEM is $_THIS_USE_MEM because _REC_MYISAM_MEM was empty!"
      msg "ALRT! _USE_INNODB_MEM is $_THIS_USE_MEM because _REC_INNODB_MEM was empty!"
    fi
    sed -i "s/= 181/= ${_USE_SQL}/g"  /etc/mysql/my.cnf
  fi
}

install_mariadb_sql() {
  cd /var/opt
  _KEYS_SERVER_TEST=FALSE
  until [[ "${_KEYS_SERVER_TEST}" =~ "MariaDB" ]]; do
    _KEYS_SERVER_TEST=$(apt-key adv --recv-keys \
      --keyserver hkp://keyserver.ubuntu.com:80 1BB943DB 2>&1)
    sleep 2
  done
  if [ "${_OSV}" = "trusty" ]; then
    st_runner "${_INSTAPP} software-properties-common" 2> /dev/null
  fi
  if [ "${_THIS_OS}" = "Debian" ]; then
    _OSN=debian
  elif [ "${_THIS_OS}" = "Ubuntu" ]; then
    _OSN=ubuntu
  fi
  if [ "${_OSV}" = "trusty" ]; then
    _DB_SERIES=10.0
    if [ -e "/root/.mstr.clstr.cnf" ] \
      || [ -e "/root/.wbhd.clstr.cnf" ] \
      || [ -e "/root/.dbhd.clstr.cnf" ]; then
      _MARIADB_VRN="${_GALERA_10_VRN}"
    else
      _MARIADB_VRN="${_MARIADB_10_VRN}"
    fi
    msg "INFO: Forced MariaDB $_MARIADB_VRN in ${_THIS_OS}/${_OSV}"
  else
    if [ "${_DB_SERIES}" = "10.0" ] || [ "${_DB_SERIES}" = "5.5" ]; then
      _DO_NOTHING=YES
    else
      _DB_SERIES=5.5
      _MARIADB_VRN="${_MARIADB_5_VRN}"
      msg "INFO: Forced MariaDB $_MARIADB_VRN in ${_THIS_OS}/${_OSV}"
    fi
    if [ -z "${_DB_SERIES}" ]; then
      _DB_SERIES=5.5
      _MARIADB_VRN="${_MARIADB_5_VRN}"
      msg "INFO: Forced MariaDB $_MARIADB_VRN in ${_THIS_OS}/${_OSV}"
    fi
  fi
  rm -f /etc/apt/sources.list.d/openssl.list
  aptRepo="${_DB_SRC}/pub/mariadb/repo/${_DB_SERIES}"
  aptLiDb="${aptLiSys}.d/mariadb.list"
  echo "## MariaDB APT Repository" > ${aptLiDb}
  echo "deb http://${aptRepo}/${_OSN} ${_OSV} main" >> ${aptLiDb}
  echo "deb-src http://${aptRepo}/${_OSN} ${_OSV} main" >> ${aptLiDb}
  _BROKEN_KEYRING_TEST=$(apt-get update 2>&1)
  if [[ "$_BROKEN_KEYRING_TEST" =~ "signatures were invalid" ]] \
    || [[ "$_BROKEN_KEYRING_TEST" =~ "GPG error" ]]; then
    msg "WARN: Installed keyring is broken, forced reinstall required"
    if [ "${_THIS_OS}" = "Debian" ]; then
      st_runner "apt-get install debian-keyring ${forCer}" 2> /dev/null
      st_runner "apt-get install debian-archive-keyring ${forCer}" 2> /dev/null
    else
      st_runner "apt-get install ubuntu-keyring ${forCer}" 2> /dev/null
    fi
  fi
  st_runner "aptitude remove mytop -y"                     &> /dev/null
  st_runner "apt-get purge mytop -y"                       &> /dev/null
  rm -f /usr/bin/mytop
  st_runner "aptitude remove mysql-common -y"              &> /dev/null
  st_runner "apt-get purge mysql-common -y"                &> /dev/null
  st_runner "apt-get update -qq"                           &> /dev/null
  if [ "${_EASY_SETUP}" = "MSTR" ] \
    || [ "${_EASY_SETUP}" = "DBHD" ] \
    || [ "${_EASY_SETUP}" = "WBHD" ] \
    || [ -e "/etc/mysql/conf.d/galera.cnf" ] \
    || [ -e "/root/.mstr.clstr.cnf" ] \
    || [ -e "/root/.dbhd.clstr.cnf" ] \
    || [ -e "/root/.wbhd.clstr.cnf" ]; then
    SQLDEB="mariadb-galera-server"
  else
    SQLDEB="mariadb-server-${_DB_SERIES} \
            mariadb-client-${_DB_SERIES} \
            mariadb-common"
  fi
  SQLADD="libmariadbclient-dev \
          libmariadbclient16 \
          libmariadbd-dev \
          libdbd-mysql-perl \
          python-mysqldb \
          libdbi-perl"
}

install_with_aptitude_sql() {
  if [ "${_OSV}" = "squeeze" ] \
    || [ "${_OSV}" = "trusty" ] \
    || [ "${_OSV}" = "precise" ] \
    || [ "${_OSV}" = "lucid" ]; then
    if [ "${_EASY_SETUP}" = "MSTR" ] \
      || [ "${_EASY_SETUP}" = "DBHD" ] \
      || [ "${_EASY_SETUP}" = "WBHD" ] \
      || [ -e "/etc/mysql/conf.d/galera.cnf" ] \
      || [ -e "/root/.mstr.clstr.cnf" ] \
      || [ -e "/root/.dbhd.clstr.cnf" ] \
      || [ -e "/root/.wbhd.clstr.cnf" ]; then
      msg "INFO: Installing MariaDB Galera Cluster..."
    else
      msg "INFO: Installing MariaDB..."
    fi
  else
    if [ "${_EASY_SETUP}" = "MSTR" ] \
      || [ "${_EASY_SETUP}" = "DBHD" ] \
      || [ "${_EASY_SETUP}" = "WBHD" ] \
      || [ -e "/etc/mysql/conf.d/galera.cnf" ] \
      || [ -e "/root/.mstr.clstr.cnf" ] \
      || [ -e "/root/.dbhd.clstr.cnf" ] \
      || [ -e "/root/.wbhd.clstr.cnf" ]; then
      msg "INFO: Installing MariaDB Galera Cluster..."
    else
      msg "INFO: Installing MariaDB..."
    fi
  fi
  install_mariadb_sql
  st_runner "${_INSTAPP} mytop" 2> /dev/null
  if [ -e "${pthLog}" ]; then
    touch ${pthLog}/fixed-mytop-mariadb.log
  fi
  st_runner "${_INSTAPP} ${SQLDEB}" 2> /dev/null
  st_runner "${_INSTAPP} ${SQLADD}" 2> /dev/null
  st_runner "${_INSTAPP} ${SQLDEB}" 2> /dev/null
  if [ "${_EASY_SETUP}" = "DBHD" ] \
    || [ -e "/etc/mysql/conf.d/galera.cnf" ] \
    || [ -e "/root/.dbhd.clstr.cnf" ]; then
    msg "INFO: Running MariaDB system tables upgrade, please wait..."
    if [ -x "/usr/bin/mariadb_upgrade" ]; then
      st_runner "mariadb_upgrade --force" &> /dev/null
    elif [ -x "/usr/bin/mysql_upgrade" ]; then
      st_runner "mysql_upgrade --force" &> /dev/null
    fi
  fi
}

#
# Forced MySQL root password update.
forced_mysql_root_password_update() {
  mv -f /root/.my.cnf-pre-* ${vBs}/ &> /dev/null
  mv -f /root/.my.pass.txt-pre-* ${vBs}/ &> /dev/null
  touch /root/.my.pass.txt
  chmod 0600 /root/.my.pass.txt &> /dev/null
  _ESC_PASS=""
  _LEN_PASS=0
  if [ "${_STRONG_PASSWORDS}" = "YES" ]; then
    _PWD_CHARS=32
  elif [ "${_STRONG_PASSWORDS}" = "NO" ]; then
    _PWD_CHARS=8
  else
    _STRONG_PASSWORDS=${_STRONG_PASSWORDS//[^0-9]/}
    if [ ! -z "${_STRONG_PASSWORDS}" ] \
      && [ "${_STRONG_PASSWORDS}" -gt "8" ]; then
      _PWD_CHARS="${_STRONG_PASSWORDS}"
    else
      _PWD_CHARS=8
    fi
    if [ ! -z "${_PWD_CHARS}" ] && [ "${_PWD_CHARS}" -gt "128" ]; then
      _PWD_CHARS=128
    fi
  fi
  if [ "${_STRONG_PASSWORDS}" = "YES" ] || [ "${_PWD_CHARS}" -gt "8" ]; then
    _ESC_PASS=$(randpass "${_PWD_CHARS}" esc 2>&1)
    _ESC_PASS=$(echo -n "${_ESC_PASS}" | tr -d "\n" 2>&1)
    _LEN_PASS=$(echo ${#_ESC_PASS} 2>&1)
  fi
  if [ -z "${_ESC_PASS}" ] || [ "${_LEN_PASS}" -lt "9" ]; then
    _ESC_PASS=$(pwgen -v -s -1 2>&1)
    _ESC_PASS=$(echo -n "${_ESC_PASS}" | tr -d "\n" 2>&1)
    _ESC_PASS=$(sanitize_string "${_ESC_PASS}" 2>&1)
  fi
  if [ ! -z "${_ESC_PASS}" ]; then
    cp -af /root/.my.cnf /root/.my.cnf-pre-${_X_VERSION}-${_NOW}
    cp -af /root/.my.pass.txt /root/.my.pass.txt-pre-${_X_VERSION}-${_NOW}
    mysql -u root -e "FLUSH HOSTS;" &> /dev/null
    mysql -u root -e "DELETE FROM mysql.user WHERE User='';" &> /dev/null
    mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host \
      NOT IN ('localhost', '127.0.0.1', '::1');" &> /dev/null
    mysql -u root -e "DROP DATABASE test;" &> /dev/null
    mysql -u root -e "DELETE FROM mysql.db \
      WHERE Db='test' OR Db='test\\_%';" &> /dev/null
    mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('${_ESC_PASS}') \
      WHERE User='root';" &> /dev/null
    mysql -u root -e "FLUSH PRIVILEGES;" &> /dev/null
    echo "[client]" > /root/.my.cnf
    echo "user=root" >> /root/.my.cnf
    echo "password=${_ESC_PASS}" >> /root/.my.cnf
    chmod 0600 /root/.my.cnf
    echo "db=mysql" > /root/.mytop
    chmod 0600 /root/.mytop
    echo "${_ESC_PASS}" > /root/.my.pass.txt
    echo " "
    if [ "${_DEBUG_MODE}" = "YES" ]; then
      if [ "${_STRONG_PASSWORDS}" = "YES" ]; then
        msg "INFO: New secure random password for ${_DB_SERVER} generated"
      else
        msg "INFO: New random password for ${_DB_SERVER} generated"
      fi
    fi
  fi
}

install_mariadb_server() {
  if [ "${_STATUS}" = "INIT" ]; then
    service cron stop &> /dev/null
    if [ -e "/usr/sbin/csf" ] && [ -e "/etc/csf/csf.deny" ]; then
      csf -x &> /dev/null
    fi
    install_with_aptitude_sql
  else
    if [ "$_UP_NRC" = "YES" ]; then
      update_newrelic
    fi
    _SQL_UPGRADE=NO
    if [[ "${_DB_SERVER_TEST}" =~ "MariaDB" ]]; then
      _SQL_TEST_UPGRADE=NO
    else
      _SQL_TEST_UPGRADE=YES
    fi
    if [ "$_SQL_TEST_UPGRADE" = "YES" ] && [ "${_DB_SERVER}" = "MariaDB" ]; then
      _SQL_UPGRADE=YES
    fi
    if [ "${_OSV}" = "squeeze" ] \
      && [[ "${_DB_SERVER_TEST}" =~ "MariaDB" ]] \
      && [[ "${_DB_SERVER_TEST}" =~ " 5.3." ]]; then
      _SQL_UPGRADE=YES
    fi
    if [[ "${_DB_SERVER_TEST}" =~ "MariaDB" ]]; then
      if [[ "${_DB_SERVER_TEST}" =~ " 5.1." ]] \
        || [[ "${_DB_SERVER_TEST}" =~ " 5.2." ]]; then
        _SQL_UPGRADE=YES
      fi
      if [ "${_DB_SERIES}" = "10.0" ]; then
        if [[ "${_DB_SERVER_TEST}" =~ "10.0." ]]; then
          _DO_NOTHING=YES
        else
          _SQL_UPGRADE=YES
        fi
      elif [ "${_DB_SERIES}" = "5.5" ]; then
        if [[ "${_DB_SERVER_TEST}" =~ "5.5." ]]; then
          _DO_NOTHING=YES
        else
          _SQL_UPGRADE=YES
        fi
        if [[ "${_DB_SERVER_TEST}" =~ "10.0." ]]; then
          _SQL_UPGRADE=NO
        fi
      fi
    fi
    if [ "${_SQL_FORCE_REINSTALL}" = "YES" ] \
      || [ "${_FULL_FORCE_REINSTALL}" = "YES" ]; then
      _SQL_UPGRADE=YES
    fi
    if [ "${_SQUEEZE_TO_WHEEZY}" = "YES" ] \
      && [ "${_LOC_OSV}" = "squeeze" ]; then
      _SQL_UPGRADE=NO
    fi
    _SQL_DEB_SRC_TEST=$(grep ${_DB_SRC} \
      ${aptLiSys}.d/mariadb.list 2>&1)
    if [[ "$_SQL_DEB_SRC_TEST" =~ "${_DB_SRC}" ]] \
      && [ -e "${pthLog}/mariadb-apt-fixed-${_X_VERSION}.log" ]; then
      _SQL_DEB_SRC_UPDATE=NO
    else
      if [ "${_THIS_OS}" = "Debian" ]; then
        _OSN=debian
      elif [ "${_THIS_OS}" = "Ubuntu" ]; then
        _OSN=ubuntu
      fi
      aptRepo="${_DB_SRC}/pub/mariadb/repo/${_DB_SERIES}"
      aptLiDb="${aptLiSys}.d/mariadb.list"
      echo "## MariaDB APT Repository" > ${aptLiDb}
      echo "deb http://${aptRepo}/${_OSN} ${_OSV} main" >> ${aptLiDb}
      echo "deb-src http://${aptRepo}/${_OSN} ${_OSV} main" >> ${aptLiDb}
      rm -f /etc/apt/sources.list.d/openssl.list
      st_runner "apt-get update -qq" &> /dev/null
      touch ${pthLog}/mariadb-apt-fixed-${_X_VERSION}.log
    fi
    if [ "$_SQL_UPGRADE" = "YES" ]; then
      service cron stop &> /dev/null
      if [ -e "/usr/sbin/csf" ] && [ -e "/etc/csf/csf.deny" ]; then
        csf -x &> /dev/null
      fi
      msg "INFO: Running ${_DB_SERVER} upgrade and then PHP forced rebuild..."
      mrun "sleep 50"
      mrun "service nginx stop" &> /dev/null
      rm -f ${aptLiSys}.d/percona.list
      rm -f ${aptLiSys}.d/ourdelta.list
      _KEYS_SERVER_TEST=FALSE
      until [[ "${_KEYS_SERVER_TEST}" =~ "MariaDB" ]]; do
        _KEYS_SERVER_TEST=$(apt-key adv --recv-keys \
          --keyserver hkp://keyserver.ubuntu.com:80 1BB943DB 2>&1)
        sleep 2
      done
      rm -f /etc/apt/sources.list.d/openssl.list
      st_runner "aptitude autoclean -y" &> /dev/null
      st_runner "apt-get clean -qq" &> /dev/null
      st_runner "apt-get update -qq" &> /dev/null
      cp -af /etc/mysql/debian-start /etc/mysql/debian-start-mariadb &> /dev/null
      sed -i "s/.*default-table-type/#default-table-type/g" /etc/mysql/my.cnf
      sed -i "s/.*language/#language/g" /etc/mysql/my.cnf
      rm -f /var/lib/mysql/debian-*.flag &> /dev/null
      rm -f /var/lib/mysql/mysql_upgrade_info &> /dev/null
      install_with_aptitude_sql
      _THIS_DB_SERVER_TEST=$(mysql -V 2>&1)
      if [[ "${_THIS_DB_SERVER_TEST}" =~ "5.5." ]] \
        || [[ "${_THIS_DB_SERVER_TEST}" =~ "10.0" ]]; then
        _DO_NOTHING=YES
      else
        sed -i "s/.*lc_messages_dir /#lc_messages_dir /g" /etc/mysql/my.cnf
        sed -i "s/.*lc_messages /#lc_messages /g" /etc/mysql/my.cnf
      fi
      if [[ "${_THIS_DB_SERVER_TEST}" =~ "MariaDB" ]]; then
        sed -i "s/.*innodb_lazy_drop_table /#innodb_lazy_drop_table /g" \
          /etc/mysql/my.cnf
      fi
      _PHP_FORCE_REINSTALL=YES
      mrun "sleep 8"
      msg "INFO: Restarting ${_DB_SERVER} server..."
      mrun "service mysql restart" &> /dev/null
      mrun "service nginx start" &> /dev/null
      if [ -e "/usr/sbin/csf" ] && [ -e "/etc/csf/csf.deny" ]; then
        mrun "csf -e" &> /dev/null
      fi
      msg "INFO: ${_DB_SERVER} server restart completed"
    fi
  fi
}

check_update_sql_credentials() {
  if [ ! -e "/root/.my.pass.txt" ]; then
    if [ "${_THIS_DB_HOST}" = "localhost" ] \
      || [ "${_THIS_DB_HOST}" = "FQDN" ]; then
      msg "INFO: Generating random password for ${_DB_SERVER}"
    else
      msg "INFO: Using default dummy password for ${_DB_SERVER}"
    fi
    touch /root/.my.pass.txt
    chmod 0600 /root/.my.pass.txt &> /dev/null
    if [ "${_THIS_DB_HOST}" = "localhost" ] \
      || [ "${_THIS_DB_HOST}" = "FQDN" ]; then
      _ESC_PASS=""
      _LEN_PASS=0
      if [ "${_STRONG_PASSWORDS}" = "YES" ]; then
        _PWD_CHARS=32
      elif [ "${_STRONG_PASSWORDS}" = "NO" ]; then
        _PWD_CHARS=8
      else
        _STRONG_PASSWORDS=${_STRONG_PASSWORDS//[^0-9]/}
        if [ ! -z "${_STRONG_PASSWORDS}" ] \
          && [ "${_STRONG_PASSWORDS}" -gt "8" ]; then
          _PWD_CHARS="${_STRONG_PASSWORDS}"
        else
          _PWD_CHARS=8
        fi
        if [ ! -z "${_PWD_CHARS}" ] && [ "${_PWD_CHARS}" -gt "128" ]; then
          _PWD_CHARS=128
        fi
      fi
      if [ "${_STRONG_PASSWORDS}" = "YES" ] || [ "${_PWD_CHARS}" -gt "8" ]; then
        _ESC_PASS=$(randpass "${_PWD_CHARS}" esc 2>&1)
        _ESC_PASS=$(echo -n "${_ESC_PASS}" | tr -d "\n" 2>&1)
        _LEN_PASS=$(echo ${#_ESC_PASS} 2>&1)
      fi
      if [ -z "${_ESC_PASS}" ] || [ "${_LEN_PASS}" -lt "9" ]; then
        _ESC_PASS=$(pwgen -v -s -1 2>&1)
        _ESC_PASS=$(echo -n "${_ESC_PASS}" | tr -d "\n" 2>&1)
        _ESC_PASS=$(sanitize_string "${_ESC_PASS}" 2>&1)
      fi
    else
      _ESC_PASS=sCWL4tgEpyS5cLZITshxSTWRjhsUOeR6
    fi
    echo "${_ESC_PASS}" > /root/.my.pass.txt
  fi
  if [ -e "/root/.my.pass.txt" ]; then
    for Files in `find /var/xdrago -maxdepth 1 -mindepth 1 -type f`; do
      sed -i "s/php-fpm nginx php/php-fpm php-cgi nginx php/g" $Files &> /dev/null
    done
    if [ "${_STATUS}" = "INIT" ]; then
      msg "INFO: Updating ${_DB_SERVER} and PHP configuration"
      update_sql_conf
      update_php_conf
      update_ini_tpl
      tune_memory_limits
      msg "INFO: Restarting ${_DB_SERVER} server..."
      mrun "service mysql restart" &> /dev/null
      msg "INFO: OS and services installed"
    else
      msg "INFO: Updating ${_DB_SERVER} and PHP configuration"
      update_sql_conf
      update_php_conf
      update_ini_tpl
      tune_memory_limits
      msg "INFO: OS and services upgrade completed"
    fi
  else
    msg "EXIT on error due to not found file with your ${_DB_SERVER} root password"
    cat <<EOF

    It appears that you don't have required file with your root sql password.
    Create this file first and run this script again:

    echo "your_working_SQL_ROOT_password" > /root/.my.pass.txt
    chmod 0600 /root/.my.pass.txt

EOF
    msg "EXIT on error due to not found file with your ${_DB_SERVER} root password"
    clean_pid_exit
  fi
}

finalize_sql_initial_setup() {
  if [ ! -e "/root/.my.cnf" ]; then
    msg "INFO: ${_DB_SERVER} final setup"
    #
    # Let's just do what mysql_secure_installation does,
    # so we can do it non-interactively:
    # - remove anonymous users
    # - remove remote root
    # - remove test database
    # - remove privileges on test database
    # - set auto-generated root password
    # - reload privileges table
    #
    if [ -e "/root/.my.pass.txt" ]; then
      if [ -z "${_ESC_PASS}" ]; then
        PXSWD=$(cat /root/.my.pass.txt 2>&1)
      else
        PXSWD="${_ESC_PASS}"
      fi
      PASWD=$(echo -n $PXSWD | tr -d "\n" 2>&1)
      mysql -u root -e "FLUSH HOSTS;" &> /dev/null
      mysql -u root -e "DELETE FROM mysql.user WHERE User='';" &> /dev/null
      mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND \
        Host NOT IN ('localhost', '127.0.0.1', '::1');" &> /dev/null
      mysql -u root -e "DROP DATABASE test;" &> /dev/null
      mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR \
        Db='test\\_%';" &> /dev/null
      mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('$PASWD') \
        WHERE User='root';" &> /dev/null
      if [ "${_THIS_DB_HOST}" = "localhost" ] \
        || [ "${_THIS_DB_HOST}" = "FQDN" ]; then
        _DO_NOTHING=YES
      else
        if [ -e "/etc/mysql/debian.cnf" ] && [ "${_STATUS}" = "INIT" ]; then
          mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('${PASWD}') \
            WHERE User='debian-sys-maint';" &> /dev/null
          mkdir -p ${vBs}
          cp -af /etc/mysql/debian.cnf \
            ${vBs}/debian.cnf-pre-${_X_VERSION}-${_NOW}.txt
          chmod 400 ${vBs}/debian.cnf-pre-${_X_VERSION}-${_NOW}.txt
          sed -i "s/^password =.*/password = ${PASWD}/g" \
            /etc/mysql/debian.cnf &> /dev/null
        fi
        if [ -e "/root/.remote.IP.list" ]; then
          _ESC="\`%\`.*"
          for _IP in `cat /root/.remote.IP.list \
            | cut -d '#' -f1 \
            | sort \
            | uniq \
            | tr -d "\s"`; do
            mysql -u root -e "GRANT ALL PRIVILEGES ON $_ESC \
            TO 'aegir_root'@'${_IP}' IDENTIFIED BY '${PASWD}' \
            WITH GRANT OPTION;" &> /dev/null
          done
        fi
        if [ -e "/root/.cluster.IP.list" ]; then
          for _IP in `cat /root/.cluster.IP.list \
            | cut -d '#' -f1 \
            | sort \
            | uniq \
            | tr -d "\s"`; do
            mysql -u root -e "GRANT ALL ON *.* TO 'root'@'${_IP}';" &> /dev/null
          done
          mysql -u root -e "GRANT ALL ON *.* TO 'wsrep'@'%' \
            IDENTIFIED BY '${PASWD}';" &> /dev/null
        fi
        touch ${pthLog}/fixed-cluster-ip-grants.log
      fi
      mysql -u root -e "FLUSH PRIVILEGES;" &> /dev/null
    fi
    echo "[client]" > /root/.my.cnf
    echo "user=root" >> /root/.my.cnf
    echo "password=$PASWD" >> /root/.my.cnf
    chmod 0600 /root/.my.cnf
    echo "db=mysql" > /root/.mytop
    chmod 0600 /root/.mytop
    if [ "${_THIS_DB_HOST}" = "localhost" ]; then
      echo "skip-name-resolve" > /etc/mysql/skip-name-resolve.txt
    elif [ -e "/root/.mstr.clstr.cnf" ] \
      || [ -e "/root/.wbhd.clstr.cnf" ] \
      || [ -e "/root/.dbhd.clstr.cnf" ]; then
      echo "skip-name-resolve" > /etc/mysql/skip-name-resolve.txt
    else
      sed -i "s/.*skip-name-resolve/#skip-name-resolve/g" /etc/mysql/my.cnf
    fi
    sed -i "s/.*check_for_crashed_tables/#check_for_crashed_tables/g" \
      /etc/mysql/debian-start &> /dev/null
    mrun "service mysql restart" &> /dev/null
    msg "INFO: ${_DB_SERVER} setup completed"
    msg "INFO: You can now log in as root by typing just 'mysql'"
  else
    if [ ! -e "${pthLog}/fixed-cluster-ip-grants.log" ] \
      && [ -e "/root/.dbhd.clstr.cnf" ]; then
      PXSWD=$(cat /root/.my.pass.txt 2>&1)
      PASWD=$(echo -n $PXSWD | tr -d "\n" 2>&1)
      if [ -e "/root/.remote.IP.list" ]; then
        _ESC="\`%\`.*"
        for _IP in `cat /root/.remote.IP.list \
          | cut -d '#' -f1 \
          | sort \
          | uniq \
          | tr -d "\s"`; do
          mysql -u root -e "GRANT ALL PRIVILEGES \
            ON $_ESC TO 'aegir_root'@'${_IP}' \
            IDENTIFIED BY '${PASWD}' WITH GRANT OPTION;" &> /dev/null
        done
      fi
      if [ -e "/root/.cluster.IP.list" ]; then
        for _IP in `cat /root/.cluster.IP.list \
          | cut -d '#' -f1 \
          | sort \
          | uniq \
          | tr -d "\s"`; do
          mysql -u root -e "GRANT ALL ON *.* TO 'root'@'${_IP}';" &> /dev/null
        done
        mysql -u root -e "GRANT ALL ON *.* TO 'wsrep'@'%' \
          IDENTIFIED BY '${PASWD}';" &> /dev/null
      fi
      touch ${pthLog}/fixed-cluster-ip-grants.log
    fi
    if [ "${_THIS_DB_HOST}" = "localhost" ] \
      || [ "${_THIS_DB_HOST}" = "FQDN" ]; then
      if [ ! -e "/root/.mysql.no.new.password.cnf" ]; then
        if [ -e "/root/.mysql.yes.new.password.cnf" ]; then
          forced_mysql_root_password_update
        fi
      fi
    fi
  fi
}
