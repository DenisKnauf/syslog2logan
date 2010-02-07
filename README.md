Dependencies
============

incomplete yet.

System
------

* ruby >= 1.9 (tested: 1.9.1,  untested: 1.8 (maybe compatible))
* libdb >= 4 (tested: 4.7)
* C-Compiler

### Debian/Ubuntu:

	# aptitude ruby1.9.1 ruby1.9.1-dev libdb4.7-dev rubygems1.9.1

If you've installed ruby1.8 (yet), you should run ruby1.9.1 instead ruby and
gem1.9.1 instead gem.
Change shebash in s2l.rb to

	#!/usr/bin/ruby1.9.1


Ruby Gems
---------

* BDB >= 0.2.2 (patch needed - gem included)
* UUIDTools

Install: (in syslog2logan-dir)

	# gem install bdb-0.2.2.gem uuidtools


Install
=======

	# gem build syslog2logan.gemspec
	# gem install syslog2logan-*.gem


Usage
=====

Start
-----

Simple:

	# ./s2l.rb

Or deamonized:

	# sh -c 'nohup ./s2l.rb </dev/null >/dev/null 2>&1 &' &


Use it
------

Your Syslog-server should send everythin via tcp to port 1514.
UDP and TLS aren't possible yet.
If you want to use any of these,  you can proxy it via a local syslog-ng.

### syslog-ng

You need these lines:

	source s_server {
		unix-stream( "/dev/log" max-connections(100));
		# internal(); # Statistics about dests. You've any other dest than the server?
		file( "/proc/kmsg");
	};
	
	destination d_server {
		tcp( "SyslogServer.example.org" port (1514));
	};
	
	log {
		source( s_server);
		destination( d_server);
	};

You should use your default source.


### rsyslog

I don't know.  Please tell me,  if you can.