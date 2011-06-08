require 'socket'
require 'select'

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
