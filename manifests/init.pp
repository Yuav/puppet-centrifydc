#
# Puppet manifest for Centrify Express
#

class centrifydc($domain = "vagrantup.com") {

	$centrifydc_package_name = $operatingsystem ? {
        redhat  => "CentrifyDC",
        default => "centrifydc"
    }


	# Install the latest Centrify Express client and join domain
	case $operatingsystem {
		centos, redhat: {
		    include site-packages
			package { $centrifydc_package_name:
				ensure => installed,
				provider => rpm, 
				source => "/var/cache/site-packages/centrifydc/centrifydc-5.0.2-rhel3-x86_64.rpm",
				notify => Exec["adjoin"],
				require => File['/var/cache/site-packages/centrifydc/centrifydc-5.0.2-rhel3-x86_64.rpm']
			}  
                        package { "CentrifyDC-openssh":
				ensure => absent,
                        }
                        package { "CentrifyDA":
				ensure => absent,
                        }
		}
		default: {
			package { $centrifydc_package_name:
				ensure => latest ,
				notify => Exec["adjoin"]
			}
		}
	}
	# This is only executed once when the package is installed.
	# It requires "adjoin -w -P -n [new machine name] -u [administrator account] domain" from the
	# puppetmaster to pre-create the machine's account. Do this at the same time you sign
	# the puppet certificate.
	#
    exec { "adjoin" :
        path => "/usr/bin:/usr/sbin:/bin",
        command => "adjoin -w -S ${domain}",
        onlyif => 'adinfo | grep "Not joined to any domain"',
        logoutput => true,
        notify => Exec["addns"]
    }
    
    # Update Active Directory DNS servers with host name
    exec { "addns" :
        path => "/usr/bin:/usr/sbin:/bin",
        command => "addns -U -m",
        onlyif => 'adinfo | grep "Not joined to any domain"',
        logoutput => true,
        require => Exec['adjoin'],
    }
    
    # Identify Ubuntu server and workstation machines by their kernel type
    case $kernelrelease {
	    /(server)$/: 
	    { 
	    	# Give the servers configuration that restricts logins to specific users and groups
	    	file { "/etc/centrifydc/centrifydc.conf":
				owner  => root,
				group  => root,
				mode   => 644,
				source => "puppet:///modules/centrifydc/server_centrifydc.conf",
                                replace => false,
				require => Package["centrifydc"]
			}
		
			# Additional users read from $users_allow array variable
			file { "/etc/centrifydc/users.allow":
				owner  => root,
				group  => root,
				mode   => 644,
				content => template("centrifydc/server_users.allow.erb"),
				require => Package["centrifydc"]
			} 
			
			# Additional groups read from $groups_allow array variable
			file { "/etc/centrifydc/groups.allow":
				owner  => root,
				group  => root,
				mode   => 644,
				content => template("centrifydc/server_groups.allow.erb"),
				require => Package["centrifydc"]
			} 
   		} 
	    default: 
	    {	
	    	# Use the default Centrify config
	    	file { "/etc/centrifydc/centrifydc.conf":
				owner  => root,
				group  => root,
				mode   => 644,
				source => "puppet:///modules/centrifydc/workstation_centrifydc.conf",
				require => Package[$centrifydc_package_name]
			}  
		} 
	}
        
        
	# Make sure service is running and is restarted if configuration files are updated
    case $kernelrelease {
	    /(server)$/: 
	    {
			service { centrifydc:
			        ensure  => running,
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
	   default:
	   {
		   	service { centrifydc:
			        ensure  => running,
			        hasstatus => false,
			        pattern => 'adclient',
			        require => [Package[$centrifydc_package_name],
			        			File["/etc/centrifydc/centrifydc.conf"]],
			        subscribe => [ 
			        	File["/etc/centrifydc/centrifydc.conf"], 
			        	Package[$centrifydc_package_name] 
			        ]
			}
	    }
	}

}
