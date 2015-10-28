#!/bin/bash

SHELL=/bin/bash
PATH=/usr/local/bin:/usr/local/sbin:/opt/local/bin:/usr/bin:/usr/sbin:/bin:/sbin

action() {
  mkdir -p /usr/share/GeoIP
  chmod 755 /usr/share/GeoIP
  cd /tmp
  wget -q -U iCab \
    http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
  gunzip GeoIP.dat.gz &> /dev/null
  cp -af GeoIP.dat /usr/share/GeoIP/
  wget -q -U iCab \
    http://geolite.maxmind.com/download/geoip/database/GeoIPv6.dat.gz
  gunzip GeoIPv6.dat.gz &> /dev/null
  cp -af GeoIPv6.dat /usr/share/GeoIP/
  chmod 644 /usr/share/GeoIP/*
  rm -f -r /tmp/GeoIP*
  rm -f -r /opt/tmp
  mkdir -p /opt/tmp
  chmod 777 /opt/tmp
  rm -f /opt/tmp/sess*
  if [[ "${_CHECK_HOST}" =~ ".host8." ]] \
    || [[ "${_CHECK_HOST}" =~ ".boa.io" ]] \
    || [ "${_VMFAMILY}" = "VS" ] \
    || [ -e "/root/.host8.cnf" ]; then
    rm -f /tmp/*
  fi
  rm -f /root/ksplice-archive.asc
  rm -f /root/install-uptrack
  find /tmp/{.ICE-unix,.X11-unix,.webmin} -mtime +0 -type f -exec rm -rf {} \;
  kill -9 $(ps aux | grep '[j]etty' | awk '{print $2}') &> /dev/null
  rm -f -r /tmp/{drush*,pear,jetty*}
  rm -f /var/log/jetty{7,8,9}/*
  if [ -e "/etc/default/jetty9" ] && [ -e "/etc/init.d/jetty9" ]; then
    service jetty9 start
  fi
  if [ -e "/etc/default/jetty8" ] && [ -e "/etc/init.d/jetty8" ]; then
    service jetty8 start
  fi
  if [ -e "/etc/default/jetty7" ] && [ -e "/etc/init.d/jetty7" ]; then
    service jetty7 start
  fi
  if [ ! -e "/root/.giant_traffic.cnf" ]; then
    echo " " >> /var/log/nginx/speed_purge.log
    echo "speed_purge start `date`" >> /var/log/nginx/speed_purge.log
    find /var/lib/nginx/speed/* -mtime +1 -exec rm -rf {} \; &> /dev/null
    echo "speed_purge complete `date`" >> /var/log/nginx/speed_purge.log
    service nginx reload
  fi
  if [ -e "/var/log/newrelic" ]; then
    echo rotate > /var/log/newrelic/nrsysmond.log
    echo rotate > /var/log/newrelic/php_agent.log
    echo rotate > /var/log/newrelic/newrelic-daemon.log
  fi
  touch /var/xdrago/log/graceful.done
}

###--------------------###
_NOW=$(date +%y%m%d-%H%M 2>&1)
_CHECK_HOST=$(uname -n 2>&1)
_VM_TEST=$(uname -a 2>&1)
if [[ "${_VM_TEST}" =~ "3.6.14-beng" ]] \
  || [[ "${_VM_TEST}" =~ "3.2.12-beng" ]] \
  || [[ "${_VM_TEST}" =~ "3.6.15-beng" ]]; then
  _VMFAMILY="VS"
else
  _VMFAMILY="XEN"
fi

if [ -e "/var/run/boa_run.pid" ] || [ -e "/root/.skip_cleanup.cnf" ]; then
  exit 0
else
  touch /var/run/boa_wait.pid
  sleep 60
  action
  rm -f /var/run/boa_wait.pid
  exit 0
fi
###EOF2015###
