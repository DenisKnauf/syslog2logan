class File
	def exclusive_lock
		flock File::LOCK_EX
	end

	def shared_lock
		flock File::LOCK_SH
	end

	def unblock
		flock File::LOCK_UN
	end
end

class FileQueue
	attr_reader :file, :size
	alias to_io file

	def initialize file, size = 16
		@file = case file
						when File then file
						else File.open file, 'a+'
						end
		@size, @pack = size, "A#{size}"
	end

	def push *a
		f = @file
		f.seek 0, IO::SEEK_END
		f.exclusive_lock
		f.write a.pack( @pack*a.length)
		f.unblock
	end

	def pop
		f = @file
		f.rewind
		f.exclusive_lock
		s = f.read( @size).unpack( 'L')[0]
		f.rewind
		f.write [s.succ].pack( 'L')
		f.sync
		f.shared_lock
		f.pos = s
		f.read( @size).unpack( 'L')[0]
		f.unblock
	end
end
