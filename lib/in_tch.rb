#!/usr/bin/ruby

require 'logger'
require 'rubygems'
require 'uuidtools'
require 'socket'
require 'select'
require 'robustserver'
require 'active_support'
require 'syslog2logan/rotate'

$logger = Logger.new $stderr

class S2L < Select::Server
	attr_accessor :dbs

	def init p
		super p
		@dbs = p[:dbs]
	end

	def event_new_client a
		logger.debug :connection => {:new => a}
		{ :clientclass => S2L::Socket, :dbs => @dbs }
	end
end

module Kernel
	def logger() $logger end
end

class S2L::Socket < Select::Socket
	def init opts
		@dbs = opts[ :dbs]
		super opts
	end

	def event_line v
		logger.debug :line => v
		@dbs.emit v
	end
	alias emit event_line
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

Main.main :home => 'logs', :server => [ '', 1514], :retries => [1,1] # [10, 10]

logger.info :halted
