#!/bin/bash

SHELL=/bin/bash
PATH=/usr/local/bin:/usr/local/sbin:/opt/local/bin:/usr/bin:/usr/sbin:/bin:/sbin
_CHECK_HOST=$(uname -n 2>&1)
_VM_TEST=$(uname -a 2>&1)
usrGroup=users
_WEBG=www-data
_THIS_RV=$(lsb_release -sc 2>&1)
if [ "${_THIS_RV}" = "wheezy" ] \
  || [ "${_THIS_RV}" = "trusty" ] \
  || [ "${_THIS_RV}" = "precise" ]; then
  _RUBY_VRN=2.2.3
else
  _RUBY_VRN=2.0.0
fi
if [[ "${_VM_TEST}" =~ "3.6.14-beng" ]] \
  || [[ "${_VM_TEST}" =~ "3.2.12-beng" ]] \
  || [[ "${_VM_TEST}" =~ "3.6.15-beng" ]]; then
  _VMFAMILY="VS"
else
  _VMFAMILY="XEN"
fi
if [ -x "/usr/bin/gpg2" ]; then
  _GPG=gpg2
else
  _GPG=gpg
fi
crlGet="-L --max-redirs 10 -k -s --retry 10 --retry-delay 5 -A iCab"

###-------------SYSTEM-----------------###

find_fast_mirror() {
  isNetc=$(which netcat 2>&1)
  if [ ! -x "${isNetc}" ] || [ -z "${isNetc}" ]; then
    rm -f /etc/apt/sources.list.d/openssl.list
    apt-get update -qq &> /dev/null
    apt-get install netcat -fuy --force-yes --reinstall &> /dev/null
    sleep 3
  fi
  ffMirr=$(which ffmirror 2>&1)
  if [ -x "${ffMirr}" ]; then
    ffList="/var/backups/boa-mirrors.txt"
    mkdir -p /var/backups
    if [ ! -e "${ffList}" ]; then
      echo "jp.files.aegir.cc"  > ${ffList}
      echo "nl.files.aegir.cc" >> ${ffList}
      echo "uk.files.aegir.cc" >> ${ffList}
      echo "us.files.aegir.cc" >> ${ffList}
    fi
    if [ -e "${ffList}" ]; then
      _CHECK_MIRROR=$(bash ${ffMirr} < ${ffList} 2>&1)
      _USE_MIR="${_CHECK_MIRROR}"
      [[ "${_USE_MIR}" =~ "printf" ]] && _USE_MIR="files.aegir.cc"
    else
      _USE_MIR="files.aegir.cc"
    fi
  else
    _USE_MIR="files.aegir.cc"
  fi
  if ! netcat -w 10 -z "${_USE_MIR}" 80; then
    echo "INFO: The mirror ${_USE_MIR} doesn't respond, let's try default"
    _USE_MIR="files.aegir.cc"
  fi
  urlDev="http://${_USE_MIR}/dev"
  urlHmr="http://${_USE_MIR}/versions/master/aegir"
  urlStb="http://${_USE_MIR}/versions/stable"
}

extract_archive() {
  if [ ! -z "$1" ]; then
    case $1 in
      *.tar.bz2)   tar xjf $1    ;;
      *.tar.gz)    tar xzf $1    ;;
      *.bz2)       bunzip2 $1    ;;
      *.rar)       unrar x $1    ;;
      *.gz)        gunzip -q $1  ;;
      *.tar)       tar xf $1     ;;
      *.tbz2)      tar xjf $1    ;;
      *.tgz)       tar xzf $1    ;;
      *.zip)       unzip -qq $1  ;;
      *.Z)         uncompress $1 ;;
      *.7z)        7z x $1       ;;
      *)           echo "'$1' cannot be extracted via >extract<" ;;
    esac
    rm -f $1
  fi
}

get_dev_ext() {
  if [ ! -z "$1" ]; then
    curl ${crlGet} "${urlDev}/HEAD/$1" -o "$1"
    extract_archive "$1"
  fi
}

###----------------------------###
##    Manage ltd shell users    ##
###----------------------------###
#
# Remove dangerous stuff from the string.
sanitize_string() {
  echo "$1" | sed 's/[\\\/\^\?\>\`\#\"\{\(\$\@\&\|\*]//g; s/\(['"'"'\]\)//g'
}
#
# Add ltd-shell group if not exists.
add_ltd_group_if_not_exists() {
  _LTD_EXISTS=$(getent group ltd-shell 2>&1)
  if [[ "$_LTD_EXISTS" =~ "ltd-shell" ]]; then
    _DO_NOTHING=YES
  else
    addgroup --system ltd-shell &> /dev/null
  fi
}
#
# Enable chattr.
enable_chattr() {
  if [ ! -z "$1" ] && [ -d "/home/$1" ]; then
    _U_HD="/home/$1/.drush"
    _U_TP="/home/$1/.tmp"
    _U_II="${_U_HD}/php.ini"
    if [ ! -e "${_U_HD}/.ctrl.246stableU.txt" ]; then
      if [[ "${_CHECK_HOST}" =~ ".host8." ]] \
        || [[ "${_CHECK_HOST}" =~ ".boa.io" ]] \
        || [ "${_VMFAMILY}" = "VS" ]; then
        rm -f -r ${_U_HD}/*
        rm -f -r ${_U_HD}/.*
      else
        rm -f ${_U_HD}/{drush_make,registry_rebuild,clean_missing_modules}
        rm -f ${_U_HD}/{drupalgeddon,drush_ecl,make_local,safe_cache_form*}
        rm -f ${_U_HD}/usr/{drush_make,registry_rebuild,clean_missing_modules}
        rm -f ${_U_HD}/usr/{drupalgeddon,drush_ecl,make_local,safe_cache_form*}
        rm -f ${_U_HD}/.ctrl*
        rm -f -r ${_U_HD}/{cache,drush.ini,*drushrc*,*.inc}
      fi
      mkdir -p ${_U_HD}/usr
      mkdir -p ${_U_TP}
      touch ${_U_TP}
      find ${_U_TP}/ -mtime +0 -exec rm -rf {} \; &> /dev/null
      chown $1:${usrGroup} ${_U_TP}
      chown $1:${usrGroup} ${_U_HD}
      chmod 02755 ${_U_TP}
      chmod 02755 ${_U_HD}
      if [ ! -L "${_U_HD}/usr/registry_rebuild" ]; then
        ln -sf ${dscUsr}/.drush/usr/registry_rebuild \
          ${_U_HD}/usr/registry_rebuild
      fi
      if [ ! -L "${_U_HD}/usr/clean_missing_modules" ]; then
        ln -sf ${dscUsr}/.drush/usr/clean_missing_modules \
          ${_U_HD}/usr/clean_missing_modules
      fi
      if [ ! -L "${_U_HD}/usr/drupalgeddon" ]; then
        ln -sf ${dscUsr}/.drush/usr/drupalgeddon \
          ${_U_HD}/usr/drupalgeddon
      fi
      if [ ! -L "${_U_HD}/usr/drush_ecl" ]; then
        ln -sf ${dscUsr}/.drush/usr/drush_ecl \
          ${_U_HD}/usr/drush_ecl
      fi
      if [ ! -L "${_U_HD}/usr/make_local" ]; then
        ln -sf ${dscUsr}/.drush/usr/make_local \
          ${_U_HD}/usr/make_local
      fi
      if [ ! -L "${_U_HD}/usr/safe_cache_form_clear" ]; then
        ln -sf ${dscUsr}/.drush/usr/safe_cache_form_clear \
          ${_U_HD}/usr/safe_cache_form_clear
      fi
    fi

    _CHECK_USE_PHP_CLI=$(grep "/opt/php" \
      ${dscUsr}/tools/drush/drush.php 2>&1)
    _PHP_V="56 55 54 53"
    for e in ${_PHP_V}; do
      if [[ "$_CHECK_USE_PHP_CLI" =~ "php${e}" ]] \
        && [ ! -e "${_U_HD}/.ctrl.php${e}.txt" ]; then
        _PHP_CLI_UPDATE=YES
      fi
    done
    echo _PHP_CLI_UPDATE is ${_PHP_CLI_UPDATE} for $1

    if [ "${_PHP_CLI_UPDATE}" = "YES" ] \
      || [ ! -e "${_U_II}" ] \
      || [ ! -e "${_U_HD}/.ctrl.246stableU.txt" ]; then
      mkdir -p ${_U_HD}
      rm -f ${_U_HD}/.ctrl.php*
      rm -f ${_U_II}
      if [ ! -z "${_T_CLI_VRN}" ]; then
        _USE_PHP_CLI="${_T_CLI_VRN}"
        echo "_USE_PHP_CLI is ${_USE_PHP_CLI} for $1 at ${_USER} WTF"
        echo "_T_CLI_VRN is ${_T_CLI_VRN}"
      else
        _CHECK_USE_PHP_CLI=$(grep "/opt/php" \
          ${dscUsr}/tools/drush/drush.php 2>&1)
        echo "_CHECK_USE_PHP_CLI is $_CHECK_USE_PHP_CLI for $1 at ${_USER}"
        if [[ "$_CHECK_USE_PHP_CLI" =~ "php55" ]]; then
          _USE_PHP_CLI=5.5
        elif [[ "$_CHECK_USE_PHP_CLI" =~ "php56" ]]; then
          _USE_PHP_CLI=5.6
        elif [[ "$_CHECK_USE_PHP_CLI" =~ "php54" ]]; then
          _USE_PHP_CLI=5.4
        elif [[ "$_CHECK_USE_PHP_CLI" =~ "php53" ]]; then
          _USE_PHP_CLI=5.3
        fi
      fi
      echo _USE_PHP_CLI is ${_USE_PHP_CLI} for $1
      if [ "${_USE_PHP_CLI}" = "5.5" ]; then
        cp -af /opt/php55/lib/php.ini ${_U_II}
        _U_INI=55
      elif [ "${_USE_PHP_CLI}" = "5.6" ]; then
        cp -af /opt/php56/lib/php.ini ${_U_II}
        _U_INI=56
      elif [ "${_USE_PHP_CLI}" = "5.4" ]; then
        cp -af /opt/php54/lib/php.ini ${_U_II}
        _U_INI=54
      elif [ "${_USE_PHP_CLI}" = "5.3" ]; then
        cp -af /opt/php53/lib/php.ini ${_U_II}
        _U_INI=53
      fi
      if [ -e "${_U_II}" ]; then
        _INI="open_basedir = \".: \
          /data/all:        \
          /data/conf:       \
          /data/disk/all:   \
          /home/$1:         \
          /opt/php53:       \
          /opt/php54:       \
          /opt/php55:       \
          /opt/php56:       \
          /opt/tika:        \
          /opt/tika7:       \
          /opt/tika8:       \
          /opt/tika9:       \
          /opt/tools/drush: \
          /usr/bin:         \
          ${dscUsr}/.drush/usr: \
          ${dscUsr}/distro:     \
          ${dscUsr}/platforms:  \
          ${dscUsr}/static\""
        _INI=$(echo "${_INI}" | sed "s/ //g" 2>&1)
        _INI=$(echo "${_INI}" | sed "s/open_basedir=/open_basedir = /g" 2>&1)
        _INI=${_INI//\//\\\/}
        _QTP=${_U_TP//\//\\\/}
        sed -i "s/.*open_basedir =.*/${_INI}/g"                              ${_U_II}
        sed -i "s/.*error_reporting =.*/error_reporting = 1/g"               ${_U_II}
        sed -i "s/.*session.save_path =.*/session.save_path = ${_QTP}/g"     ${_U_II}
        sed -i "s/.*soap.wsdl_cache_dir =.*/soap.wsdl_cache_dir = ${_QTP}/g" ${_U_II}
        sed -i "s/.*sys_temp_dir =.*/sys_temp_dir = ${_QTP}/g"               ${_U_II}
        sed -i "s/.*upload_tmp_dir =.*/upload_tmp_dir = ${_QTP}/g"           ${_U_II}
        echo > ${_U_HD}/.ctrl.php${_U_INI}.txt
        echo > ${_U_HD}/.ctrl.246stableU.txt
      fi
    fi

    UQ="$1"
    if [ -f "${dscUsr}/static/control/compass.info" ]; then
      if [ -d "/home/${UQ}/.rvm/src" ]; then
        rm -f -r /home/${UQ}/.rvm/src/*
      fi
      if [ -d "/home/${UQ}/.rvm/archives" ]; then
        rm -f -r /home/${UQ}/.rvm/archives/*
      fi
      if [ -d "/home/${UQ}/.rvm/log" ]; then
        rm -f -r /home/${UQ}/.rvm/log/*
      fi
      if [ ! -x "/home/${UQ}/.rvm/bin/rvm" ]; then
        touch /var/run/manage_rvm_users.pid
        su -s /bin/bash - ${UQ} -c "$_GPG --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3"
        su -s /bin/bash - ${UQ} -c "\curl -sSL https://rvm.io/mpapis.asc | $_GPG --import"
        su -s /bin/bash   ${UQ} -c "\curl -sSL https://get.rvm.io | bash -s stable"
        su -s /bin/bash - ${UQ} -c "rvm get stable --auto-dotfiles"
        su -s /bin/bash - ${UQ} -c "echo rvm_autoupdate_flag=0 > ~/.rvmrc"
        rm -f /var/run/manage_rvm_users.pid
      fi
      su -s /bin/bash - ${UQ} -c "echo rvm_autoupdate_flag=0 > ~/.rvmrc"
      if [ ! -e "/home/${UQ}/.rvm/rubies/default" ]; then
        if [ -x "/bin/websh" ] && [ -L "/bin/sh" ]; then
          _WEB_SH=$(readlink -n /bin/sh 2>&1)
          _WEB_SH=$(echo -n ${_WEB_SH} | tr -d "\n" 2>&1)
          if [ -x "/bin/dash" ]; then
            if [ "${_WEB_SH}" != "/bin/dash" ]; then
              rm -f /bin/sh
              ln -s /bin/dash /bin/sh
            fi
          else
            if [ "${_WEB_SH}" != "/bin/bash" ]; then
              rm -f /bin/sh
              ln -s /bin/bash /bin/sh
            fi
          fi
        fi
        touch /var/run/manage_rvm_users.pid
        su -s /bin/bash - ${UQ} -c "rvm install ${_RUBY_VRN}"
        su -s /bin/bash - ${UQ} -c "rvm use ${_RUBY_VRN} --default"
        rm -f /var/run/manage_rvm_users.pid
        rm -f /bin/sh
        ln -s /bin/websh /bin/sh
      fi
      if [ ! -f "${dscUsr}/log/.gems.build.d.${UQ}.txt" ]; then
        rm -f ${dscUsr}/log/eventmachine*
        if [ -x "/bin/websh" ] && [ -L "/bin/sh" ]; then
          _WEB_SH=$(readlink -n /bin/sh 2>&1)
          _WEB_SH=$(echo -n ${_WEB_SH} | tr -d "\n" 2>&1)
          if [ -x "/bin/dash" ]; then
            if [ "${_WEB_SH}" != "/bin/dash" ]; then
              rm -f /bin/sh
              ln -s /bin/dash /bin/sh
            fi
          else
            if [ "${_WEB_SH}" != "/bin/bash" ]; then
              rm -f /bin/sh
              ln -s /bin/bash /bin/sh
            fi
          fi
        fi
        touch /var/run/manage_rvm_users.pid
        su -s /bin/bash - ${UQ} -c "rvm all do gem install --conservative bluecloth"      &> /dev/null
        su -s /bin/bash - ${UQ} -c "rvm all do gem install --conservative eventmachine"   &> /dev/null
        su -s /bin/bash - ${UQ} -c "rvm all do gem install --version 1.0.3 eventmachine"  &> /dev/null
        su -s /bin/bash - ${UQ} -c "rvm all do gem install --conservative ffi"            &> /dev/null
        su -s /bin/bash - ${UQ} -c "rvm all do gem install --version 1.9.3 ffi"           &> /dev/null
        su -s /bin/bash - ${UQ} -c "rvm all do gem install --conservative hitimes"        &> /dev/null
        su -s /bin/bash - ${UQ} -c "rvm all do gem install --conservative http_parser.rb" &> /dev/null
        su -s /bin/bash - ${UQ} -c "rvm all do gem install --conservative oily_png"       &> /dev/null
        su -s /bin/bash - ${UQ} -c "rvm all do gem install --version 1.1.1 oily_png"      &> /dev/null
        su -s /bin/bash - ${UQ} -c "rvm all do gem install --conservative yajl-ruby"      &> /dev/null
        touch ${dscUsr}/log/.gems.build.d.${UQ}.txt
        rm -f /var/run/manage_rvm_users.pid
        rm -f /bin/sh
        ln -s /bin/websh /bin/sh
      fi
      if [ -d "/home/${UQ}/.rvm/src" ]; then
        rm -f -r /home/${UQ}/.rvm/src/*
      fi
      if [ -d "/home/${UQ}/.rvm/archives" ]; then
        rm -f -r /home/${UQ}/.rvm/archives/*
      fi
      if [ -d "/home/${UQ}/.rvm/log" ]; then
        rm -f -r /home/${UQ}/.rvm/log/*
      fi
      rm -f /home/${UQ}/{.profile,.bash_logout,.bash_profile,.bashrc,.zlogin,.zshrc}
      rm -f /home/${UQ}/.rvm/scripts/notes
    else
      if [ -d "/home/${UQ}/.rvm" ] || [ -d "/home/${UQ}/.gem" ]; then
        rm -f ${dscUsr}/log/.gems.build*
        rm -f -r /home/${UQ}/.rvm    &> /dev/null
        rm -f -r /home/${UQ}/.gem    &> /dev/null
      fi
    fi

    if [ "$1" != "${_USER}.ftp" ]; then
      chattr +i /home/$1             &> /dev/null
    else
      chattr +i /home/$1/platforms   &> /dev/null
      chattr +i /home/$1/platforms/* &> /dev/null
    fi
    if [ -d "/home/$1/.bazaar" ]; then
      chattr +i /home/$1/.bazaar     &> /dev/null
    fi
    chattr +i /home/$1/.drush        &> /dev/null
    chattr +i /home/$1/.drush/usr    &> /dev/null
    chattr +i /home/$1/.drush/*.ini  &> /dev/null
  fi
}
#
# Disable chattr.
disable_chattr() {
  if [ ! -z "$1" ] && [ -d "/home/$1" ]; then
    if [ "$1" != "${_USER}.ftp" ]; then
      chattr -i /home/$1             &> /dev/null
    else
      chattr -i /home/$1/platforms   &> /dev/null
      chattr -i /home/$1/platforms/* &> /dev/null
    fi
    if [ -d "/home/$1/.bazaar" ]; then
      chattr -i /home/$1/.bazaar     &> /dev/null
    fi
    chattr -i /home/$1/.drush        &> /dev/null
    chattr -i /home/$1/.drush/usr    &> /dev/null
    chattr -i /home/$1/.drush/*.ini  &> /dev/null
    usrTgt="/home/$1/.drush/usr"
    if [ "$1" != "${_USER}.ftp" ]; then
      if [ ! -L "${usrTgt}/drupalgeddon" ] && [ -d "${usrDgn}" ]; then
        ln -sf ${usrDgn} ${usrTgt}/drupalgeddon
      fi
    else
      if [ ! -L "${usrTgt}/drupalgeddon" ] && [ -d "${usrDgn}" ]; then
        rm -f -r ${usrTgt}/drupalgeddon
        ln -sf ${usrDgn} ${usrTgt}/drupalgeddon
      fi
    fi
  fi
}
#
# Kill zombies.
kill_zombies() {
for Existing in `cat /etc/passwd | cut -d ':' -f1 | sort`; do
  _SEC_IDY=$(id -nG ${Existing} 2>&1)
  if [[ "$_SEC_IDY" =~ "ltd-shell" ]]; then
    usrParent=$(echo ${Existing} | cut -d. -f1 | awk '{ print $1}' 2>&1)
    _PAR_DIR="/data/disk/${usrParent}/clients"
    _SEC_SYM="/home/${Existing}/sites"
    _SEC_DIR=$(readlink -n ${_SEC_SYM} 2>&1)
    _SEC_DIR=$(echo -n ${_SEC_DIR} | tr -d "\n" 2>&1)
    if [ ! -L "${_SEC_SYM}" ] || [ ! -e "${_SEC_DIR}" ] \
      || [ ! -e "/home/${usrParent}.ftp/users/${Existing}" ]; then
      disable_chattr ${Existing}
      deluser \
        --remove-home \
        --backup-to /var/backups/zombie/deleted ${Existing} &> /dev/null
      rm -f /home/${usrParent}.ftp/users/${Existing}
      echo Zombie ${Existing} killed
      echo
    fi
  fi
done
}
#
# Fix dot dirs.
fix_dot_dirs() {
  usrTmp="/home/${usrLtd}/.tmp"
  if [ ! -d "${usrTmp}" ]; then
    mkdir -p ${usrTmp}
    chown ${usrLtd}:${usrGroup} ${usrTmp}
    chmod 02755 ${usrTmp}
  fi
  usrLftp="/home/${usrLtd}/.lftp"
  if [ ! -d "${usrLftp}" ]; then
    mkdir -p ${usrLftp}
    chown ${usrLtd}:${usrGroup} ${usrLftp}
    chmod 02755 ${usrLftp}
  fi
  usrLhist="/home/${usrLtd}/.lhistory"
  if [ ! -e "${usrLhist}" ]; then
    touch ${usrLhist}
    chown ${usrLtd}:${usrGroup} ${usrLhist}
    chmod 644 ${usrLhist}
  fi
  usrDrush="/home/${usrLtd}/.drush"
  if [ ! -d "${usrDrush}" ]; then
    mkdir -p ${usrDrush}
    chown ${usrLtd}:${usrGroup} ${usrDrush}
    chmod 700 ${usrDrush}
  fi
  usrSsh="/home/${usrLtd}/.ssh"
  if [ ! -d "${usrSsh}" ]; then
    mkdir -p ${usrSsh}
    chown -R ${usrLtd}:${usrGroup} ${usrSsh}
    chmod 700 ${usrSsh}
  fi
  chmod 600 ${usrSsh}/id_{r,d}sa &> /dev/null
  chmod 600 ${usrSsh}/known_hosts &> /dev/null
  usrBzr="/home/${usrLtd}/.bazaar"
  if [ -x "/usr/local/bin/bzr" ]; then
    if [ ! -e "${usrBzr}/bazaar.conf" ]; then
      mkdir -p ${usrBzr}
      echo ignore_missing_extensions=True > ${usrBzr}/bazaar.conf
      chown -R ${usrLtd}:${usrGroup} ${usrBzr}
      chmod 700 ${usrBzr}
    fi
  else
    rm -f -r ${usrBzr}
  fi
}
#
# Manage Drush Aliases.
manage_sec_user_drush_aliases() {
  rm -f ${usrLtdRoot}/sites
  ln -sf $Client ${usrLtdRoot}/sites
  mkdir -p ${usrLtdRoot}/.drush
  for Alias in `find ${usrLtdRoot}/.drush/*.alias.drushrc.php \
    -maxdepth 1 -type f | sort`; do
    AliasName=$(echo "$Alias" | cut -d'/' -f5 | awk '{ print $1}' 2>&1)
    AliasName=$(echo "${AliasName}" \
      | sed "s/.alias.drushrc.php//g" \
      | awk '{ print $1}' 2>&1)
    if [ ! -z "${AliasName}" ] \
      && [ ! -e "${usrLtdRoot}/sites/${AliasName}" ]; then
      rm -f ${usrLtdRoot}/.drush/${AliasName}.alias.drushrc.php
    fi
  done
  for Symlink in `find ${usrLtdRoot}/sites/ \
    -maxdepth 1 -mindepth 1 | sort`; do
    SiteName=$(echo $Symlink \
      | cut -d'/' -f5 \
      | awk '{ print $1}' 2>&1)
    pthAliasMain="${pthParentUsr}/.drush/${SiteName}.alias.drushrc.php"
    pthAliasCopy="${usrLtdRoot}/.drush/${SiteName}.alias.drushrc.php"
    if [ ! -z "$SiteName" ] && [ ! -e "${pthAliasCopy}" ]; then
      cp -af ${pthAliasMain} ${pthAliasCopy}
      chmod 440 ${pthAliasCopy}
    elif [ ! -z "$SiteName" ]  && [ -e "${pthAliasCopy}" ]; then
      _DIFF_T=$(diff ${pthAliasCopy} ${pthAliasMain} 2>&1)
      if [ ! -z "${_DIFF_T}" ]; then
        cp -af ${pthAliasMain} ${pthAliasCopy}
        chmod 440 ${pthAliasCopy}
      fi
    fi
  done
}
#
# OK, create user.
ok_create_user() {
  _ADMIN="${_USER}.ftp"
  echo "_ADMIN is == ${_ADMIN} == at ok_create_user"
  usrLtdRoot="/home/${usrLtd}"
  _SEC_SYM="${usrLtdRoot}/sites"
  _TMP="/var/tmp"
  if [ ! -L "${_SEC_SYM}" ]; then
    mkdir -p /var/backups/zombie/deleted/${_NOW}
    mv -f ${usrLtdRoot} /var/backups/zombie/deleted/${_NOW}/ &> /dev/null
  fi
  if [ ! -d "${usrLtdRoot}" ]; then
    if [ -e "/usr/bin/mysecureshell" ] && [ -e "/etc/ssh/sftp_config" ]; then
      useradd -d ${usrLtdRoot} -s /usr/bin/mysecureshell -m -N -r ${usrLtd}
      echo "usrLtdRoot is == ${usrLtdRoot} == at ok_create_user"
    else
      useradd -d ${usrLtdRoot} -s /usr/bin/lshell -m -N -r ${usrLtd}
    fi
    adduser ${usrLtd} ${_WEBG}
    _ESC_LUPASS=""
    _LEN_LUPASS=0
    if [ "${_STRONG_PASSWORDS}" = "YES" ]  ; then
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
      _ESC_LUPASS=$(randpass "${_PWD_CHARS}" alnum 2>&1)
      _ESC_LUPASS=$(echo -n "${_ESC_LUPASS}" | tr -d "\n" 2>&1)
      _LEN_LUPASS=$(echo ${#_ESC_LUPASS} 2>&1)
    fi
    if [ -z "${_ESC_LUPASS}" ] || [ "${_LEN_LUPASS}" -lt "9" ]; then
      _ESC_LUPASS=$(pwgen -v -s -1 2>&1)
      _ESC_LUPASS=$(echo -n "${_ESC_LUPASS}" | tr -d "\n" 2>&1)
      _ESC_LUPASS=$(sanitize_string "${_ESC_LUPASS}" 2>&1)
    fi
    ph=$(mkpasswd -m sha-512 "${_ESC_LUPASS}" \
      $(openssl rand -base64 16 | tr -d '+=' | head -c 16) 2>&1)
    usermod -p $ph ${usrLtd}
    passwd -w 7 -x 90 ${usrLtd}
    usermod -aG lshellg ${usrLtd}
    usermod -aG ltd-shell ${usrLtd}
  fi
  if [ ! -e "/home/${_ADMIN}/users/${usrLtd}" ] \
    && [ ! -z "${_ESC_LUPASS}" ]; then
    if [ -e "/usr/bin/mysecureshell" ] \
      && [ -e "/etc/ssh/sftp_config" ]; then
      chsh -s /usr/bin/mysecureshell ${usrLtd}
    else
      chsh -s /usr/bin/lshell ${usrLtd}
    fi
    echo >> ${_THIS_LTD_CONF}
    echo "[${usrLtd}]" >> ${_THIS_LTD_CONF}
    echo "path : [${_ALLD_DIR}]" >> ${_THIS_LTD_CONF}
    chmod 700 ${usrLtdRoot}
    mkdir -p /home/${_ADMIN}/users
    echo "${_ESC_LUPASS}" > /home/${_ADMIN}/users/${usrLtd}
  fi
  fix_dot_dirs
  rm -f ${usrLtdRoot}/{.profile,.bash_logout,.bash_profile,.bashrc}
}
#
# OK, update user.
ok_update_user() {
  _ADMIN="${_USER}.ftp"
  usrLtdRoot="/home/${usrLtd}"
  if [ -e "/home/${_ADMIN}/users/${usrLtd}" ]; then
    echo >> ${_THIS_LTD_CONF}
    echo "[${usrLtd}]" >> ${_THIS_LTD_CONF}
    echo "path : [${_ALLD_DIR}]" >> ${_THIS_LTD_CONF}
    manage_sec_user_drush_aliases
    chmod 700 ${usrLtdRoot}
  fi
  fix_dot_dirs
  rm -f ${usrLtdRoot}/{.profile,.bash_logout,.bash_profile,.bashrc}
}
#
# Add user if not exists.
add_user_if_not_exists() {
  _ID_EXISTS=$(getent passwd ${usrLtd} 2>&1)
  _ID_SHELLS=$(id -nG ${usrLtd} 2>&1)
  echo "_ID_EXISTS is == ${_ID_EXISTS} == at add_user_if_not_exists"
  echo "_ID_SHELLS is == $_ID_SHELLS == at add_user_if_not_exists"
  if [ -z "${_ID_EXISTS}" ]; then
    echo "We will create user == ${usrLtd} =="
    ok_create_user
    manage_sec_user_drush_aliases
    enable_chattr ${usrLtd}
  elif [[ "${_ID_EXISTS}" =~ "${usrLtd}" ]] \
    && [[ "$_ID_SHELLS" =~ "ltd-shell" ]]; then
    echo "We will update user == ${usrLtd} =="
    disable_chattr ${usrLtd}
    rm -f -r /home/${usrLtd}/drush-backups
    usrTmp="/home/${usrLtd}/.tmp"
    if [ ! -d "${usrTmp}" ]; then
      mkdir -p ${usrTmp}
      chown ${usrLtd}:${usrGroup} ${usrTmp}
      chmod 02755 ${usrTmp}
    fi
    touch ${usrTmp}
    find ${usrTmp}/ -mtime +0 -exec rm -rf {} \; &> /dev/null
    ok_update_user
    enable_chattr ${usrLtd}
  fi
}
#
# Manage Access Paths.
manage_sec_access_paths() {
#for Domain in `find $Client/ -maxdepth 1 -mindepth 1 -type l -printf %P\\n | sort`
for Domain in `find $Client/ -maxdepth 1 -mindepth 1 -type l | sort`; do
  _PATH_DOM=$(readlink -n ${Domain} 2>&1)
  _PATH_DOM=$(echo -n ${_PATH_DOM} | tr -d "\n" 2>&1)
  _ALLD_DIR="${_ALLD_DIR}, '${_PATH_DOM}'"
  if [ -e "${_PATH_DOM}" ]; then
    _ALLD_NUM=$(( _ALLD_NUM += 1 ))
  fi
  echo Done for ${Domain} at $Client
done
}
#
# Manage Secondary Users.
manage_sec() {
for Client in `find ${pthParentUsr}/clients/ -maxdepth 1 -mindepth 1 -type d | sort`; do
  usrLtd=$(echo $Client | cut -d'/' -f6 | awk '{ print $1}' 2>&1)
  usrLtd=${usrLtd//[^a-zA-Z0-9]/}
  usrLtd=$(echo -n ${usrLtd} | tr A-Z a-z 2>&1)
  usrLtd="${_USER}.${usrLtd}"
  echo "usrLtd is == ${usrLtd} == at manage_sec"
  _ALLD_NUM="0"
  _ALLD_CTL="1"
  _ALLD_DIR="'$Client'"
  cd $Client
  manage_sec_access_paths
  #_ALLD_DIR="${_ALLD_DIR}, '/home/${usrLtd}'"
  if [ "$_ALLD_NUM" -ge "$_ALLD_CTL" ]; then
    add_user_if_not_exists
    echo Done for $Client at ${pthParentUsr}
  else
    echo Empty $Client at ${pthParentUsr} - deleting now
    if [ -e "$Client" ]; then
      rmdir $Client
    fi
  fi
done
}
#
# Update local INI for PHP CLI on the Aegir Satellite Instance.
update_php_cli_local_ini() {
  _U_HD="${dscUsr}/.drush"
  _U_TP="${dscUsr}/.tmp"
  _U_II="${_U_HD}/php.ini"
  _PHP_CLI_UPDATE=NO
  _CHECK_USE_PHP_CLI=$(grep "/opt/php" ${_DRUSH_FILE} 2>&1)
  _PHP_V="56 55 54 53"
  for e in ${_PHP_V}; do
    if [[ "$_CHECK_USE_PHP_CLI" =~ "php${e}" ]] \
      && [ ! -e "${_U_HD}/.ctrl.php${e}.txt" ]; then
      _PHP_CLI_UPDATE=YES
    fi
  done
  if [ "${_PHP_CLI_UPDATE}" = "YES" ] \
    || [ ! -e "${_U_II}" ] \
    || [ ! -d "${_U_TP}" ] \
    || [ ! -e "${_U_HD}/.ctrl.246stableU.txt" ]; then
    mkdir -p ${_U_TP}
    touch ${_U_TP}
    find ${_U_TP}/ -mtime +0 -exec rm -rf {} \; &> /dev/null
    mkdir -p ${_U_HD}
    chown ${_USER}:${usrGroup} ${_U_TP}
    chown ${_USER}:${usrGroup} ${_U_HD}
    chmod 755 ${_U_TP}
    chmod 755 ${_U_HD}
    chattr -i ${_U_II}
    rm -f ${_U_HD}/.ctrl.php*
    rm -f ${_U_II}
    if [[ "$_CHECK_USE_PHP_CLI" =~ "php55" ]]; then
      cp -af /opt/php55/lib/php.ini ${_U_II}
      _U_INI=55
    elif [[ "$_CHECK_USE_PHP_CLI" =~ "php56" ]]; then
      cp -af /opt/php56/lib/php.ini ${_U_II}
      _U_INI=56
    elif [[ "$_CHECK_USE_PHP_CLI" =~ "php54" ]]; then
      cp -af /opt/php54/lib/php.ini ${_U_II}
      _U_INI=54
    elif [[ "$_CHECK_USE_PHP_CLI" =~ "php53" ]]; then
      cp -af /opt/php53/lib/php.ini ${_U_II}
      _U_INI=53
    fi
    if [ -e "${_U_II}" ]; then
      _INI="open_basedir = \".: \
        /data/all:           \
        /data/conf:          \
        /data/disk/all:      \
        /opt/php53:          \
        /opt/php54:          \
        /opt/php55:          \
        /opt/php56:          \
        /opt/tika:           \
        /opt/tika7:          \
        /opt/tika8:          \
        /opt/tika9:          \
        /opt/tmp/make_local: \
        /opt/tools/drush:    \
        ${dscUsr}:           \
        /usr/bin\""
      _INI=$(echo "${_INI}" | sed "s/ //g" 2>&1)
      _INI=$(echo "${_INI}" | sed "s/open_basedir=/open_basedir = /g" 2>&1)
      _INI=${_INI//\//\\\/}
      _QTP=${_U_TP//\//\\\/}
      sed -i "s/.*open_basedir =.*/${_INI}/g"                              ${_U_II}
      sed -i "s/.*error_reporting =.*/error_reporting = 1/g"               ${_U_II}
      sed -i "s/.*session.save_path =.*/session.save_path = ${_QTP}/g"     ${_U_II}
      sed -i "s/.*soap.wsdl_cache_dir =.*/soap.wsdl_cache_dir = ${_QTP}/g" ${_U_II}
      sed -i "s/.*sys_temp_dir =.*/sys_temp_dir = ${_QTP}/g"               ${_U_II}
      sed -i "s/.*upload_tmp_dir =.*/upload_tmp_dir = ${_QTP}/g"           ${_U_II}
      echo > ${_U_HD}/.ctrl.php${_U_INI}.txt
      echo > ${_U_HD}/.ctrl.246stableU.txt
    fi
    chattr +i ${_U_II}
  fi
}
#
# Update PHP-CLI for Drush.
update_php_cli_drush() {
  _DRUSH_FILE="${dscUsr}/tools/drush/drush.php"
  if [ "${_T_CLI_VRN}" = "5.5" ] && [ -x "/opt/php55/bin/php" ]; then
    sed -i "s/^#\!\/.*/#\!\/opt\/php55\/bin\/php/g"  ${_DRUSH_FILE} &> /dev/null
    _T_CLI=/opt/php55/bin
  elif [ "${_T_CLI_VRN}" = "5.6" ] && [ -x "/opt/php56/bin/php" ]; then
    sed -i "s/^#\!\/.*/#\!\/opt\/php56\/bin\/php/g"  ${_DRUSH_FILE} &> /dev/null
    _T_CLI=/opt/php56/bin
  elif [ "${_T_CLI_VRN}" = "5.4" ] && [ -x "/opt/php54/bin/php" ]; then
    sed -i "s/^#\!\/.*/#\!\/opt\/php54\/bin\/php/g"  ${_DRUSH_FILE} &> /dev/null
    _T_CLI=/opt/php54/bin
  elif [ "${_T_CLI_VRN}" = "5.3" ] && [ -x "/opt/php53/bin/php" ]; then
    sed -i "s/^#\!\/.*/#\!\/opt\/php53\/bin\/php/g"  ${_DRUSH_FILE} &> /dev/null
    _T_CLI=/opt/php53/bin
  else
    _T_CLI=/foo/bar
  fi
  if [ -x "${_T_CLI}/php" ]; then
    _DRUSHCMD="${_T_CLI}/php ${dscUsr}/tools/drush/drush.php"
    if [ -e "${dscUsr}/aegir.sh" ]; then
      rm -f ${dscUsr}/aegir.sh
    fi
    touch ${dscUsr}/aegir.sh
    echo -e "#!/bin/bash\n\nPATH=.:${_T_CLI}:/usr/sbin:/usr/bin:/sbin:/bin\n${_DRUSHCMD} \
      '@hostmaster' hosting-dispatch\ntouch ${dscUsr}/${_USER}-task.done" \
      | fmt -su -w 2500 | tee -a ${dscUsr}/aegir.sh >/dev/null 2>&1
    chown ${_USER}:${usrGroup} ${dscUsr}/aegir.sh &> /dev/null
    chmod 0700 ${dscUsr}/aegir.sh &> /dev/null
  fi
}
#
# Tune FPM workers.
satellite_tune_fpm_workers() {
  _ETH_TEST=$(ifconfig 2>&1)
  _AWS_TEST_A=$(grep cloudimg /etc/fstab 2>&1)
  _AWS_TEST_B=$(grep cloudconfig /etc/fstab 2>&1)
  if [[ "${_ETH_TEST}" =~ "venet0" ]]; then
    _VMFAMILY="VZ"
  elif [ -e "/proc/bean_counters" ]; then
    _VMFAMILY="VZ"
  else
    _VMFAMILY="XEN"
  fi
  if [[ "${_VM_TEST}" =~ "3.6.14-beng" ]] \
    || [[ "${_VM_TEST}" =~ "3.2.12-beng" ]] \
    || [[ "${_VM_TEST}" =~ "3.6.15-beng" ]]; then
    _VMFAMILY="VS"
  fi
  if [[ "${_AWS_TEST_A}" =~ "cloudimg" ]] \
    || [[ "${_AWS_TEST_B}" =~ "cloudconfig" ]]; then
    _VMFAMILY="AWS"
  fi
  _RAM=$(free -mto | grep Mem: | awk '{ print $2 }' 2>&1)
  if [ "${_RESERVED_RAM}" -gt "0" ]; then
    _RAM=$(( _RAM - _RESERVED_RAM ))
  fi
  _USE=$(( _RAM / 4 ))
  if [ "${_USE}" -ge "512" ] && [ "${_USE}" -lt "1024" ]; then
    if [ "${_PHP_FPM_WORKERS}" = "AUTO" ]; then
      _L_PHP_FPM_WORKERS=24
    else
      _L_PHP_FPM_WORKERS=${_PHP_FPM_WORKERS}
    fi
  elif [ "${_USE}" -ge "1024" ]; then
    if [ "${_VMFAMILY}" = "XEN" ] || [ "${_VMFAMILY}" = "AWS" ]; then
      if [ "${_PHP_FPM_WORKERS}" = "AUTO" ]; then
        _L_PHP_FPM_WORKERS=48
      else
        _L_PHP_FPM_WORKERS=${_PHP_FPM_WORKERS}
      fi
    elif [ "${_VMFAMILY}" = "VS" ] || [ "${_VMFAMILY}" = "TG" ]; then
      if [ -e "/boot/grub/grub.cfg" ] \
        || [ -e "/boot/grub/menu.lst" ] \
        || [ -e "/root/.tg.cnf" ]; then
        if [ "${_PHP_FPM_WORKERS}" = "AUTO" ]; then
          _L_PHP_FPM_WORKERS=48
        else
          _L_PHP_FPM_WORKERS=${_PHP_FPM_WORKERS}
        fi
      else
        if [ "${_PHP_FPM_WORKERS}" = "AUTO" ]; then
          _L_PHP_FPM_WORKERS=24
        else
          _L_PHP_FPM_WORKERS=${_PHP_FPM_WORKERS}
        fi
      fi
    else
      if [ "${_PHP_FPM_WORKERS}" = "AUTO" ]; then
        _L_PHP_FPM_WORKERS=24
      else
        _L_PHP_FPM_WORKERS=${_PHP_FPM_WORKERS}
      fi
    fi
  else
    if [ "${_PHP_FPM_WORKERS}" = "AUTO" ]; then
      _L_PHP_FPM_WORKERS=6
    else
      _L_PHP_FPM_WORKERS=${_PHP_FPM_WORKERS}
    fi
  fi
}
#
# Disable New Relic per Octopus instance.
disable_newrelic() {
  _PHP_SV=${_PHP_FPM_VERSION//[^0-9]/}
  if [ -z "${_PHP_SV}" ]; then
    _PHP_SV=55
  fi
  _THIS_POOL_TPL="/opt/php${_PHP_SV}/etc/pool.d/${_USER}.conf"
  if [ -e "$_THIS_POOL_TPL" ]; then
    _CHECK_NEW_RELIC_KEY=$(grep "newrelic.enabled.*true" $_THIS_POOL_TPL 2>&1)
    if [[ "$_CHECK_NEW_RELIC_KEY" =~ "newrelic.enabled" ]]; then
      echo New Relic for ${_USER} will be disabled because newrelic.info does not exist
      sed -i "s/^php_admin_value\[newrelic.license\].*/php_admin_value\[newrelic.license\] = \"\"/g" $_THIS_POOL_TPL
      sed -i "s/^php_admin_value\[newrelic.enabled\].*/php_admin_value\[newrelic.enabled\] = \"false\"/g" $_THIS_POOL_TPL
      if [ -e "/etc/init.d/php${_PHP_SV}-fpm" ]; then
        service php${_PHP_SV}-fpm reload
      fi
    fi
  fi
}
#
# Enable New Relic per Octopus instance.
enable_newrelic() {
  _LOC_NEW_RELIC_KEY=$(cat ${dscUsr}/static/control/newrelic.info 2>&1)
  _LOC_NEW_RELIC_KEY=${_LOC_NEW_RELIC_KEY//[^0-9a-zA-Z]/}
  _LOC_NEW_RELIC_KEY=$(echo -n $_LOC_NEW_RELIC_KEY | tr -d "\n" 2>&1)
  if [ -z "$_LOC_NEW_RELIC_KEY" ]; then
    disable_newrelic
  else
    _PHP_SV=${_PHP_FPM_VERSION//[^0-9]/}
    if [ -z "${_PHP_SV}" ]; then
      _PHP_SV=55
    fi
    _THIS_POOL_TPL="/opt/php${_PHP_SV}/etc/pool.d/${_USER}.conf"
    if [ -e "$_THIS_POOL_TPL" ]; then
      _CHECK_NEW_RELIC_TPL=$(grep "newrelic.license" $_THIS_POOL_TPL 2>&1)
      _CHECK_NEW_RELIC_KEY=$(grep "$_LOC_NEW_RELIC_KEY" $_THIS_POOL_TPL 2>&1)
      if [[ "$_CHECK_NEW_RELIC_KEY" =~ "$_LOC_NEW_RELIC_KEY" ]]; then
        echo "New Relic integration is already active for ${_USER}"
      else
        if [[ "$_CHECK_NEW_RELIC_TPL" =~ "newrelic.license" ]]; then
          echo "New Relic for ${_USER} update with key \
            $_LOC_NEW_RELIC_KEY in php${_PHP_SV}"
          sed -i "s/^php_admin_value\[newrelic.license\].*/php_admin_value\[newrelic.license\] = \"$_LOC_NEW_RELIC_KEY\"/g" $_THIS_POOL_TPL
          sed -i "s/^php_admin_value\[newrelic.enabled\].*/php_admin_value\[newrelic.enabled\] = \"true\"/g" $_THIS_POOL_TPL
        else
          echo New Relic for ${_USER} setup with key $_LOC_NEW_RELIC_KEY in php${_PHP_SV}
          echo "php_admin_value[newrelic.license] = \"$_LOC_NEW_RELIC_KEY\"" >> $_THIS_POOL_TPL
          echo "php_admin_value[newrelic.enabled] = \"true\"" >> $_THIS_POOL_TPL
        fi
        if [ -e "/etc/init.d/php${_PHP_SV}-fpm" ]; then
          service php${_PHP_SV}-fpm reload
        fi
      fi
    fi
  fi
}
#
# Switch New Relic on or off per Octopus instance.
switch_newrelic() {
  if [ -e "${dscUsr}/static/control/newrelic.info" ]; then
    enable_newrelic
  else
    disable_newrelic
  fi
}
#
# Update web user.
satellite_update_web_user() {
  _T_HD="/home/${_WEB}/.drush"
  _T_TP="/home/${_WEB}/.tmp"
  _T_TS="/home/${_WEB}/.aws"
  _T_II="${_T_HD}/php.ini"
  if [ -e "/home/${_WEB}" ]; then
    chattr -i /home/${_WEB} &> /dev/null
    chattr -i /home/${_WEB}/.drush &> /dev/null
    mkdir -p /home/${_WEB}/.{tmp,drush,aws}
    if [ ! -z "$1" ]; then
      if [ "$1" = "hhvm" ]; then
        if [ -e "/opt/php56/etc/php56.ini" ] \
          && [ -x "/opt/php56/bin/php" ]; then
          _T_PV=56
        elif [ -e "/opt/php55/etc/php55.ini" ] \
          && [ -x "/opt/php55/bin/php" ]; then
          _T_PV=55
        fi
      else
        _T_PV=$1
      fi
    fi
    if [ ! -z "${_T_PV}" ] && [ -e "/opt/php${_T_PV}/etc/php${_T_PV}.ini" ]; then
      cp -af /opt/php${_T_PV}/etc/php${_T_PV}.ini ${_T_II}
    else
      if [ -e "/opt/php55/etc/php55.ini" ]; then
        cp -af /opt/php55/etc/php55.ini ${_T_II}
        _T_PV=55
      elif [ -e "/opt/php56/etc/php56.ini" ]; then
        cp -af /opt/php56/etc/php56.ini ${_T_II}
        _T_PV=56
      elif [ -e "/opt/php54/etc/php54.ini" ]; then
        cp -af /opt/php54/etc/php54.ini ${_T_II}
        _T_PV=54
      elif [ -e "/opt/php53/etc/php53.ini" ]; then
        cp -af /opt/php53/etc/php53.ini ${_T_II}
        _T_PV=53
      fi
    fi
    if [ -e "${_T_II}" ]; then
      _INI="open_basedir = \".: \
        /data/all:      \
        /data/conf:     \
        /data/disk/all: \
        /mnt:           \
        /opt/php53:     \
        /opt/php54:     \
        /opt/php55:     \
        /opt/php56:     \
        /opt/tika:      \
        /opt/tika7:     \
        /opt/tika8:     \
        /opt/tika9:     \
        /srv:           \
        /usr/bin:       \
        /var/second/${_USER}:     \
        ${dscUsr}/aegir:          \
        ${dscUsr}/backup-exports: \
        ${dscUsr}/distro:         \
        ${dscUsr}/platforms:      \
        ${dscUsr}/static:         \
        ${_T_HD}:                 \
        ${_T_TP}:                 \
        ${_T_TS}\""
      _INI=$(echo "${_INI}" | sed "s/ //g" 2>&1)
      _INI=$(echo "${_INI}" | sed "s/open_basedir=/open_basedir = /g" 2>&1)
      _INI=${_INI//\//\\\/}
      _QTP=${_T_TP//\//\\\/}
      sed -i "s/.*open_basedir =.*/${_INI}/g"                              ${_T_II}
      sed -i "s/.*session.save_path =.*/session.save_path = ${_QTP}/g"     ${_T_II}
      sed -i "s/.*soap.wsdl_cache_dir =.*/soap.wsdl_cache_dir = ${_QTP}/g" ${_T_II}
      sed -i "s/.*sys_temp_dir =.*/sys_temp_dir = ${_QTP}/g"               ${_T_II}
      sed -i "s/.*upload_tmp_dir =.*/upload_tmp_dir = ${_QTP}/g"           ${_T_II}
      if [ "$1" = "hhvm" ]; then
        sed -i "s/.*ioncube.*//g" ${_T_II}
        sed -i "s/.*opcache.*//g" ${_T_II}
      fi
      rm -f ${_T_HD}/.ctrl.php*
      echo > ${_T_HD}/.ctrl.php${_T_PV}.txt
    fi
    chmod 700 /home/${_WEB}
    chown -R ${_WEB}:${_WEBG} /home/${_WEB}
    chmod 550 /home/${_WEB}/.drush
    chmod 440 /home/${_WEB}/.drush/php.ini
    chattr +i /home/${_WEB} &> /dev/null
    chattr +i /home/${_WEB}/.drush &> /dev/null
  fi
}
#
# Remove web user.
satellite_remove_web_user() {
  if [ -e "/home/${_WEB}/.tmp" ] || [ "$1" = "clean" ]; then
    chattr -i /home/${_WEB} &> /dev/null
    chattr -i /home/${_WEB}/.drush &> /dev/null
    deluser \
      --remove-home \
      --backup-to /var/backups/zombie/deleted ${_WEB} &> /dev/null
    if [ -e "/home/${_WEB}" ]; then
      rm -f -r /home/${_WEB} &> /dev/null
    fi
  fi
}
#
# Add web user.
satellite_create_web_user() {
  _T_HD="/home/${_WEB}/.drush"
  _T_II="${_T_HD}/php.ini"
  _T_ID_EXISTS=$(getent passwd ${_WEB} 2>&1)
  if [ ! -z "${_T_ID_EXISTS}" ] && [ -e "${_T_II}" ]; then
    satellite_update_web_user "$1"
  elif [ -z "${_T_ID_EXISTS}" ] || [ ! -e "${_T_II}" ]; then
    satellite_remove_web_user "clean"
    adduser --force-badname --system --ingroup www-data ${_WEB} &> /dev/null
    satellite_update_web_user "$1"
  fi
}
#
# Switch PHP Version.
switch_php() {
  _PHP_CLI_UPDATE=NO
  _T_CLI_VRN=""
  if [ -e "${dscUsr}/static/control/fpm.info" ] \
    || [ -e "${dscUsr}/static/control/cli.info" ] \
    || [ -e "${dscUsr}/static/control/hhvm.info" ]; then
    echo "Custom FPM, HHVM or CLI settings for ${_USER} exist, \
      running switch_php checks"
    if [ -e "${dscUsr}/static/control/cli.info" ]; then
      _T_CLI_VRN=$(cat ${dscUsr}/static/control/cli.info 2>&1)
      _T_CLI_VRN=${_T_CLI_VRN//[^0-9.]/}
      _T_CLI_VRN=$(echo -n ${_T_CLI_VRN} | tr -d "\n" 2>&1)
      if [ "${_T_CLI_VRN}" = "5.6" ] \
        || [ "${_T_CLI_VRN}" = "5.5" ] \
        || [ "${_T_CLI_VRN}" = "5.4" ] \
        || [ "${_T_CLI_VRN}" = "5.3" ] \
        || [ "${_T_CLI_VRN}" = "5.2" ]; then
        if [ "${_T_CLI_VRN}" = "5.5" ] \
          && [ ! -x "/opt/php55/bin/php" ]; then
          if [ -x "/opt/php56/bin/php" ]; then
            _T_CLI_VRN=5.6
          elif [ -x "/opt/php54/bin/php" ]; then
            _T_CLI_VRN=5.4
          elif [ -x "/opt/php53/bin/php" ]; then
            _T_CLI_VRN=5.3
          fi
        elif [ "${_T_CLI_VRN}" = "5.6" ] \
          && [ ! -x "/opt/php56/bin/php" ]; then
          if [ -x "/opt/php55/bin/php" ]; then
            _T_CLI_VRN=5.5
          elif [ -x "/opt/php54/bin/php" ]; then
            _T_CLI_VRN=5.4
          elif [ -x "/opt/php53/bin/php" ]; then
            _T_CLI_VRN=5.3
          fi
        elif [ "${_T_CLI_VRN}" = "5.4" ] \
          && [ ! -x "/opt/php54/bin/php" ]; then
          if [ -x "/opt/php55/bin/php" ]; then
            _T_CLI_VRN=5.5
          elif [ -x "/opt/php56/bin/php" ]; then
            _T_CLI_VRN=5.6
          elif [ -x "/opt/php53/bin/php" ]; then
            _T_CLI_VRN=5.3
          fi
        elif [ "${_T_CLI_VRN}" = "5.3" ] \
          && [ ! -x "/opt/php53/bin/php" ]; then
          if [ -x "/opt/php55/bin/php" ]; then
            _T_CLI_VRN=5.5
          elif [ -x "/opt/php56/bin/php" ]; then
            _T_CLI_VRN=5.6
          elif [ -x "/opt/php54/bin/php" ]; then
            _T_CLI_VRN=5.4
          fi
        elif [ "${_T_CLI_VRN}" = "5.2" ]; then
          if [ -x "/opt/php55/bin/php" ]; then
            _T_CLI_VRN=5.5
          elif [ -x "/opt/php56/bin/php" ]; then
            _T_CLI_VRN=5.6
          elif [ -x "/opt/php54/bin/php" ]; then
            _T_CLI_VRN=5.4
          elif [ -x "/opt/php53/bin/php" ]; then
            _T_CLI_VRN=5.3
          fi
        fi
        if [ "${_T_CLI_VRN}" != "${_PHP_CLI_VERSION}" ]; then
          _PHP_CLI_UPDATE=YES
          update_php_cli_drush
          if [ -x "${_T_CLI}/php" ]; then
            update_php_cli_local_ini
            sed -i "s/^_PHP_CLI_VERSION=.*/_PHP_CLI_VERSION=${_T_CLI_VRN}/g" \
              /root/.${_USER}.octopus.cnf &> /dev/null
            echo ${_T_CLI_VRN} > ${dscUsr}/log/cli.txt
            echo ${_T_CLI_VRN} > ${dscUsr}/static/control/cli.info
            chown ${_USER}.ftp:${usrGroup} ${dscUsr}/static/control/cli.info
          fi
        fi
      fi
    fi
    if [ -e "${dscUsr}/static/control/hhvm.info" ]; then
      if [ -x "/usr/bin/hhvm" ] \
        && [ -e "/var/xdrago/conf/hhvm/init.d/hhvm.foo" ] \
        && [ -e "/var/xdrago/conf/hhvm/server.foo.ini" ]; then
        if [ ! -e "/opt/hhvm/server.${_USER}.ini" ] \
          || [ ! -e "/etc/init.d/hhvm.${_USER}" ] \
          || [ ! -e "/var/run/hhvm/${_USER}" ]  ; then
          ### create or update special system user if needed
          satellite_create_web_user "hhvm"
          ### configure custom hhvm server init.d script
          cp -af /var/xdrago/conf/hhvm/init.d/hhvm.foo /etc/init.d/hhvm.${_USER}
          sed -i "s/foo/${_USER}/g" /etc/init.d/hhvm.${_USER} &> /dev/null
          sed -i "s/.ftp/.web/g" /etc/init.d/hhvm.${_USER} &> /dev/null
          chmod 755 /etc/init.d/hhvm.${_USER}
          chown root:root /etc/init.d/hhvm.${_USER}
          update-rc.d hhvm.${_USER} defaults &> /dev/null
          ### configure custom hhvm server ini file
          mkdir -p /opt/hhvm
          cp -af /var/xdrago/conf/hhvm/server.foo.ini /opt/hhvm/server.${_USER}.ini
          sed -i "s/foo/${_USER}/g" /opt/hhvm/server.${_USER}.ini &> /dev/null
          sed -i "s/.ftp/.web/g" /opt/hhvm/server.${_USER}.ini &> /dev/null
          chmod 755 /opt/hhvm/server.${_USER}.ini
          chown root:root /opt/hhvm/server.${_USER}.ini
          mkdir -p /var/log/hhvm/${_USER}
          chown ${_WEB}:${_WEBG} /var/log/hhvm/${_USER}
          ### start custom hhvm server
          service hhvm.${_USER} start &> /dev/null
          ### remove fpm control file to avoid confusion
          rm -f ${dscUsr}/static/control/fpm.info
          ### update nginx configuration
          sed -i "s/\/var\/run\/${_USER}.fpm.socket/\/var\/run\/hhvm\/${_USER}\/hhvm.socket/g" \
            ${dscUsr}/config/includes/nginx_vhost_common.conf
          sed -i "s/\/var\/run\/${_USER}.fpm.socket/\/var\/run\/hhvm\/${_USER}\/hhvm.socket/g" \
            ${dscUsr}/.drush/sys/provision/http/Provision/Config/Nginx/Inc/vhost_include.tpl.php
          ### reload nginx
          service nginx reload &> /dev/null
        fi
      fi
    else
      if [ -e "/opt/hhvm/server.${_USER}.ini" ] \
        || [ -e "/etc/init.d/hhvm.${_USER}" ] \
        || [ -e "/var/run/hhvm/${_USER}" ]  ; then
        ### disable no longer used custom hhvm server instance
        if [ -e "/etc/init.d/hhvm.${_USER}" ]; then
          service hhvm.${_USER} stop &> /dev/null
          update-rc.d -f hhvm.${_USER} remove &> /dev/null
          rm -f /etc/init.d/hhvm.${_USER}
        fi
        ### delete special system user no longer needed
        satellite_remove_web_user "hhvm"
        ### delete leftovers
        rm -f /opt/hhvm/server.${_USER}.ini
        rm -f -r /var/run/hhvm/${_USER}
        rm -f -r /var/log/hhvm/${_USER}
        ### update nginx configuration
        sed -i "s/\/var\/run\/hhvm\/${_USER}\/hhvm.socket/\/var\/run\/${_USER}.fpm.socket/g" \
          ${dscUsr}/config/includes/nginx_vhost_common.conf
        sed -i "s/\/var\/run\/hhvm\/${_USER}\/hhvm.socket/\/var\/run\/${_USER}.fpm.socket/g" \
          ${dscUsr}/.drush/sys/provision/http/Provision/Config/Nginx/Inc/vhost_include.tpl.php
        ### reload nginx
        service nginx reload &> /dev/null
        ### create dummy control file to enable PHP-FPM again
        echo 5.2 > ${dscUsr}/static/control/fpm.info
        chown ${_USER}.ftp:${usrGroup} ${dscUsr}/static/control/fpm.info
        _FORCE_FPM_SETUP=YES
      fi
    fi
    sleep 5
    if [ ! -e "${dscUsr}/static/control/hhvm.info" ] \
      && [ -e "${dscUsr}/static/control/fpm.info" ] \
      && [ -e "/var/xdrago/conf/fpm-pool-foo.conf" ]; then
      _T_FPM_VRN=$(cat ${dscUsr}/static/control/fpm.info 2>&1)
      _T_FPM_VRN=${_T_FPM_VRN//[^0-9.]/}
      _T_FPM_VRN=$(echo -n $_T_FPM_VRN | tr -d "\n" 2>&1)
      if [ "$_T_FPM_VRN" = "5.6" ] \
        || [ "$_T_FPM_VRN" = "5.5" ] \
        || [ "$_T_FPM_VRN" = "5.4" ] \
        || [ "$_T_FPM_VRN" = "5.3" ] \
        || [ "$_T_FPM_VRN" = "5.2" ]; then
        if [ "$_T_FPM_VRN" = "5.5" ] \
          && [ ! -x "/opt/php55/bin/php" ]; then
          if [ -x "/opt/php56/bin/php" ]; then
            _T_FPM_VRN=5.6
          elif [ -x "/opt/php54/bin/php" ]; then
            _T_FPM_VRN=5.4
          elif [ -x "/opt/php53/bin/php" ]; then
            _T_FPM_VRN=5.3
          fi
        elif [ "$_T_FPM_VRN" = "5.6" ] \
          && [ ! -x "/opt/php56/bin/php" ]; then
          if [ -x "/opt/php55/bin/php" ]; then
            _T_FPM_VRN=5.5
          elif [ -x "/opt/php54/bin/php" ]; then
            _T_FPM_VRN=5.4
          elif [ -x "/opt/php53/bin/php" ]; then
            _T_FPM_VRN=5.3
          fi
        elif [ "$_T_FPM_VRN" = "5.4" ] \
          && [ ! -x "/opt/php54/bin/php" ]; then
          if [ -x "/opt/php55/bin/php" ]; then
            _T_FPM_VRN=5.5
          elif [ -x "/opt/php56/bin/php" ]; then
            _T_FPM_VRN=5.6
          elif [ -x "/opt/php53/bin/php" ]; then
            _T_FPM_VRN=5.3
          fi
        elif [ "$_T_FPM_VRN" = "5.3" ] \
          && [ ! -x "/opt/php53/bin/php" ]; then
          if [ -x "/opt/php55/bin/php" ]; then
            _T_FPM_VRN=5.5
          elif [ -x "/opt/php56/bin/php" ]; then
            _T_FPM_VRN=5.6
          elif [ -x "/opt/php54/bin/php" ]; then
            _T_FPM_VRN=5.4
          fi
        elif [ "$_T_FPM_VRN" = "5.2" ]; then
          if [ -x "/opt/php55/bin/php" ]; then
            _T_FPM_VRN=5.5
          elif [ -x "/opt/php56/bin/php" ]; then
            _T_FPM_VRN=5.6
          elif [ -x "/opt/php54/bin/php" ]; then
            _T_FPM_VRN=5.4
          elif [ -x "/opt/php53/bin/php" ]; then
            _T_FPM_VRN=5.3
          fi
        fi
        if [ "$_T_FPM_VRN" != "${_PHP_FPM_VERSION}" ] \
          || [ "$_FORCE_FPM_SETUP" = "YES" ]; then
          _NEW_FPM_SETUP=YES
          _FORCE_FPM_SETUP=NO
        fi
        if [ ! -z "$_T_FPM_VRN" ] \
          && [ "$_NEW_FPM_SETUP" = "YES" ]; then
          _NEW_FPM_SETUP=NO
          satellite_tune_fpm_workers
          _LIM_FPM="${_L_PHP_FPM_WORKERS}"
          if [ "$_LIM_FPM" -lt "24" ]; then
            if [[ "${_CHECK_HOST}" =~ ".host8." ]] \
              || [[ "${_CHECK_HOST}" =~ ".boa.io" ]] \
              || [ "${_VMFAMILY}" = "VS" ]; then
              _LIM_FPM=24
            fi
          fi
          if [ "${_CLIENT_OPTION}" = "MICRO" ]; then
            _LIM_FPM=2
            _PHP_FPM_WORKERS=4
          fi
          _CHILD_MAX_FPM=$(( _LIM_FPM * 2 ))
          if [ "${_PHP_FPM_WORKERS}" = "AUTO" ]; then
            _DO_NOTHING=YES
          else
            _PHP_FPM_WORKERS=${_PHP_FPM_WORKERS//[^0-9]/}
            if [ ! -z "${_PHP_FPM_WORKERS}" ] \
              && [ "${_PHP_FPM_WORKERS}" -gt "0" ]; then
              _CHILD_MAX_FPM="${_PHP_FPM_WORKERS}"
            fi
          fi
          sed -i "s/^_PHP_FPM_VERSION=.*/_PHP_FPM_VERSION=$_T_FPM_VRN/g" \
            /root/.${_USER}.octopus.cnf &> /dev/null
          echo $_T_FPM_VRN > ${dscUsr}/log/fpm.txt
          echo $_T_FPM_VRN > ${dscUsr}/static/control/fpm.info
          chown ${_USER}.ftp:${usrGroup} ${dscUsr}/static/control/fpm.info
          _PHP_OLD_SV=${_PHP_FPM_VERSION//[^0-9]/}
          _PHP_SV=${_T_FPM_VRN//[^0-9]/}
          if [ -z "${_PHP_SV}" ]; then
            _PHP_SV=55
          fi
          ### create or update special system user if needed
          if [ -e "/home/${_WEB}/.drush/php.ini" ]; then
            _OLD_PHP_IN_USE=$(grep "/lib/php" /home/${_WEB}/.drush/php.ini 2>&1)
            _PHP_V="56 55 54 53"
            for e in ${_PHP_V}; do
              if [[ "${_OLD_PHP_IN_USE}" =~ "php${e}" ]]; then
                if [ "${e}" != "${_PHP_SV}" ] \
                  || [ ! -e "/home/${_WEB}/.drush/.ctrl.php${_PHP_SV}.txt" ]; then
                  echo _OLD_PHP_IN_USE is ${_OLD_PHP_IN_USE} for ${_WEB} update
                  echo _NEW_PHP_TO_USE is ${_PHP_SV} for ${_WEB} update
                  satellite_update_web_user "${_PHP_SV}"
                fi
              fi
            done
          else
            echo _NEW_PHP_TO_USE is ${_PHP_SV} for ${_WEB} create
            satellite_create_web_user "${_PHP_SV}"
          fi
          ### create or update special system user if needed
          rm -f /opt/php*/etc/pool.d/${_USER}.conf
          cp -af /var/xdrago/conf/fpm-pool-foo.conf \
            /opt/php${_PHP_SV}/etc/pool.d/${_USER}.conf
          sed -i "s/.ftp/.web/g" \
            /opt/php${_PHP_SV}/etc/pool.d/${_USER}.conf &> /dev/null
          sed -i "s/\/data\/disk\/foo\/.tmp/\/home\/foo.web\/.tmp/g" \
            /opt/php${_PHP_SV}/etc/pool.d/${_USER}.conf &> /dev/null
          sed -i "s/foo/${_USER}/g" \
            /opt/php${_PHP_SV}/etc/pool.d/${_USER}.conf &> /dev/null
          if [ ! -z "${_PHP_FPM_DENY}" ]; then
            sed -i "s/passthru,/${_PHP_FPM_DENY},/g" \
              /opt/php${_PHP_SV}/etc/pool.d/${_USER}.conf &> /dev/null
          else
            if [[ "${_CHECK_HOST}" =~ ".host8." ]] \
              || [[ "${_CHECK_HOST}" =~ ".boa.io" ]] \
              || [ "${_VMFAMILY}" = "VS" ] \
              || [ -e "/root/.host8.cnf" ]; then
              _DO_NOTHING=YES
            else
              sed -i "s/passthru,//g" \
                /opt/php${_PHP_SV}/etc/pool.d/${_USER}.conf &> /dev/null
            fi
          fi
          if [ "${_PHP_FPM_TIMEOUT}" = "AUTO" ] \
            || [ -z "${_PHP_FPM_TIMEOUT}" ]; then
            _PHP_FPM_TIMEOUT=180
          fi
          _PHP_FPM_TIMEOUT=${_PHP_FPM_TIMEOUT//[^0-9]/}
          if [ "${_PHP_FPM_TIMEOUT}" -lt "60" ]; then
            _PHP_FPM_TIMEOUT=60
          fi
          if [ "${_PHP_FPM_TIMEOUT}" -gt "180" ]; then
            _PHP_FPM_TIMEOUT=180
          fi
          if [ ! -z "${_PHP_FPM_TIMEOUT}" ]; then
            _PHP_TO="${_PHP_FPM_TIMEOUT}s"
            sed -i "s/180s/${_PHP_TO}/g" \
              /opt/php${_PHP_SV}/etc/pool.d/${_USER}.conf &> /dev/null
          fi
          if [ ! -z "${_CHILD_MAX_FPM}" ]; then
            sed -i "s/pm.max_children =.*/pm.max_children = ${_CHILD_MAX_FPM}/g" \
              /opt/php${_PHP_SV}/etc/pool.d/${_USER}.conf &> /dev/null
          fi
          if [ -e "/etc/init.d/php${_PHP_OLD_SV}-fpm" ]; then
            service php${_PHP_OLD_SV}-fpm reload &> /dev/null
          fi
          if [ -e "/etc/init.d/php${_PHP_SV}-fpm" ]; then
            service php${_PHP_SV}-fpm reload &> /dev/null
          fi
        fi
      fi
    fi
  fi
}
#
# Manage mirroring of drush aliases.
manage_site_drush_alias_mirror() {

  for Alias in `find /home/${_USER}.ftp/.drush/*.alias.drushrc.php \
    -maxdepth 1 -type f | sort`; do
    AliasFile=$(echo "$Alias" | cut -d'/' -f5 | awk '{ print $1}' 2>&1)
    if [ ! -e "${pthParentUsr}/.drush/${AliasFile}" ]; then
      rm -f /home/${_USER}.ftp/.drush/${AliasFile}
    fi
  done

  if [ -e "/home/${_USER}.ftp/.drush/hm.alias.drushrc.php" ]; then
    rm -f /home/${_USER}.ftp/.drush/hm.alias.drushrc.php
  fi
  if [ -e "/home/${_USER}.ftp/.drush/self.alias.drushrc.php" ]; then
    rm -f /home/${_USER}.ftp/.drush/self.alias.drushrc.php
  fi
  if [ -e "/data/disk/${_USER}/.drush/.alias.drushrc.php" ]; then
    rm -f /data/disk/${_USER}/.drush/.alias.drushrc.php
  fi
  if [ -e "/data/disk/${_USER}/.drush/self.alias.drushrc.php" ]; then
    rm -f /data/disk/${_USER}/.drush/self.alias.drushrc.php
  fi
  if [ -e "/data/disk/${_USER}/config/self" ]; then
    rm -f -r /data/disk/${_USER}/config/self
  fi

  for Alias in `find ${pthParentUsr}/.drush/*.alias.drushrc.php \
    -maxdepth 1 -type f | sort`; do
    AliasName=$(echo "$Alias" | cut -d'/' -f6 | awk '{ print $1}' 2>&1)
    AliasName=$(echo "${AliasName}" \
      | sed "s/.alias.drushrc.php//g" \
      | awk '{ print $1}' 2>&1)
    if [ "${AliasName}" = "hm" ] \
      || [[ "${AliasName}" =~ (^)"platform_" ]] \
      || [[ "${AliasName}" =~ (^)"server_" ]] \
      || [[ "${AliasName}" =~ (^)"self" ]] \
      || [[ "${AliasName}" =~ (^)"hostmaster" ]] \
      || [ -z "${AliasName}" ]; then
      _IS_SITE=NO
    else
      SiteName="${AliasName}"
      echo SiteName is $SiteName
      if [[ "$SiteName" =~ ".restore"($) ]]; then
        _IS_SITE=NO
        rm -f ${pthParentUsr}/.drush/${SiteName}.alias.drushrc.php
      else
        SiteDir=$(cat $Alias \
          | grep "site_path'" \
          | cut -d: -f2 \
          | awk '{ print $3}' \
          | sed "s/[\,']//g" 2>&1)
        if [ -d "$SiteDir" ]; then
          echo SiteDir is $SiteDir
          pthAliasMain="${pthParentUsr}/.drush/${SiteName}.alias.drushrc.php"
          pthAliasCopy="/home/${_USER}.ftp/.drush/${SiteName}.alias.drushrc.php"
          if [ ! -e "${pthAliasCopy}" ]; then
            cp -af ${pthAliasMain} ${pthAliasCopy}
            chmod 440 ${pthAliasCopy}
          else
            _DIFF_T=$(diff ${pthAliasCopy} ${pthAliasMain} 2>&1)
            if [ ! -z "${_DIFF_T}" ]; then
              cp -af ${pthAliasMain} ${pthAliasCopy}
              chmod 440 ${pthAliasCopy}
            fi
          fi
        else
          rm -f ${pthAliasCopy}
          echo "ZOMBIE $SiteDir IN ${pthAliasMain}"
        fi
      fi
    fi
  done
}
#
# Manage Primary Users.
manage_user() {
for pthParentUsr in `find /data/disk/ -maxdepth 1 -mindepth 1 | sort`; do
  if [ -e "${pthParentUsr}/config/server_master/nginx/vhost.d" ] \
    && [ -e "${pthParentUsr}/log/fpm.txt" ] \
    && [ ! -e "${pthParentUsr}/log/CANCELLED" ]; then
    _USER=""
    _USER=$(echo ${pthParentUsr} | cut -d'/' -f4 | awk '{ print $1}' 2>&1)
    echo "_USER is == ${_USER} == at manage_user"
    _WEB="${_USER}.web"
    dscUsr="/data/disk/${_USER}"
    octInc="${dscUsr}/config/includes"
    octTpl="${dscUsr}/.drush/sys/provision/http/Provision/Config/Nginx"
    usrDgn="${dscUsr}/.drush/usr/drupalgeddon"
    rm -f ${dscUsr}/*.php* &> /dev/null
    chmod 0440 ${dscUsr}/.drush/*.php &> /dev/null
    chmod 0400 ${dscUsr}/.drush/drushrc.php &> /dev/null
    chmod 0400 ${dscUsr}/.drush/hm.alias.drushrc.php &> /dev/null
    chmod 0400 ${dscUsr}/.drush/hostmaster*.php &> /dev/null
    chmod 0400 ${dscUsr}/.drush/platform_*.php &> /dev/null
    chmod 0400 ${dscUsr}/.drush/server_*.php &> /dev/null
    chmod 0710 ${dscUsr}/.drush &> /dev/null
    find ${dscUsr}/config/server_master \
      -type d -exec chmod 0700 {} \; &> /dev/null
    find ${dscUsr}/config/server_master \
      -type f -exec chmod 0600 {} \; &> /dev/null
    if [ ! -e "${dscUsr}/.tmp/.ctrl.246stableU.txt" ]; then
      rm -f -r ${dscUsr}/.drush/cache
      mkdir -p ${dscUsr}/.tmp
      touch ${dscUsr}/.tmp
      find ${dscUsr}/.tmp/ -mtime +0 -exec rm -rf {} \; &> /dev/null
      chown ${_USER}:${usrGroup} ${dscUsr}/.tmp &> /dev/null
      chmod 02755 ${dscUsr}/.tmp &> /dev/null
      echo OK > ${dscUsr}/.tmp/.ctrl.246stableU.txt
    fi
    if [ ! -e "${dscUsr}/static/control/.ctrl.246stableU.txt" ]; then
      mkdir -p ${dscUsr}/static/control
      chmod 755 ${dscUsr}/static/control
      if [ -e "/var/xdrago/conf/control-readme.txt" ]; then
        cp -af /var/xdrago/conf/control-readme.txt \
          ${dscUsr}/static/control/README.txt &> /dev/null
        chmod 0644 ${dscUsr}/static/control/README.txt
      fi
      chown -R ${_USER}.ftp:${usrGroup} \
        ${dscUsr}/static/control &> /dev/null
      rm -f ${dscUsr}/static/control/.ctrl.*
      echo OK > ${dscUsr}/static/control/.ctrl.246stableU.txt
    fi
    if [ -e "/root/.${_USER}.octopus.cnf" ]; then
      source /root/.${_USER}.octopus.cnf
    fi
    switch_php
    switch_newrelic
    if [ -e "${pthParentUsr}/clients" ] && [ ! -z ${_USER} ]; then
      echo Managing Users for ${pthParentUsr} Instance
      rm -f -r ${pthParentUsr}/clients/admin &> /dev/null
      rm -f -r ${pthParentUsr}/clients/omega8ccgmailcom &> /dev/null
      rm -f -r ${pthParentUsr}/clients/nocomega8cc &> /dev/null
      rm -f -r ${pthParentUsr}/clients/*/backups &> /dev/null
      symlinks -dr ${pthParentUsr}/clients &> /dev/null
      if [ -e "/home/${_USER}.ftp" ]; then
        disable_chattr ${_USER}.ftp
        symlinks -dr /home/${_USER}.ftp &> /dev/null
        echo >> ${_THIS_LTD_CONF}
        echo "[${_USER}.ftp]" >> ${_THIS_LTD_CONF}
        echo "path : ['${dscUsr}/distro', \
                      '${dscUsr}/static', \
                      '${dscUsr}/backups', \
                      '${dscUsr}/clients']" \
                      | fmt -su -w 2500 >> ${_THIS_LTD_CONF}
        manage_site_drush_alias_mirror
        manage_sec
        if [ -e "/home/${_USER}.ftp/users" ]; then
          chown -R ${_USER}.ftp:${usrGroup} /home/${_USER}.ftp/users
          chmod 700 /home/${_USER}.ftp/users
          chmod 600 /home/${_USER}.ftp/users/*
        fi
        if [ ! -L "/home/${_USER}.ftp/static" ]; then
          rm -f /home/${_USER}.ftp/{backups,clients,static}
          ln -sf ${dscUsr}/backups /home/${_USER}.ftp/backups
          ln -sf ${dscUsr}/clients /home/${_USER}.ftp/clients
          ln -sf ${dscUsr}/static  /home/${_USER}.ftp/static
        fi
        if [ ! -e "/home/${_USER}.ftp/.tmp/.ctrl.246stableU.txt" ]; then
          rm -f -r /home/${_USER}.ftp/.drush/cache
          rm -f -r /home/${_USER}.ftp/.tmp
          mkdir -p /home/${_USER}.ftp/.tmp
          chown ${_USER}.ftp:${usrGroup} /home/${_USER}.ftp/.tmp &> /dev/null
          chmod 700 /home/${_USER}.ftp/.tmp &> /dev/null
          echo OK > /home/${_USER}.ftp/.tmp/.ctrl.246stableU.txt
        fi
        enable_chattr ${_USER}.ftp
        echo Done for ${pthParentUsr}
      else
        echo Directory /home/${_USER}.ftp not available
      fi
      echo
    else
      echo Directory ${pthParentUsr}/clients not available
    fi
    echo
  fi
done
}

###-------------SYSTEM-----------------###

if [ ! -L "/usr/bin/MySecureShell" ] && [ -x "/usr/bin/mysecureshell" ] ; then
  mv -f /usr/bin/MySecureShell /var/backups/legacy-MySecureShell-bin
  ln -sf /usr/bin/mysecureshell /usr/bin/MySecureShell
fi

_NOW=$(date +%y%m%d-%H%M 2>&1)
mkdir -p /var/backups/ltd/{conf,log,old}
mkdir -p /var/backups/zombie/deleted
_THIS_LTD_CONF="/var/backups/ltd/conf/lshell.conf.${_NOW}"
if [ -e "/var/run/manage_rvm_users.pid" ] \
  || [ -e "/var/run/manage_ltd_users.pid" ] \
  || [ -e "/var/run/boa_run.pid" ] \
  || [ -e "/var/run/boa_wait.pid" ]; then
  touch /var/xdrago/log/wait-manage-ltd-users
  echo Another BOA task is running, we have to wait
  sleep 10
  exit 0
elif [ ! -e "/var/xdrago/conf/lshell.conf" ]; then
  echo Missing /var/xdrago/conf/lshell.conf template
  exit 0
else
  touch /var/run/manage_ltd_users.pid
  find_fast_mirror
  find /etc/[a-z]*\.lock -maxdepth 1 -type f -exec rm -rf {} \; &> /dev/null
  cat /var/xdrago/conf/lshell.conf > ${_THIS_LTD_CONF}
  _THISHTNM=$(hostname --fqdn 2>&1)
  _THISHTIP=$(echo $(getent ahostsv4 $_THISHTNM) \
    | cut -d: -f2 \
    | awk '{ print $1}' 2>&1)
  sed -i "s/8.8.8.8/${_THISHTIP}/g" ${_THIS_LTD_CONF}
  if [ ! -e "/root/.allow.mc.cnf" ]; then
    sed -i "s/'mc', //g" ${_THIS_LTD_CONF}
    sed -i "s/, 'mc':'mc -u'//g" ${_THIS_LTD_CONF}
  fi
  add_ltd_group_if_not_exists
  kill_zombies >/var/backups/ltd/log/zombies-${_NOW}.log 2>&1
  manage_user >/var/backups/ltd/log/users-${_NOW}.log 2>&1
  if [ -e "${_THIS_LTD_CONF}" ]; then
    _DIFF_T=$(diff ${_THIS_LTD_CONF} /etc/lshell.conf 2>&1)
    if [ ! -z "${_DIFF_T}" ]; then
      cp -af /etc/lshell.conf /var/backups/ltd/old/lshell.conf-before-${_NOW}
      cp -af ${_THIS_LTD_CONF} /etc/lshell.conf
    else
      rm -f ${_THIS_LTD_CONF}
    fi
  fi
  if [ -L "/bin/sh" ]; then
    _WEB_SH=$(readlink -n /bin/sh 2>&1)
    _WEB_SH=$(echo -n ${_WEB_SH} | tr -d "\n" 2>&1)
    if [ -x "/bin/websh" ]; then
      if [ "${_WEB_SH}" != "/bin/websh" ] \
        && [ ! -e "/root/.dbhd.clstr.cnf" ]; then
        rm -f /bin/sh
        ln -s /bin/websh /bin/sh
      fi
    else
      if [ -x "/bin/dash" ]; then
        if [ "${_WEB_SH}" != "/bin/dash" ]; then
          rm -f /bin/sh
          ln -s /bin/dash /bin/sh
        fi
      else
        if [ "${_WEB_SH}" != "/bin/bash" ]; then
          rm -f /bin/sh
          ln -s /bin/bash /bin/sh
        fi
      fi
      curl -s -A iCab "${urlHmr}/helpers/websh.sh.txt" -o /bin/websh
      chmod 755 /bin/websh
    fi
  fi
  rm -f $_TMP/*.txt
  if [ ! -e "/root/.home.no.wildcard.chmod.cnf" ]; then
    chmod 700 /home/* &> /dev/null
  fi
  chmod 0600 /var/log/lsh/*
  chmod 0440 /var/aegir/.drush/*.php &> /dev/null
  chmod 0400 /var/aegir/.drush/drushrc.php &> /dev/null
  chmod 0400 /var/aegir/.drush/hm.alias.drushrc.php &> /dev/null
  chmod 0400 /var/aegir/.drush/hostmaster*.php &> /dev/null
  chmod 0400 /var/aegir/.drush/platform_*.php &> /dev/null
  chmod 0400 /var/aegir/.drush/server_*.php &> /dev/null
  chmod 0710 /var/aegir/.drush &> /dev/null
  find /var/aegir/config/server_master \
    -type d -exec chmod 0700 {} \; &> /dev/null
  find /var/aegir/config/server_master \
    -type f -exec chmod 0600 {} \; &> /dev/null
  if [ -e "/var/scout" ]; then
    _SCOUT_CRON_OFF=$(grep "OFFscoutOFF" /etc/crontab 2>&1)
    if [[ "$_SCOUT_CRON_OFF" =~ "OFFscoutOFF" ]]; then
      sleep 5
      sed -i "s/OFFscoutOFF/scout/g" /etc/crontab &> /dev/null
    fi
  fi
  if [ -e "/var/backups/reports/up/barracuda" ]; then
    if [ -e "/root/.mstr.clstr.cnf" ] \
      || [ -e "/root/.wbhd.clstr.cnf" ] \
      || [ -e "/root/.dbhd.clstr.cnf" ]; then
      if [ -e "/var/spool/cron/crontabs/aegir" ]; then
        sleep 180
        rm -f /var/spool/cron/crontabs/aegir
        service cron reload &> /dev/null
      fi
    fi
    if [ -e "/root/.mstr.clstr.cnf" ] \
      || [ -e "/root/.wbhd.clstr.cnf" ]; then
      if [ -e "/var/run/mysqld/mysqld.pid" ] \
        && [ ! -e "/root/.dbhd.clstr.cnf" ]; then
        service cron stop &> /dev/null
        sleep 180
        touch /root/.remote.db.cnf
        service mysql stop &> /dev/null
        sleep 5
        service cron start &> /dev/null
      fi
    fi
  fi
  sleep 5
  rm -f /var/run/manage_ltd_users.pid
  exit 0
fi
###EOF2015###
