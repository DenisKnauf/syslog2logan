#!/usr/bin/ruby

$:.push File.join( File.dirname( $0), '..', 'lib')
require 'logger'
require 'json'
require 'rubygems'
require 'uuidtools'
require 'socket'
require 'select'
require 'robustserver'
require 'active_support'
require 'syslog2logan/rotate'
require 'syslog2logan/server'

$logger = Logger.new $stderr
$logger.formatter = proc { |severity, datetime, progname, msg| [severity, datetime, progname, msg.inspect].to_json+"\n" }

module Kernel
	def logger() $logger end
end

class Main < RobustServer
	def initialize conf
		super
		@logger = $logger
		@conf = conf
		logger.info :open => S2L
		@serv = S2L.new :sock => TCPServer.new( *@conf[:server])
		@sigs[:INT] = @sigs[:TERM] = method(:shutdown)
		@sigs[:USR1] = method(:state)
	end

	def state s = nil
		logger.debug :server => @serv.class
	end

	def shutdown s = nil
		logger.info :shutdown => [s, Signal[s]]
		@serv.close
		exit 0
	end

	def run
		logger.info :open => @conf[:backend]
		@conf[:backend][0].new( @conf[:backend][1]) do |backend|
			logger.info :open => Rotate
			@serv.dbs = Rotate.new &backend.to_proc
			logger.info :run => @serv.class
			@serv.run
			logger.info :close => @conf[:backend]
		end
	end
end

require 'syslog2logan/backend/tch'
Main.main :backend => [ Backend::TCH, {:dir => 'logs'}], :server => [ '', 1514], :retries => [1,1] # [10, 10]

logger.info :halted
