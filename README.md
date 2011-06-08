Dependencies
============

System
------

* ruby >= 1.9 (tested: 1.9.1,  untested: 1.8 (maybe compatible))
* tokyocabinet

### Debian/Ubuntu:

	# aptitude ruby1.9.1 ruby1.9.1-dev rubygems1.9.1 libtokyocabinet-dev libtokyotyrant-dev

If you've installed ruby1.8 (yet),  you should run ruby1.9.1 instead ruby and
gem1.9.1 instead gem.
Change shebash in s2l.rb to

	#!/usr/bin/ruby1.9.1

or

	#!/usr/bin/env ruby1.9.1

Install
=======

	# gem install syslog2logan

Usage
=====

First you should know,  the database environments are in *this* directory,
where you call *s2l.rb*.  You must use this directory for logan itself too!
Don't use this directory for anything else.

Start
-----

Simple on Ubuntu:

	# /var/lib/gems/1.9*/gems/syslog2logan-*/bin/s2l.rb

Deamonized:

	# sh -c 'nohup PATHTO/s2l.rb </dev/null >/dev/null 2>&1 &' &

Use it
------

Your Syslog-server should send everythin via tcp to port 1514.
UDP and TLS aren't possible yet.
If you want to use any of these,  you can proxy it via a local syslog-ng.

### syslog-ng

You need these lines:

	source s_server {
		unix-stream( "/dev/log" max-connections(100));
		# internal(); # Statistics about dests.  It's unimportant for LogAn.
		file( "/proc/kmsg");
	};
	
	destination d_server {
		tcp( "SyslogServer.example.org" port (1514));
	};
	
	log {
		source( s_server);
		destination( d_server);
	};

### rsyslog

I don't know.  Please tell me,  how to use.
