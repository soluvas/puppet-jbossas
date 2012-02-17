# Class: jboss-as
#
# This module manages jboss-as
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
class jboss-as {

	$version = '7.1.0.Final'
	# Mirror URL with trailing slash
	# Will use curl to download, so 'file:///' is also possible not just 'http://'
	# file:///together/Technology/Servers/JBoss/jboss-as-7.1.0.Final.tar.gz
	#$mirror_url = 'file:///together/Technology/Servers/JBoss/'
	$mirror_url = 'file:///home/ceefour/Public/'
	$mirror_url_version = "${mirror_url}jboss-as-${version}.tar.gz"
	$dist_dir = '/tmp'
	$dist_file = "${dist_dir}/jboss-as-${version}.tar.gz"
	$http_port = 9080
	$https_port = 9443
	
	notice "Mirror URL: $mirror_url_version"
	
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
	
	# Download the JBoss AS distribution
	exec { "/usr/bin/curl -v --progress-bar -o '$dist_file' '$mirror_url_version'":
		creates => $dist_file,
		user => 'jbossas',
		logoutput => true,
	}

	# Extract the JBoss AS distribution
	$jboss_home = "/home/jbossas/jboss-as"
	exec { "/bin/tar -xzv -f '$dist_file'":
		creates => "/home/jbossas/jboss-as-${version}",
		user => 'jbossas',
		cwd => '/home/jbossas',
		logoutput => true,
		unless => "/usr/bin/test -d '$jboss_home'"
	}
	exec { "/bin/mv -v 'jboss-as-${version}' jboss-as":
		creates => $jboss_home,
		user => 'jbossas',
		cwd => '/home/jbossas',
		logoutput => true,
	}
	
	# Set ports
	exec { "/bin/sed -i -e 's/socket-binding name=\"http\" port=\"8080\"/socket-binding name=\"http\" port=\"${http_port}\"/' jboss-as/standalone/configuration/standalone.xml":
		user => 'jbossas',
		cwd => '/home/jbossas',
		logoutput => true,
	}
	exec { "/bin/sed -i -e 's/socket-binding name=\"https\" port=\"8443\"/socket-binding name=\"https\" port=\"${https_port}\"/' jboss-as/standalone/configuration/standalone.xml":
		user => 'jbossas',
		cwd => '/home/jbossas',
		logoutput => true,
	}
}
