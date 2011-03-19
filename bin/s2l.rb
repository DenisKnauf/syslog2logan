#!/usr/bin/ruby

require 'logger'
require 'rubygems'
require 'sbdb'
require 'uuidtools'
require 'socket'
require 'select'
require 'robustserver'

$logger = Logger.new $stderr

class S2L < Select::Server
	attr_accessor :dbs

	def init p
		super p
		@dbs = p[:dbs]
	end

	def event_new_client a
		debug :connection => {:new => a}
		{ :clientclass => S2L::Socket, :dbs => @dbs }
	end
end

module Kernel
	def debug( *p)  $logger.debug *p  end
	def info( *p)  $logger.info *p  end
	def warn( *p)  $logger.warn *p  end
	def error( *p)  $logger.error *p  end
	def fatal( *p)  $logger.fatal *p  end
end

class S2L::Socket < Select::Socket
	def init opts
		@dbs = opts[ :dbs]
		super opts
	end

	def event_line v
		debug :line => v
		@dbs.emit v
	end
	alias emit event_line
end

class Rotate
	def initialize db, &e
		@rdb, @env, @dbs = db, db.home, {}
		self.hash = e || lambda {|k|
			[k.timestamp.to_i/60/60/24].pack 'N'
		}
	end

	def hash= e
		self.hash &e
	end

	def hash &e
		@hash_func = e  if e
		@hash_func
	end

	def hashing k
		@hash_func.call k
	end

	def db_name id
		h = hashing id
		n = @rdb[ h]
		if n
			n = UUIDTools::UUID.parse_raw n
		else
			n = UUIDTools::UUID.timestamp_create
			@rdb[ h] = n.raw
			info :create => n.to_s
		end
		n
	end

	def db n
		@env[ n.to_s, :type => SBDB::Btree, :flags => SBDB::CREATE | SBDB::AUTO_COMMIT]
	end

	def queue n
		@env[ "newids.queue", :type => SBDB::Queue, :flags => SBDB::CREATE | SBDB::AUTO_COMMIT, :re_len => 16]
	end

	def sync
		@dbs.each{|n,db|db.sync}
		@rdb.sync
	end

	def close
		@dbs.each{|n,db|db.close 0}
		@rdb.close 0
	end

	def put v
		id = UUIDTools::UUID.timestamp_create
		s = [0x10, v].pack 'Na*'
		n = db_name id
		db( n)[ id.raw] = s
		queue( n).push id.raw
	end
	alias emit put
end

class Main < RobustServer
	def initialize conf
		super
		@logger = $logger
		@conf = conf
		info :open => S2L
		@serv = S2L.new :sock => TCPServer.new( *@conf[:server])
		info :create => {:home => @conf[:home]}
		Dir.mkdir @conf[:home]  rescue Errno::EEXIST
		@sigs[:INT] = @sigs[:TERM] = method(:shutdown)
		@sigs[:USR1] = method(:state)
	end

	def state s = nil
		debug :server => @serv
	end

	def shutdown s = nil
		info :shutdown => [s, Signal[s]]
		@serv.close
		exit 0
	end

	def run
		info :open => SBDB::Env
		SBDB::Env.new( @conf[:home],
				log_config: SBDB::Env::LOG_IN_MEMORY | SBDB::Env::LOG_AUTO_REMOVE,
				flags: SBDB::CREATE | SBDB::Env::INIT_TXN | Bdb::DB_INIT_MPOOL) do |dbenv|
			info :open => Rotate
			@serv.dbs = Rotate.new dbenv[ 'rotates.db', :type => SBDB::Btree, :flags => SBDB::CREATE | Bdb::DB_AUTO_COMMIT]
			info :run => @serv
			@serv.run
		end
	end
end

Main.main :home => 'logs', :server => [ '', 1514], :retries => [1,1] # [10, 10]

info :halted
