require 'ffi'

module AODBM
	class DB
		attr_reader :c

		def initialize name, flags = nil
			flags ||= 0
			@c = Lib::open name, flags
		end

		def open name, flags = nil
			db = new name, flags
			block_given? ? yield( db) : db
		end

		def close
			Lib::close @c
		end

		def current
			Version.new @c, Lib::current( @c)
		end

		def commit version
			Lib::commit @c, version
		end
	end

	class Version
		attr_reader :db, :c

		def initialize db, c
			@db, @c = db, c
		end

		def previous
			Version.new @db, Lib::previous( @db.c, @c)
		end

		def has? data
			Lib::has @db.c, @c, Lib::Data.new( data)
		end

		def set key, val
			Lib::set @db.c, @c, Lib::Data.new( key), Lib::Data.new( val)
		end
	end

	module Lib
		extend FFI::Library
		ffi_lib "libaodbm.so"

		typedef :pointer, :aodbm
		typedef :uint64, :version

		class Data < FFI::Struct
			def initialilze data

			end

			layout :dat, :buffer,  :sz, :size_t
		end
		typedef :pointer, :data

		attach_function :open, :aodbm_open, [:string, :int], :aodbm
		attach_function :close, :aodbm_close, [:aodbm], :void

		attach_function :current, :aodbm_current, [:aodbm], :version
		attach_function :commit, :aodbm_commit, [:aodbm, :version], :bool

		attach_function :has, :aodbm_has, [:aodbm, :version, :data], :bool
		attach_function :set, :aodbm_set, [:aodbm, :version, :data, :data], :version
		attach_function :get, :aodbm_get, [:aodbm, :version, :data], :data
		attach_function :del, :aodbm_del, [:aodbm, :version, :data], :version

		attach_function :is_based_on, :aodbm_is_based_on, [:aodbm, :version, :data], :bool
		attach_function :previous, :aodbm_previous_version, [:aodbm, :version], :version
		attach_function :common_ancestor, :aodbm_common_ancestor, [:aodbm, :version, :version], :version

		#typedef :changeset, :pointer
		#attach_function :aodbm_diff_prev, [:aodbm, :version], :changeset
		#attach_function :aodbm_diff_prev_rev, [:aodbm, :version], :changeset
		#attach_function :aodbm_diff, [:aodbm, :version, :version], :changeset
		#attach_function :aodbm_apply, [:aodbm, :version, :changeset], :version
		#attach_function :aodbm_apply_di, [:aodbm, :version, :changeset], :version
		#attach_function :aodbm_merge, [:aodbm, :version, :version], :version

		typedef :pointer, :iterator
		class Record < FFI::Struct
			layout :key, :data,  :val, :data
		end
		typedef :pointer, :record

		attach_function :new_iterator, :aodbm_new_iterator, [:aodbm, :version], :iterator
		attach_function :iterator_from, :aodbm_iterate_from, [:aodbm, :version, :data], :iterator
		attach_function :iterate_next, :aodbm_iterator_next, [:aodbm, :iterator], :record
		attach_function :iterate_goto, :aodbm_iterator_goto, [:aodbm, :iterator, :data], :void
		attach_function :free_iterator, :aodbm_free_iterator, [:iterator], :void

		attach_function :free_data, :aodbm_free_data, [:data], :void
	end
end
