# Class: jbossas
#
# This module manages JBoss Application Server 7.x
#
# Parameters:
# * @version@ = '7.1.0.Final'
# * @mirror_url@ = 'http://download.jboss.org/jbossas/7.1/jboss-as-7.1.0.Final/'
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
class jbossas ($version = '7.1.0.Final',
	# Mirror URL with trailing slash
	# Will use curl to download, so 'file:///' is also possible not just 'http://'
	$mirror_url = 'http://download.jboss.org/jbossas/7.1/jboss-as-7.1.0.Final/',
	$http_port = 8080,
	$https_port = 8443)
{
	$dir = "/usr/share/jboss-as"
	
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
			comment => 'JBoss Application Server'
		}
		file { '/home/jbossas':
			ensure => present,
			owner => 'jbossas',
			group => 'jbossas',
			mode => 0775
		}
		
		# Download the JBoss AS distribution ~100MB file
		exec { "/usr/bin/curl -v --progress-bar -o '$dist_file' '$mirror_url_version'":
			creates => $dist_file,
			user => 'jbossas',
			logoutput => true,
			require => Package['curl']
		}
	
		# Extract the JBoss AS distribution
		file { $dist_dir:
			ensure => directory,
			owner => 'jbossas', group => 'jbossas',
			mode => 0775,
		}
		exec { 'extract jboss':
			command => "/bin/tar -xz -f '$dist_file'",
			creates => "/home/jbossas/jboss-as-${jbossas::version}",
			cwd => '/home/jbossas',
			user => 'jbossas', group => 'jbossas',
			logoutput => true,
			unless => "/usr/bin/test -d '$jbossas::dir'"
		}
		exec { 'rename jboss_home':
			command => "/bin/mv -v '/home/jbossas/jboss-as-${jbossas::version}' '${jbossas::dir}'",
			creates => $jbossas::dir,
			logoutput => true,
			require => Exec['extract jboss']
		}
		file { "$jbossas::dir":
			ensure => directory,
			owner => 'jbossas', group => 'jbossas',
			require => Exec['rename jboss_home']
		}
		
	}

	# init.d configuration for Ubuntu
	class initd {
		file { '/etc/jboss-as':
			ensure => directory,
			owner => 'root', group => 'root'
		}
		file { '/etc/jboss-as/jboss-as.conf':
			source => 'puppet:///modules/jbossas/init.d/jboss-as.conf',
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
		service { 'jboss-as':
			enable => true,
			require => File['/etc/init.d/jboss-as']
		}
	}
	Class['install'] -> Class['initd']		
	
	include install
	include initd
	
	# Set ports
	notice "HTTP Port: $http_port - HTTPS Port: $https_port"
	exec { "/bin/sed -i -e 's/socket-binding name=\"http\" port=\"[0-9]\\+\"/socket-binding name=\"http\" port=\"${http_port}\"/' standalone/configuration/standalone.xml":
		user => 'jbossas',
		cwd => $dir,
		logoutput => true,
		require => Class['jbossas::install'],
		notify => Service['jboss-as']
	}
	exec { "/bin/sed -i -e 's/socket-binding name=\"https\" port=\"[0-9]\\+\"/socket-binding name=\"https\" port=\"${https_port}\"/' standalone/configuration/standalone.xml":
		user => 'jbossas',
		cwd => $dir,
		logoutput => true,
		require => Class['jbossas::install'],
		notify => Service['jboss-as']
	}
}
