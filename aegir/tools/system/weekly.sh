#!/bin/bash

SHELL=/bin/bash
PATH=/usr/local/bin:/usr/local/sbin:/opt/local/bin:/usr/bin:/usr/sbin:/bin:/sbin

###-------------SYSTEM-----------------###
fix_clear_cache() {
  if [ -e "${Plr}/profiles/hostmaster" ]; then
    su -s /bin/bash - ${_THIS_U} -c "drush @hostmaster cc all &> /dev/null"
  fi
}

read_account_data() {
  if [ -e "/data/disk/${_THIS_U}/log/email.txt" ]; then
    _CLIENT_EMAIL=$(cat /data/disk/${_THIS_U}/log/email.txt 2>&1)
    _CLIENT_EMAIL=$(echo -n ${_CLIENT_EMAIL} | tr -d "\n" 2>&1)
  fi
  if [ -e "/data/disk/${_THIS_U}/log/cores.txt" ]; then
    _CLIENT_CORES=$(cat /data/disk/${_THIS_U}/log/cores.txt 2>&1)
    _CLIENT_CORES=$(echo -n ${_CLIENT_CORES} | tr -d "\n" 2>&1)
  fi
  if [ "${_CLIENT_CORES}" -gt "1" ]; then
    _ENGINE_NR="Engines"
  else
    _ENGINE_NR="Engine"
  fi
  if [ -e "/data/disk/${_THIS_U}/log/option.txt" ]; then
    _CLIENT_OPTION=$(cat /data/disk/${_THIS_U}/log/option.txt 2>&1)
    _CLIENT_OPTION=$(echo -n ${_CLIENT_OPTION} | tr -d "\n" 2>&1)
  fi
  if [ -e "/data/disk/${_THIS_U}/log/extra.txt" ] \
    && [ "${_CLIENT_OPTION}" = "POWER" ]; then
    _EXTRA_ENGINE=$(cat /data/disk/${_THIS_U}/log/extra.txt 2>&1)
    _EXTRA_ENGINE=$(echo -n ${_EXTRA_ENGINE} | tr -d "\n" 2>&1)
    _ENGINE_NR="${_ENGINE_NR} + ${_EXTRA_ENGINE} x EDGE"
  fi
}

send_notice_core() {
  _MY_EMAIL="notify@netdream.it"
  _BCC_EMAIL="webmaster@netdream.it"
  _CLIENT_EMAIL=${_CLIENT_EMAIL//\\\@/\@}
  _MAILX_TEST=$(mail -V 2>&1)
  if [[ "${_MAILX_TEST}" =~ "GNU Mailutils" ]]; then
  cat <<EOF | mail -e -a "From: ${_MY_EMAIL}" -a "Bcc: ${_BCC_EMAIL}" \
    -s "URGENT: Please migrate ${Dom} site to Pressflow" ${_CLIENT_EMAIL}
Hello,

Our system detected that you are using vanilla Drupal core
for site ${Dom}.

The platform root directory for this site is:
${Plr}

Using non-Pressflow 5.x or 6.x core is not allowed
on our servers, unless it is a temporary result of your site
import, but every imported site should be migrated to Pressflow
based platform as soon as possible.

If the site is not migrated to Pressflow based platform
in seven (7) days, it may cause service interruption.

We are working hard to deliver top performance hosting
for your Drupal sites and we appreciate your efforts
to meet the requirements, which are an integral part
of the quality you can expect from Netdream.

If you have any questions, please don't respond to this message,
since it was sent from our default system address -- please use
our support contact form instead:

  http://helpdesk.netdream.it

Thank you in advance.

--
This e-mail has been sent by your Aegir platform core monitor.

EOF
  elif [[ "${_MAILX_TEST}" =~ "invalid" ]]; then
  cat <<EOF | mail -a "From: ${_MY_EMAIL}" -e -b ${_BCC_EMAIL} \
    -s "URGENT: Please migrate ${Dom} site to Pressflow" ${_CLIENT_EMAIL}
Hello,

Our system detected that you are using vanilla Drupal core
for site ${Dom}.

The platform root directory for this site is:
${Plr}

Using non-Pressflow 5.x or 6.x core is not allowed
on our servers, unless it is a temporary result of your site
import, but every imported site should be migrated to Pressflow
based platform as soon as possible.

If the site is not migrated to Pressflow based platform
in seven (7) days, it may cause service interruption.

We are working hard to deliver top performance hosting
for your Drupal sites and we appreciate your efforts
to meet the requirements, which are an integral part
of the quality you can expect from Netdream.

If you have any questions, please don't respond to this message,
since it was sent from our default system address -- please use
our support contact form instead:

  http://helpdesk.netdream.it

Thank you in advance.

--
This e-mail has been sent by your Aegir platform core monitor.

EOF
  else
  cat <<EOF | mail -r ${_MY_EMAIL} -e -b ${_BCC_EMAIL} \
    -s "URGENT: Please migrate ${Dom} site to Pressflow" ${_CLIENT_EMAIL}
Hello,

Our system detected that you are using vanilla Drupal core
for site ${Dom}.

The platform root directory for this site is:
${Plr}

Using non-Pressflow 5.x or 6.x core is not allowed
on our servers, unless it is a temporary result of your site
import, but every imported site should be migrated to Pressflow
based platform as soon as possible.

If the site is not migrated to Pressflow based platform
in seven (7) days, it may cause service interruption.

We are working hard to deliver top performance hosting
for your Drupal sites and we appreciate your efforts
to meet the requirements, which are an integral part
of the quality you can expect from Netdream.

If you have any questions, please don't respond to this message,
since it was sent from our default system address -- please use
our support contact form instead:

  http://helpdesk.netdream.it

Thank you in advance.

--
This e-mail has been sent by your Aegir platform core monitor.

EOF
  fi
  echo "INFO: Pressflow notice sent to ${_CLIENT_EMAIL} [${_THIS_U}]: OK"
}

detect_vanilla_core() {
  if [ ! -e "${Plr}/core" ]; then
    if [ -e "${Plr}/web.config" ]; then
      _DO_NOTHING=YES
    else
      if [ -e "${Plr}/modules/watchdog" ]; then
        if [ ! -e "/boot/grub/grub.cfg" ] \
          && [ ! -e "/boot/grub/menu.lst" ] \
          && [[ "${Plr}" =~ "static" ]] \
          && [ ! -e "${Plr}/modules/cookie_cache_bypass" ]; then
          if [[ "${_CHECK_HOST}" =~ ".host8." ]] \
            || [[ "${_CHECK_HOST}" =~ ".boa.io" ]] \
            || [ "${_VMFAMILY}" = "VS" ]; then
            echo Vanilla Drupal 5.x Platform detected in ${Plr}
            read_account_data
            send_notice_core
          fi
        fi
      else
        if [ ! -e "${Plr}/modules/path_alias_cache" ] \
          && [ -e "${Plr}/modules/user" ] \
          && [[ "${Plr}" =~ "static" ]]; then
          echo Vanilla Drupal 6.x Platform detected in ${Plr}
          if [ ! -e "/boot/grub/grub.cfg" ] \
            && [ ! -e "/boot/grub/menu.lst" ]; then
            if [[ "${_CHECK_HOST}" =~ ".host8." ]] \
              || [[ "${_CHECK_HOST}" =~ ".boa.io" ]] \
              || [ "${_VMFAMILY}" = "VS" ]; then
              read_account_data
              send_notice_core
            fi
          fi
        fi
      fi
    fi
  fi
}

count() {
  for Site in `find ${User}/config/server_master/nginx/vhost.d \
    -maxdepth 1 -mindepth 1 -type f | sort`; do
    #echo Counting Site $Site
    Dom=$(echo $Site | cut -d'/' -f9 | awk '{ print $1}' 2>&1)
    #echo "${_THIS_U},${Dom},vhost-exists"
    _DEV_URL=NO
    searchStringA=".temporary."
    searchStringB=".testing."
    case ${Dom} in
      *"$searchStringA"*) _DEV_URL=YES ;;
      *"$searchStringB"*) _DEV_URL=YES ;;
      *)
      ;;
    esac
    if [ -e "${User}/.drush/${Dom}.alias.drushrc.php" ]; then
      #echo "${_THIS_U},${Dom},drushrc-exists"
      Dir=$(cat ${User}/.drush/${Dom}.alias.drushrc.php \
        | grep "site_path'" \
        | cut -d: -f2 \
        | awk '{ print $3}' \
        | sed "s/[\,']//g" 2>&1)
      Plr=$(cat ${User}/.drush/${Dom}.alias.drushrc.php \
        | grep "root'" \
        | cut -d: -f2 \
        | awk '{ print $3}' \
        | sed "s/[\,']//g" 2>&1)
      detect_vanilla_core
      fix_clear_cache
      #echo Dir is ${Dir}
      if [ -e "${Dir}/drushrc.php" ] \
        && [ -e "${Dir}/files" ] \
        && [ -e "${Dir}/private" ] \
        && [ -e "${Dir}/modules" ] \
        && [ ! -e "${Plr}/profiles/hostmaster" ]; then
        #echo "${_THIS_U},${Dom},sitedir-exists"
        Dat=$(cat ${Dir}/drushrc.php \
          | grep "options\['db_name'\] = " \
          | cut -d: -f2 \
          | awk '{ print $3}' \
          | sed "s/[\,';]//g" 2>&1)
        #echo Dat is ${Dat}
        if [ ! -z "${Dat}" ] && [ -e "${Dir}" ]; then
          if [ -L "${Dir}/files" ] || [ -L "${Dir}/private" ]; then
            DirSize=$(du -L -s ${Dir} 2>&1)
          else
            DirSize=$(du -s ${Dir} 2>&1)
          fi
          DirSize=$(echo "${DirSize}" \
            | cut -d'/' -f1 \
            | awk '{ print $1}' \
            | sed "s/[\/\s+]//g" 2>&1)
          if [ "${_DEV_URL}" = "YES" ]; then
            echo "${_THIS_U},${Dom},DirSize:${DirSize},skip"
          else
            SumDir=$(( SumDir + DirSize ))
            echo "${_THIS_U},${Dom},DirSize:${DirSize}"
          fi
        fi
        if [ ! -z "${Dat}" ] && [ -e "/var/lib/mysql/${Dat}" ]; then
          DatSize=$(du -s /var/lib/mysql/${Dat} 2>&1)
          DatSize=$(echo "${DatSize}" \
            | cut -d'/' -f1 \
            | awk '{ print $1}' \
            | sed "s/[\/\s+]//g" 2>&1)
          if [ "${_DEV_URL}" = "YES" ]; then
            echo "${_THIS_U},${Dom},DatSize:${DatSize}:${Dat},skip"
          else
            SumDat=$(( SumDat + DatSize ))
            echo "${_THIS_U},${Dom},DatSize:${DatSize}:${Dat}"
          fi
        else
          echo "Database ${Dat} for ${Dom} does not exist"
        fi
      fi
    fi
  done
}

send_notice_sql() {
  _MY_EMAIL="notify@netdream.it"
  _BCC_EMAIL="webmaster@netdream.it"
  _CLIENT_EMAIL=${_CLIENT_EMAIL//\\\@/\@}
  _MAILX_TEST=$(mail -V 2>&1)
  if [[ "${_MAILX_TEST}" =~ "GNU Mailutils" ]]; then
  cat <<EOF | mail -e -a "From: ${_MY_EMAIL}" -a "Bcc: ${_BCC_EMAIL}" \
    -s "NOTICE: Your DB Usage on [${_THIS_U}] is too high" ${_CLIENT_EMAIL}
Hello,

You are using more resources than allocated in your subscription.
You have currently ${_CLIENT_CORES} Aegir ${_CLIENT_OPTION} ${_ENGINE_NR}.

Your allowed databases space is ${_SQL_MIN_LIMIT} MB.
You are currently using ${SumDatH} MB of databases space.

Please reduce your usage by deleting no longer used sites,
or by converting their tables to MyISAM format on command line
when in the site directory with:

  $ sqlmagic convert to-myisam

or purchase enough Aegir Engines to cover your current usage.

You can purchase more Aegir Engines easily online:

  http://helpdesk.netdream.it

Note that we do not count any site identified as temporary dev/test,
by having in its main name a special keyword with two dots on both sides:

  .temporary. .testing.

For example, a site with main name: abc.testing.foo.com is by default excluded
from your allocated resources limits (not counted for billing purposes).

However, if we discover that someone is using this method to hide real
usage via listed keywords in the main site name and adding live domain(s)
as aliases, such account will be suspended without any warning.

Please also note that you can not keep such tmp/test/dev sites forever.
We allow to exclude them from the usage limits only because it is expected
that these sites will be deleted as soon as possible - in a matter of days
or a few weeks, but not any longer. If you will ignore this rule, we reserve
the right to remove ability to exclude tmp/test/dev sites on your system.

If you are using more (counted) resources than allocated in your subscription
for more than 30 calendar days without purchasing an upgrade, your instance
will be suspended without further notice, and to restore it you will have to
pay for all past due overages plus \$152 USD reconnection fee.

We provide very generous soft-limits and we allow free-of-charge overages
between weekly checks which happen every Monday, but in return we expect
that you will use this allowance responsibly and sparingly.

If you have any questions, please don't respond to this message,
since it was sent from our default system address -- please use
our billing contact form instead:

  http://helpdesk.netdream.it

Thank you in advance.

--
This e-mail has been sent by your Aegir resources usage weekly monitor.

EOF
  elif [[ "${_MAILX_TEST}" =~ "invalid" ]]; then
  cat <<EOF | mail -a "From: ${_MY_EMAIL}" -e -b ${_BCC_EMAIL} \
    -s "NOTICE: Your DB Usage on [${_THIS_U}] is too high" ${_CLIENT_EMAIL}
Hello,

You are using more resources than allocated in your subscription.
You have currently ${_CLIENT_CORES} Aegir ${_CLIENT_OPTION} ${_ENGINE_NR}.

Your allowed databases space is ${_SQL_MIN_LIMIT} MB.
You are currently using ${SumDatH} MB of databases space.

Please reduce your usage by deleting no longer used sites,
or by converting their tables to MyISAM format on command line
when in the site directory with:

  $ sqlmagic convert to-myisam

or purchase enough Aegir Engines to cover your current usage.

You can purchase more Aegir Engines easily online:

  http://helpdesk.netdream.it

Note that we do not count any site identified as temporary dev/test,
by having in its main name a special keyword with two dots on both sides:

  .temporary. .testing.

For example, a site with main name: abc.testing.foo.com is by default excluded
from your allocated resources limits (not counted for billing purposes).

However, if we discover that someone is using this method to hide real
usage via listed keywords in the main site name and adding live domain(s)
as aliases, such account will be suspended without any warning.

Please also note that you can not keep such tmp/test/dev sites forever.
We allow to exclude them from the usage limits only because it is expected
that these sites will be deleted as soon as possible - in a matter of days
or a few weeks, but not any longer. If you will ignore this rule, we reserve
the right to remove ability to exclude tmp/test/dev sites on your system.

If you are using more (counted) resources than allocated in your subscription
for more than 30 calendar days without purchasing an upgrade, your instance
will be suspended without further notice, and to restore it you will have to
pay for all past due overages plus \$152 USD reconnection fee.

We provide very generous soft-limits and we allow free-of-charge overages
between weekly checks which happen every Monday, but in return we expect
that you will use this allowance responsibly and sparingly.

Thank you in advance.

--
This e-mail has been sent by your Aegir resources usage weekly monitor.

EOF
  else
  cat <<EOF | mail -r ${_MY_EMAIL} -e -b ${_BCC_EMAIL} \
    -s "NOTICE: Your DB Usage on [${_THIS_U}] is too high" ${_CLIENT_EMAIL}
Hello,

You are using more resources than allocated in your subscription.
You have currently ${_CLIENT_CORES} Aegir ${_CLIENT_OPTION} ${_ENGINE_NR}.

Your allowed databases space is ${_SQL_MIN_LIMIT} MB.
You are currently using ${SumDatH} MB of databases space.

Please reduce your usage by deleting no longer used sites,
or by converting their tables to MyISAM format on command line
when in the site directory with:

  $ sqlmagic convert to-myisam

or purchase enough Aegir Engines to cover your current usage.

You can purchase more Aegir Engines easily online:

  http://helpdesk.netdream.it

Note that we do not count any site identified as temporary dev/test,
by having in its main name a special keyword with two dots on both sides:

  .temporary. .testing.

For example, a site with main name: abc.testing.foo.com is by default excluded
from your allocated resources limits (not counted for billing purposes).

However, if we discover that someone is using this method to hide real
usage via listed keywords in the main site name and adding live domain(s)
as aliases, such account will be suspended without any warning.

Please also note that you can not keep such tmp/test/dev sites forever.
We allow to exclude them from the usage limits only because it is expected
that these sites will be deleted as soon as possible - in a matter of days
or a few weeks, but not any longer. If you will ignore this rule, we reserve
the right to remove ability to exclude tmp/test/dev sites on your system.

If you are using more (counted) resources than allocated in your subscription
for more than 30 calendar days without purchasing an upgrade, your instance
will be suspended without further notice, and to restore it you will have to
pay for all past due overages plus \$152 USD reconnection fee.

We provide very generous soft-limits and we allow free-of-charge overages
between weekly checks which happen every Monday, but in return we expect
that you will use this allowance responsibly and sparingly.

Thank you in advance.

--
This e-mail has been sent by your Aegir resources usage weekly monitor.

EOF
  fi
  echo "INFO: Notice sent to ${_CLIENT_EMAIL} [${_THIS_U}]: OK"
}

send_notice_disk() {
  _MY_EMAIL="notify@netdream.it"
  _BCC_EMAIL="webmaster@netdream.it"
  _CLIENT_EMAIL=${_CLIENT_EMAIL//\\\@/\@}
  _MAILX_TEST=$(mail -V 2>&1)
  if [[ "${_MAILX_TEST}" =~ "GNU Mailutils" ]]; then
  cat <<EOF | mail -e -a "From: ${_MY_EMAIL}" -a "Bcc: ${_BCC_EMAIL}" \
    -s "NOTICE: Your Disk Usage on [${_THIS_U}] is too high" ${_CLIENT_EMAIL}
Hello,

You are using more resources than allocated in your subscription.
You have currently ${_CLIENT_CORES} Aegir ${_CLIENT_OPTION} ${_ENGINE_NR}.

Your allowed disk space is ${_DSK_MIN_LIMIT} MB.
You are currently using ${HomSizH} MB of disk space.

Please reduce your usage by deleting old backups, files,
and no longer used sites, or purchase enough Aegir Engines
to cover your current usage.

You can purchase more Aegir Engines easily online:

  http://helpdesk.netdream.it

Note that we do not count any site identified as temporary dev/test,
by having in its main name a special keyword with two dots on both sides:

  .temporary. .testing.

For example, a site with main name: abc.testing.foo.com is by default excluded
from your allocated resources limits (not counted for billing purposes).

However, if we discover that someone is using this method to hide real
usage via listed keywords in the main site name and adding live domain(s)
as aliases, such account will be suspended without any warning.

Please also note that you can not keep such tmp/test/dev sites forever.
We allow to exclude them from the usage limits only because it is expected
that these sites will be deleted as soon as possible - in a matter of days
or a few weeks, but not any longer. If you will ignore this rule, we reserve
the right to remove ability to exclude tmp/test/dev sites on your system.

If you are using more (counted) resources than allocated in your subscription
for more than 30 calendar days without purchasing an upgrade, your instance
will be suspended without further notice, and to restore it you will have to
pay for all past due overages plus \$152 USD reconnection fee.

We provide very generous soft-limits and we allow free-of-charge overages
between weekly checks which happen every Monday, but in return we expect
that you will use this allowance responsibly and sparingly.

If you have any questions, please don't respond to this message,
since it was sent from our default system address -- please use
our billing contact form instead:

  http://helpdesk.netdream.it

Thank you in advance.

--
This e-mail has been sent by your Aegir resources usage weekly monitor.

EOF
  elif [[ "${_MAILX_TEST}" =~ "invalid" ]]; then
  cat <<EOF | mail -a "From: ${_MY_EMAIL}" -e -b ${_BCC_EMAIL} \
    -s "NOTICE: Your Disk Usage on [${_THIS_U}] is too high" ${_CLIENT_EMAIL}
Hello,

You are using more resources than allocated in your subscription.
You have currently ${_CLIENT_CORES} Aegir ${_CLIENT_OPTION} ${_ENGINE_NR}.

Your allowed disk space is ${_DSK_MIN_LIMIT} MB.
You are currently using ${HomSizH} MB of disk space.

Please reduce your usage by deleting old backups, files,
and no longer used sites, or purchase enough Aegir Engines
to cover your current usage.

You can purchase more Aegir Engines easily online:

  http://helpdesk.netdream.it

Note that we do not count any site identified as temporary dev/test,
by having in its main name a special keyword with two dots on both sides:

  .temporary. .testing.

For example, a site with main name: abc.testing.foo.com is by default excluded
from your allocated resources limits (not counted for billing purposes).

However, if we discover that someone is using this method to hide real
usage via listed keywords in the main site name and adding live domain(s)
as aliases, such account will be suspended without any warning.

If you are using more (counted) resources than allocated in your subscription
for more than 30 calendar days without purchasing an upgrade, your instance
will be suspended without further notice, and to restore it you will have to
pay for all past due overages plus \$152 USD reconnection fee.

We provide very generous soft-limits and we allow free-of-charge overages
between weekly checks which happen every Monday, but in return we expect
that you will use this allowance responsibly and sparingly.

Thank you in advance.

--
This e-mail has been sent by your Aegir resources usage weekly monitor.

EOF
  else
  cat <<EOF | mail -r ${_MY_EMAIL} -e -b ${_BCC_EMAIL} \
    -s "NOTICE: Your Disk Usage on [${_THIS_U}] is too high" ${_CLIENT_EMAIL}
Hello,

You are using more resources than allocated in your subscription.
You have currently ${_CLIENT_CORES} Aegir ${_CLIENT_OPTION} ${_ENGINE_NR}.

Your allowed disk space is ${_DSK_MIN_LIMIT} MB.
You are currently using ${HomSizH} MB of disk space.

Please reduce your usage by deleting old backups, files,
and no longer used sites, or purchase enough Aegir Engines
to cover your current usage.

You can purchase more Aegir Engines easily online:

  http://helpdesk.netdream.it

Note that we do not count any site identified as temporary dev/test,
by having in its main name a special keyword with two dots on both sides:

  .temporary. .testing.

For example, a site with main name: abc.testing.foo.com is by default excluded
from your allocated resources limits (not counted for billing purposes).

However, if we discover that someone is using this method to hide real
usage via listed keywords in the main site name and adding live domain(s)
as aliases, such account will be suspended without any warning.

If you are using more (counted) resources than allocated in your subscription
for more than 30 calendar days without purchasing an upgrade, your instance
will be suspended without further notice, and to restore it you will have to
pay for all past due overages plus \$152 USD reconnection fee.

We provide very generous soft-limits and we allow free-of-charge overages
between weekly checks which happen every Monday, but in return we expect
that you will use this allowance responsibly and sparingly.

Thank you in advance.

--
This e-mail has been sent by your Aegir resources usage weekly monitor.

EOF
  fi
  echo "INFO: Notice sent to ${_CLIENT_EMAIL} [${_THIS_U}]: OK"
}

check_limits() {
  read_account_data
  if [ "${_CLIENT_OPTION}" = "POWER" ]; then
    _SQL_MIN_LIMIT=5120
    _DSK_MIN_LIMIT=51200
    _SQL_MAX_LIMIT=$(( _SQL_MIN_LIMIT + 256 ))
    _DSK_MAX_LIMIT=$(( _DSK_MIN_LIMIT + 2560 ))
  elif [ "${_CLIENT_OPTION}" = "SSD" ] \
    || [ "${_CLIENT_OPTION}" = "EDGE" ]; then
    _CLIENT_OPTION=EDGE
    _SQL_MIN_LIMIT=512
    _DSK_MIN_LIMIT=15360
    _SQL_MAX_LIMIT=$(( _SQL_MIN_LIMIT + 128 ))
    _DSK_MAX_LIMIT=$(( _DSK_MIN_LIMIT + 1280 ))
  elif [ "${_CLIENT_OPTION}" = "MICRO" ]; then
    _SQL_MIN_LIMIT=256
    _DSK_MIN_LIMIT=4096
    _SQL_MAX_LIMIT=$(( _SQL_MIN_LIMIT + 64 ))
    _DSK_MAX_LIMIT=$(( _DSK_MIN_LIMIT + 640 ))
  else
    _SQL_MIN_LIMIT=256
    _DSK_MIN_LIMIT=5120
    _SQL_MAX_LIMIT=$(( _SQL_MIN_LIMIT + 64 ))
    _DSK_MAX_LIMIT=$(( _DSK_MIN_LIMIT + 640 ))
  fi
  _SQL_MIN_LIMIT=$(( _SQL_MIN_LIMIT *= _CLIENT_CORES ))
  _DSK_MIN_LIMIT=$(( _DSK_MIN_LIMIT *= _CLIENT_CORES ))
  _SQL_MAX_LIMIT=$(( _SQL_MAX_LIMIT *= _CLIENT_CORES ))
  _DSK_MAX_LIMIT=$(( _DSK_MAX_LIMIT *= _CLIENT_CORES ))
  if [ ! -z "${_EXTRA_ENGINE}" ]; then
    _SQL_ADD_LIMIT=512
    _DSK_ADD_LIMIT=15360
    _SQL_ADD_LIMIT=$(( _SQL_ADD_LIMIT *= _EXTRA_ENGINE ))
    _DSK_ADD_LIMIT=$(( _DSK_ADD_LIMIT *= _EXTRA_ENGINE ))
    _SQL_MIN_LIMIT=$(( _SQL_MIN_LIMIT + _SQL_ADD_LIMIT ))
    _DSK_MIN_LIMIT=$(( _DSK_MIN_LIMIT + _DSK_ADD_LIMIT ))
    _SQL_MAX_LIMIT=$(( _SQL_MAX_LIMIT + _SQL_ADD_LIMIT ))
    _DSK_MAX_LIMIT=$(( _DSK_MAX_LIMIT + _DSK_ADD_LIMIT ))
    echo _EXTRA_ENGINE is ${_EXTRA_ENGINE}
  fi
  echo _CLIENT_CORES is ${_CLIENT_CORES}
  echo _SQL_MIN_LIMIT is ${_SQL_MIN_LIMIT}
  echo _SQL_MAX_LIMIT is ${_SQL_MAX_LIMIT}
  echo _DSK_MIN_LIMIT is ${_DSK_MIN_LIMIT}
  echo _DSK_MAX_LIMIT is ${_DSK_MAX_LIMIT}
  if [ "${SumDatH}" -gt "${_SQL_MAX_LIMIT}" ]; then
    if [ ! -e "${User}/log/CANCELLED" ]; then
      send_notice_sql
    fi
    echo SQL Usage for ${_THIS_U} above limits
  else
    echo SQL Usage for ${_THIS_U} below limits
  fi
  if [ "${HomSizH}" -gt "${_DSK_MAX_LIMIT}" ]; then
    if [ ! -e "${User}/log/CANCELLED" ]; then
      send_notice_disk
    fi
    echo Disk Usage for ${_THIS_U} above limits
  else
    echo Disk Usage for ${_THIS_U} below limits
  fi
}

count_cpu() {
  _CPU_INFO=$(grep -c processor /proc/cpuinfo 2>&1)
  _CPU_INFO=${_CPU_INFO//[^0-9]/}
  _NPROC_TEST=$(which nproc 2>&1)
  if [ -z "${_NPROC_TEST}" ]; then
    _CPU_NR="${_CPU_INFO}"
  else
    _CPU_NR=$(nproc 2>&1)
  fi
  _CPU_NR=${_CPU_NR//[^0-9]/}
  if [ ! -z "${_CPU_NR}" ] \
    && [ ! -z "${_CPU_INFO}" ] \
    && [ "${_CPU_NR}" -gt "${_CPU_INFO}" ] \
    && [ "${_CPU_INFO}" -gt "0" ]; then
    _CPU_NR="${_CPU_INFO}"
  fi
  if [ -z "${_CPU_NR}" ] || [ "${_CPU_NR}" -lt "1" ]; then
    _CPU_NR=1
  fi
}

load_control() {
  if [ -e "/root/.barracuda.cnf" ]; then
    source /root/.barracuda.cnf
    _CPU_MAX_RATIO=${_CPU_MAX_RATIO//[^0-9]/}
  fi
  if [ -z "${_CPU_MAX_RATIO}" ]; then
    _CPU_MAX_RATIO=6
  fi
  _O_LOAD=$(awk '{print $1*100}' /proc/loadavg 2>&1)
  _O_LOAD=$(( _O_LOAD / _CPU_NR ))
  _O_LOAD_MAX=$(( 100 * _CPU_MAX_RATIO ))
}

action() {
  for User in `find /data/disk/ -maxdepth 1 -mindepth 1 | sort`; do
    count_cpu
    load_control
    if [ -e "${User}/config/server_master/nginx/vhost.d" ]; then
      if [ "${_O_LOAD}" -lt "${_O_LOAD_MAX}" ]; then
        SumDir=0
        SumDat=0
        HomSiz=0
        HxmSiz=0
        _THIS_U=$(echo ${User} | cut -d'/' -f4 | awk '{ print $1}' 2>&1)
        _THIS_HM_SITE=$(cat ${User}/.drush/hostmaster.alias.drushrc.php \
          | grep "site_path'" \
          | cut -d: -f2 \
          | awk '{ print $3}' \
          | sed "s/[\,']//g" 2>&1)
        echo load is ${_O_LOAD} while maxload is ${_O_LOAD_MAX}
        echo Counting User ${User}
        count
        if [ -e "/home/${_THIS_U}.ftp" ]; then
          HxmSiz=$(du -s /home/${_THIS_U}.ftp 2>&1)
          HxmSiz=$(echo "${HxmSiz}" \
            | cut -d'/' -f1 \
            | awk '{ print $1}' \
            | sed "s/[\/\s+]//g" 2>&1)
        fi
        if [ -L "${User}" ]; then
          HomSiz=$(du -D -s ${User} 2>&1)
        else
          HomSiz=$(du -s ${User} 2>&1)
        fi
        HomSiz=$(echo "${HomSiz}" \
          | cut -d'/' -f1 \
          | awk '{ print $1}' \
          | sed "s/[\/\s+]//g" 2>&1)
        HomSiz=$(( HomSiz + HxmSiz ))
        HomSizH=$(echo "scale=0; ${HomSiz}/1024" | bc 2>&1)
        SumDatH=$(echo "scale=0; ${SumDat}/1024" | bc 2>&1)
        SumDirH=$(echo "scale=0; ${SumDir}/1024" | bc 2>&1)
        echo HomSiz is ${HomSiz} or ${HomSizH} MB
        echo SumDir is ${SumDir} or ${SumDirH} MB
        echo SumDat is ${SumDat} or ${SumDatH} MB
        if [[ "${_CHECK_HOST}" =~ ".host8." ]] \
          || [[ "${_CHECK_HOST}" =~ ".boa.io" ]] \
          || [ "${_VMFAMILY}" = "VS" ]; then
          check_limits
          if [ -e "${_THIS_HM_SITE}" ]; then
            su -s /bin/bash - ${_THIS_U} -c "drush @hostmaster \
              vset --always-set site_footer 'Weekly Usage Monitor \
              | ${_DATE} \
              | Disk <strong>${HomSizH}</strong> MB \
              | Databases <strong>${SumDatH}</strong> MB \
              | <strong>${_CLIENT_CORES}</strong> \
              Aegir ${_CLIENT_OPTION} ${_ENGINE_NR}' &> /dev/null"
            su -s /bin/bash - ${_THIS_U} \
              -c "drush @hostmaster cc all &> /dev/null"
          fi
        else
          if [ -e "${_THIS_HM_SITE}" ]; then
            su -s /bin/bash - ${_THIS_U} \
              -c "drush @hostmaster vset \
              --always-set site_footer '' &> /dev/null"
            su -s /bin/bash - ${_THIS_U} \
              -c "drush @hostmaster cc all &> /dev/null"
          fi
        fi
        echo "Done for ${User}"
      else
        echo "load is ${_O_LOAD} while maxload is ${_O_LOAD_MAX}"
        echo "...we have to wait..."
      fi
      echo
      echo
    fi
  done
}

###--------------------###
echo "INFO: Weekly maintenance start"
_NOW=$(date +%y%m%d-%H%M 2>&1)
_DATE=$(date 2>&1)
_CHECK_HOST=$(uname -n 2>&1)
_VM_TEST=$(uname -a 2>&1)
if [[ "${_VM_TEST}" =~ "3.6.14-beng" ]] \
  || [ -e "/root/.debug.cnf" ] \
  || [[ "${_VM_TEST}" =~ "3.6.15-beng" ]]; then
  _VMFAMILY="VS"
else
  _VMFAMILY="XEN"
fi
mkdir -p /var/xdrago/log/usage
action >/var/xdrago/log/usage/usage-${_NOW}.log 2>&1
echo "INFO: Weekly maintenance complete"
exit 0
###EOF2015###
