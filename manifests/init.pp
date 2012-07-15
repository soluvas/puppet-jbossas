# Class: jbossas
#
# This module manages JBoss Application Server 7.x
#
# Parameters:
# * @version@ = '7.1.1.Final'
# * @mirror_url@ = 'http://download.jboss.org/jbossas/7.1/jboss-as-7.1.1.Final/'
# * @bind_address@ = '127.0.0.1'
# * @http_port@ = 8080
# * @https_port@ = 8443
#
# Actions:
#
# Requires:
# * package curl
#
# Sample Usage:
#
# [Remember: No empty lines between comments and class definition]
class jbossas (
  $version = '7.1.1.Final',
  # Mirror URL with trailing slash
  # Will use curl to download, so 'file:///' is also possible not just 'http://'
  $mirror_url = 'http://download.jboss.org/jbossas/7.1/jboss-as-7.1.1.Final/',
  $bind_address = '127.0.0.1',
  $http_port = 8080,
  $https_port = 8443,
  $enable_service = true)
{
  $dir = "/usr/share/jboss-as"

  package {
    libtcnative-1: ensure => present;
    libapr1:       ensure => present;
  }

  class install {
    $mirror_url_version = "${jbossas::mirror_url}jboss-as-${jbossas::version}.tar.gz"
    $dist_dir = '/home/jbossas/tmp'
    $dist_file = "${dist_dir}/jboss-as-${jbossas::version}.tar.gz"

    notice "Download URL: $mirror_url_version"
    notice "JBoss AS directory: $jbossas::dir"

    # Create group, user, and home folder
    group { jbossas:
      ensure => present
    }
    user { jbossas:
      ensure => present,
      managehome => true,
      gid => 'jbossas',
      require => Group['jbossas'],
      comment => 'JBoss Application Server'
    }
    file { '/home/jbossas':
      ensure => present,
      owner => 'jbossas',
      group => 'jbossas',
      mode => 0775,
      require => [ Group['jbossas'], User['jbossas'] ]
    }

    # Download the JBoss AS distribution ~100MB file
    exec { download_jboss_as:
      command => "/usr/bin/curl -v --progress-bar -o '$dist_file' '$mirror_url_version'",
      creates => $dist_file,
      user => 'jbossas',
      logoutput => true,
      require => [ Package['curl'], File[$dist_dir] ]
    }

    # Extract the JBoss AS distribution
    file { $dist_dir:
      ensure => directory,
      owner => 'jbossas', group => 'jbossas',
      mode => 0775,
      require => [ Group['jbossas'], User['jbossas'] ]
    }
    exec { extract_jboss_as:
      command => "/bin/tar -xz -f '$dist_file'",
      creates => "/home/jbossas/jboss-as-${jbossas::version}",
      cwd => '/home/jbossas',
      user => 'jbossas', group => 'jbossas',
      logoutput => true,
      unless => "/usr/bin/test -d '$jbossas::dir'",
      require => [ Group['jbossas'], User['jbossas'], Exec['download_jboss_as'] ]
    }
    exec { move_jboss_home:
      command => "/bin/mv -v '/home/jbossas/jboss-as-${jbossas::version}' '${jbossas::dir}'",
      creates => $jbossas::dir,
      logoutput => true,
      require => Exec['extract_jboss_as']
    }
    file { "$jbossas::dir":
      ensure => directory,
      owner => 'jbossas', group => 'jbossas',
      require => [ Group['jbossas'], User['jbossas'], Exec['move_jboss_home'] ]
    }

  }

  # init.d configuration for Ubuntu
  class initd {
    $jbossas_bind_address = $jbossas::bind_address

    file { '/etc/jboss-as':
      ensure => directory,
      owner => 'root', group => 'root'
    }
    file { '/etc/jboss-as/jboss-as.conf':
      content => template('jbossas/jboss-as.conf.erb'),
      owner => 'root', group => 'root',
      mode => 0644,
      require => File['/etc/jboss-as']
    }
    file { '/var/run/jboss-as':
      ensure => directory,
      owner => 'jbossas', group => 'jbossas',
      mode => 0775
    }
    file { '/etc/init.d/jboss-as':
      source => 'puppet:///modules/jbossas/init.d/jboss-as-standalone.sh',
      owner => 'root', group => 'root',
      mode => 0755
    }
  }
  Class['install'] -> Class['initd']

  include install
  include initd

  # Configure
  notice "Bind address: $bind_address - HTTP Port: $http_port - HTTPS Port: $https_port"
  exec { jbossas_http_port:
  	command   => "/bin/sed -i -e 's/socket-binding name=\"http\" port=\"[0-9]\\+\"/socket-binding name=\"http\" port=\"${http_port}\"/' standalone/configuration/standalone.xml",
    user      => 'jbossas',
    cwd       => $dir,
    logoutput => true,
    require   => Class['jbossas::install'],
    unless    => "/bin/grep 'socket-binding name=\"http\" port=\"${http_port}\"/' standalone/configuration/standalone.xml",
    notify    => Service['jboss-as'],
  }
  exec { jbossas_https_port:
    command   => "/bin/sed -i -e 's/socket-binding name=\"https\" port=\"[0-9]\\+\"/socket-binding name=\"https\" port=\"${https_port}\"/' standalone/configuration/standalone.xml",
    user      => 'jbossas',
    cwd       => $dir,
    logoutput => true,
    require   => Class['jbossas::install'],
    unless    => "/bin/grep 'socket-binding name=\"https\" port=\"${https_port}\"/' standalone/configuration/standalone.xml",
    notify    => Service['jboss-as']
  }

  service { jboss-as:
    enable => $enable_service,
    ensure => $enable_service ? { true => running, default => undef },
    require => [ Class['jbossas::initd'], Exec['jbossas_http_port', 'jbossas_https_port'],
                 Package['libtcnative-1', 'libapr1'] ]
  }

  define virtual_server($default_web_module = '',
    $aliases = [],
    $ensure = 'present')
  {
    case $ensure {
      'present': {
#        notice "JBoss Virtual Server $name: default_web_module=$default_web_module"
        if $default_web_module {
          $cli_args = inline_template('<% require "json" %>default-web-module=<%= default_web_module %>,alias=<%= aliases.to_json.gsub("\"", "\\\"") %>')
        } else {
          $cli_args = inline_template("<% require 'json' %>alias=<%= aliases.to_json %>")
        }
        notice "$jbossas::dir/bin/jboss-cli.sh -c --command='/subsystem=web/virtual-server=$name:add\\($cli_args\\)'"
        exec { "add jboss virtual-server $name":
          command => "${jbossas::dir}/bin/jboss-cli.sh -c --command=/subsystem=web/virtual-server=$name:add\\($cli_args\\)",
          user => 'jbossas', group => 'jbossas',
          logoutput => true,
          unless => "/bin/sh ${jbossas::dir}/bin/jboss-cli.sh -c /subsystem=web/virtual-server=$name:read-resource | grep success",
          notify => Service['jboss-as'],
          provider => 'posix'
        }
      }
      'absent': {
        exec { "remove jboss virtual-server $name":
          command => "${jbossas::dir}/bin/jboss-cli.sh -c '/subsystem=web/virtual-server=$name:remove()'",
          user => 'jbossas', group => 'jbossas',
          logoutput => true,
          onlyif => "/bin/sh ${jbossas::dir}/bin/jboss-cli.sh -c /subsystem=web/virtual-server=$name:read-resource | grep success",
          notify => Service['jboss-as'],
          provider => 'posix'
        }
      }
    }
  }

}
