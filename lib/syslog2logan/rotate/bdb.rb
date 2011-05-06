#!/usr/bin/ruby

require 'logger'
require 'rubygems'
require 'sbdb'
require 'uuidtools'
require 'socket'
require 'select'
require 'robustserver'
require 'active_support'

class Rotate::BDB
	def initialize db, &e
		@rdb, @env, @dbs = db, db.home, {}
		self.hash = e || lambda {|k|
			[k.timestamp.to_i/1.hour].pack 'N'
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
			logger.info :create => n.to_s
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
		@dbs.each {|n, db| db.sync }
		@rdb.sync
	end

	def close
		@dbs.each {|n, db| db.close 0 }
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
		logger.info :open => S2L
		@serv = S2L.new :sock => TCPServer.new( *@conf[:server])
		logger.info :create => {:home => @conf[:home]}
		Dir.mkdir @conf[:home]  rescue Errno::EEXIST
		@sigs[:INT] = @sigs[:TERM] = method(:shutdown)
		@sigs[:USR1] = method(:state)
	end

	def state s = nil
		logger.debug :server => @serv
	end

	def shutdown s = nil
		logger.info :shutdown => [s, Signal[s]]
		@serv.close
		exit 0
	end

	def run
		logger.info :open => SBDB::Env
		SBDB::Env.new( @conf[:home],
				log_config: SBDB::Env::LOG_IN_MEMORY | SBDB::Env::LOG_AUTO_REMOVE,
				flags: SBDB::CREATE | SBDB::Env::INIT_TXN | Bdb::DB_INIT_MPOOL) do |dbenv|
			logger.info :open => Rotate
			@serv.dbs = Rotate.new dbenv[ 'rotates.db', :type => SBDB::Btree, :flags => SBDB::CREATE | Bdb::DB_AUTO_COMMIT]
			logger.info :run => @serv
			@serv.run
		end
	end
end
