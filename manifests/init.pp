#
# Puppet manifest for Centrify Express
#
class centrifydc ($domain = "cisco.com",
	$username = undef,
	$password = undef) {
	$centrifydc_package_name = $::operatingsystem ? {
		redhat => "CentrifyDC",
		centos => "CentrifyDC",
		ubuntu => "centrifydc",
		default => "centrifydc"
	}

	# Install the latest Centrify Express client and join domain
	case $::operatingsystem {
		centos, redhat : {
			include centrifypackages package {
				$centrifydc_package_name :
					ensure => installed,
					provider => rpm,
					source => "/tmp/centrifydc-5.0.2-rhel3-${::architecture}.rpm",
					notify => Exec["adjoin"],
					require => File["/tmp/centrifydc-5.0.2-rhel3-${::architecture}.rpm"]
			}
			package {
				"CentrifyDC-openssh" :
					ensure => absent,
			}
			package {
				"CentrifyDA" :
					ensure => absent,
			}
		}
		debian, ubuntu : {
			package {
				'python-software-properties' :
					ensure => latest,
					notify => Exec['partnerrepo'],
					
			}
			exec {
				'partnerrepo' :
					command =>
					"add-apt-repository 'deb http://archive.canonical.com/ $::lsbdistcodename partner'",
					require => Package['python-software-properties'],
					notify => [Package[$centrifydc_package_name], Exec['apt-update']]
			}
			exec {
				"apt-update" :
					command => "/usr/bin/apt-get update",
					refreshonly => true ;
			}
			package {
				$centrifydc_package_name :
					ensure => latest,
					require => Exec['partnerrepo'],
					notify => Exec["adjoin"]
			}
		}
		default : {
			package {
				$centrifydc_package_name :
					ensure => latest,
					notify => Exec["adjoin"]
			}
		}
	}
	# This is only executed once when the package is installed.
	# It requires "adjoin -w -P -n [new machine name] -u [administrator account] domain" from the
	# puppetmaster to pre-create the machine's account. Do this at the same time you sign
	# the puppet certificate. --force allows us to overwrite existing entries in AD
	#
	exec {
		"adjoin" :
			path => "/usr/bin:/usr/sbin:/bin",
			command => "adjoin -u ${username} -p ${password} -w ${domain} -n ${::hostname} --force",
			onlyif => 'adinfo | grep "Not joined to any domain"',
			logoutput => true,
			require => Package[$centrifydc_package_name]
	}

	# Identify Ubuntu server and workstation machines by their kernel type
	#case $::kernelrelease {
	#/(server)$/ : {
	#default : {
	# Use the default Centrify config
	#	file {
	#		"/etc/centrifydc/centrifydc.conf" :
	#			owner => root,
	#			group => root,
	#			mode => 644,
	#			source => "puppet:///modules/centrifydc/workstation_centrifydc.conf",
	#			require => Package[$centrifydc_package_name]
	#	}
	#}

	# Give the servers configuration that restricts logins to specific users and groups
	file {
		"/etc/centrifydc/centrifydc.conf" :
			owner => root,
			group => root,
			mode => 644,
			source => "puppet:///modules/centrifydc/server_centrifydc.conf",
			replace => false,
			require => Package[$centrifydc_package_name]
	}

	# Additional users read from $users_allow array variable
	file {
		"/etc/centrifydc/users.allow" :
			owner => root,
			group => root,
			mode => 644,
			content => template("centrifydc/server_users.allow.erb"),
			require => Package[$centrifydc_package_name]
	}

	# Additional groups read from $groups_allow array variable
	file {
		"/etc/centrifydc/groups.allow" :
			owner => root,
			group => root,
			mode => 644,
			content => template("centrifydc/server_groups.allow.erb"),
			require => Package[$centrifydc_package_name]
	}

	# Make sure service is running and is restarted if configuration files are updated
	#/(server)$/ :
	#case $::kernelrelease {
	#default : {
	#	service {
	#		centrifydc :
	#			ensure => running,
	#			hasstatus => false,
	#			pattern => 'adclient',
	#			require => [
	#				Package[$centrifydc_package_name],
	#				File["/etc/centrifydc/centrifydc.conf"]
	#			],
	#			subscribe => [File["/etc/centrifydc/centrifydc.conf"],
	#			Package[$centrifydc_package_name]]
	#	}
	#}
	service {
		centrifydc :
			ensure => running,
			require => [
				Package[$centrifydc_package_name],
				File["/etc/centrifydc/centrifydc.conf"],
				File["/etc/centrifydc/users.allow"], 
				File["/etc/centrifydc/groups.allow"],
			],
			subscribe => [
				File["/etc/centrifydc/centrifydc.conf"],
				File["/etc/centrifydc/users.allow"], 
				File["/etc/centrifydc/groups.allow"],
				Package[$centrifydc_package_name]
			]
	}
}
