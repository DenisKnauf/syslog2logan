#!/usr/bin/ruby

require 'rubygems'
require 'sbdb'
require 'uuidtools'
require 'socket'
require 'select'

class S2L < Select::Server
	def init p
		super p
		@dbs = p[:dbs]
	end

	def event_new_client a
		{ :clientclass => S2L::Socket, :dbs => @dbs }
	end
end

module Kernel
	def debug( *p)  logger :debug, *p  end
	def info( *p)  logger :info, *p  end
	def warn( *p)  logger :warn, *p  end
	def error( *p)  logger :error, *p  end
	def fatal( *p)  logger :fatal, *p  end

	def logger l, *p
		p = p.first  if p.length == 1
		$stderr.puts [Time.now, l, p].inspect
	end
	private :logger
end

class S2L::Socket < Select::Socket
	def init opts
		@dbs = opts[ :dbs]
		super opts
	end

	def event_line v
		@dbs.emit v
	end
	alias emit event_line
end

class Rotate
	def initialize db, &e
		@rdb, @env, @dbs = db, db.home, {}
		self.hash = e || lambda {|k|
			[UUIDTools::UUID.parse_raw( k).timestamp.to_i/60/60/24].pack 'N'
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

	def db k
		h = hashing k
		db = @dbs[h]
		unless db
			n = @rdb[ h]
			if n
				n = UUIDTools::UUID.parse_raw n
			else
				n = UUIDTools::UUID.timestamp_create
				@rdb[ h] = n.raw
			end
			info :open => n.to_s
			db = @env.open SBDB::Btree, n.to_s, 'logs', Bdb::DB_CREATE | Bdb::DB_AUTO_COMMIT, nil
			@dbs[h] = db
		end
		db
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
		db(id.raw)[ id.raw] = s
	end
	alias emit put
end

class Retries
	attr_accessor :max, :range
	attr_reader :count, :last

	def initialize max = 10, range = 10
		@max, @range, @count, @last = max, range, 0, Time.now
	end

	def retry?
		@count = @last + @range > Time.now ? @count + 1 : 1
		@last = Time.now
		@count < @max
	end

	def run ex, &e
		begin e.call *args
		rescue ex
			retries.retry? and retry
		end
	end
end

$conf = {
	:home => 'logs',
	:server => [ '', 1514],
	:retries => [10, 10]
}

info :create => {:home => $conf[:home]}
Dir.mkdir $conf[:home]  rescue Errno::EEXIST

info :open => SBDB::Env
SBDB::Env.new( $conf[:home], SBDB::CREATE | SBDB::INIT_TXN | SBDB::INIT_LOCK | SBDB::INIT_LOG | SBDB::INIT_MPOOL | Bdb::DB_AUTO_COMMIT) do |dbenv|
	info :open => SBDB::Btree
	dbenv.open( SBDB::Btree, 'rotates.db', 'rotates', SBDB::CREATE | Bdb::DB_AUTO_COMMIT, nil) do |rdb|
		info :open => Rotate
		dbs = Rotate.new rdb
		info :open => S2L
		serv = S2L.new :sock => TCPServer.new( *$conf[:server]), :dbs => dbs
		retries = Retries.new *$conf[:retries]
		begin
			info :run => serv
			serv.run
			info :shutdown => :stoped
		rescue Interrupt
			info :shutdown => :interrupted
		rescue SignalException
			info :shutdown => :signal
		rescue Object
			error :exception=>$!, :backtrace=>$!.backtrace
			retries.retry? and retry
			fatal "Too many retries (#{retries.count})"
			info :shutdown => :fatal
		end
		info :close => rdb
	end
	info :close => dbenv
end
info :halted
