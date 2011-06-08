require 'rufus/tokyo'
require 'syslog2logan/backend/base'

class Backend::TCH < Backend::Base
	attr_reader :dir
	def initialize opts = {}, &e
		@dir = opts[:dir]
		Dir.mkdir @dir  rescue Errno::EEXIST
		@dbs = []
		if block_given?
			begin
				super opts, &e
			ensure
				close
			end
		else
			super opts
		end
	end

	def close
		@dbs.each &:close
	end

	def open name
		logger.info :open => name, :backend => self.class
		db = Rufus::Tokyo::Cabinet.new File.join( @dir, name)+".tch"
		@dbs.push db
		db
	end
end
