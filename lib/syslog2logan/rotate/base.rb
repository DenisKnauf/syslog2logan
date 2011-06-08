#!/usr/bin/ruby

require 'logger'
require 'uuidtools'
require 'active_support/core_ext'

class Rotate
	# open_db_func: must returns a db-object with #[] and #[]=.
	# #sync and #close are optional, for Rotate#sync, Rotate#close.
	def initialize hash_func = nil, &open_db_func
		@dbs = Hash.new {|h,k| h[k] = open_db_func.call(k) }
		hash_func ||= lambda {|k| [k.timestamp.to_i/1.day].pack 'N' }
		define_singleton_method :hashing, &hash_func
		@rotate = @dbs['rotate']
		@queue = @dbs['queue']
	end

	def db_name id
		h = hashing id
		n = @rotate[ h]
		if n
			n = UUIDTools::UUID.parse_raw n
		else
			n = UUIDTools::UUID.timestamp_create
			@rotate[ h] = n.raw
			logger.info :create => n.to_s
		end
		n
	end

	# Synchronize data to disc.
	# Only avaible if db-backend provides #sync.
	def sync
		@dbs.each {|n, db| db.sync }
		@rotate.sync
		@queue.sync
	end

	# Close databases.
	# Only avaible if db-backend provides #close.
	def close
		@dbs.each {|n, db| db.close }
		@rotate.close
		@queue.close
	end

	# Put new logline to databases.
	# This will be written in a database with an UUID as name.
	# If this db don't exist, it will be created via open_db_func (#initialize).
	def put v
		id = UUIDTools::UUID.timestamp_create
		s = [0x10, v].pack 'Na*'
		n = db_name id
		@dbs[n][ id.raw] = s
		@queue.push id.raw
	end
	alias emit put
end
