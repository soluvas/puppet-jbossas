# Class: jbossas
#
# This module manages JBoss Application Server 7.x
#
# Parameters:
#
# Actions:
#
# Requires:
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
	class install {
		$mirror_url_version = "${jbossas::mirror_url}jboss-as-${jbossas::version}.tar.gz"
		$dist_dir = '/home/jbossas/tmp'
		$dist_file = "${dist_dir}/jboss-as-${jbossas::version}.tar.gz"
		$jboss_home = "/home/jbossas/jboss-as"

		notice "Download URL: $mirror_url_version"
		notice "JBoss AS directory: $jboss_home"
	
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
		exec { "/bin/tar -xz -f '$dist_file'":
			creates => "/home/jbossas/jboss-as-${jbossas::version}",
			cwd => '/home/jbossas',
			user => 'jbossas', group => 'jbossas',
			logoutput => true,
			unless => "/usr/bin/test -d '$jboss_home'"
		}
		exec { "/bin/mv -v 'jboss-as-${jbossas::version}' jboss-as":
			creates => $jboss_home,
			cwd => '/home/jbossas',
			user => 'jbossas', group => 'jbossas',
			logoutput => true,
		}
	}
	
	include install
	
	# Set ports
	notice "HTTP Port: $http_port - HTTPS Port: $https_port"
	exec { "/bin/sed -i -e 's/socket-binding name=\"http\" port=\"[0-9]\\+\"/socket-binding name=\"http\" port=\"${http_port}\"/' jboss-as/standalone/configuration/standalone.xml":
		user => 'jbossas',
		cwd => '/home/jbossas',
		logoutput => true,
		require => Class['jbossas::install']
	}
	exec { "/bin/sed -i -e 's/socket-binding name=\"https\" port=\"[0-9]\\+\"/socket-binding name=\"https\" port=\"${https_port}\"/' jboss-as/standalone/configuration/standalone.xml":
		user => 'jbossas',
		cwd => '/home/jbossas',
		logoutput => true,
		require => Class['jbossas::install']
	}
}
