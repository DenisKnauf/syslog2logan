require 'zlib'  # Zlib::crc32
require 'uuidtools'

# Maximum Filesize: 4GB because #pack("N")

class Plain < File
	UUID_SIZE   = 16        # Size of an key (UUID as raw 16byte string)
	INT_SIZE    = 4
	CRCR32_SIZE = INT_SIZE  # Size of CRC32 (32Bit)

	KEY_SIZE    = UUID_SIZE
	IDX_SIZE    = INT_SIZE  # Size of an index (big-endian 32bit integer)
	SIZE_SIZE   = INT_SIZE  # Size of size_t
	CHK_SIZE    = CRCR32_SIZE
	IDXE_SIZE   = KEY_SIZE + IDX_SIZE # Size of an entry in index-file
	DBP_SIZE    = KEY_SIZE + SIZE_SIZE + CHK_SIZE

	UUID_PACK   = "a16"
	INT_PACK    = "N"
	STR_PACK    = "a*"
	CRC32_PACK  = INT_PACK

	KEY_PACK    = UUID_PACK
	IDX_PACK    = INT_PACK
	SIZE_PACK   = INT_PACK
	CHK_PACK    = CRC32_PACK
	IDXE_PACK   = KEY_PACK + IDX_PACK
	DBP_PACK    = KEY_PACK + SIZE_PACK + CHK_PACK
	VAL_PACK    = STR_PACK
	ENTRY_PACK  = DBP_PACK + VAL_PACK

	class Corrupt < Exception
	end

	module UUIDConv
		class <<self
			# Converts a UUIDTools::UUID to raw-String: UUIDTools::UUID#raw
			def cto_s x
				x.raw
			end

			# Converts a String to UUIDTools::UUID: UUIDTools::UUID.parse_raw
			def cto_key x
				UUIDTools::UUID.parse_raw x
			end
		end
	end

	# Converting-helper.
	# To methods are required:
	# #cto_str # obj => 16-byte-String
	# #cto_key # 16-byte-String => obj
	attr_accessor :conv
	attr_reader :idx

	def initialize *a
		super *a
		@conv = @@conv
		@idx = File.open "#{path}.idx", a[1]
	end

	class <<self
		# Default we use UUIDTool for keys.
		@@conv = UUIDConv

		def new *a
			a[1] ||= 'a'
			r = super *a
			block_given? ? yield(r) : r
		end

		def open *a, &e
			a[1] ||= 'r'
			new *a, &e
		end
	end

	def sync
		super
		@idx.sync
	end

	def close
		super
		@idx.close
	end

	def gen_entry key, val
		[key, val.length, Zlib::crc32( val), val].pack( ENTRY_PACK)
	end

	def gen_idx key, pos = self.pos
		[key, pos].pack IDXE_PACK
	end

	# Store an entry in DB
	def push key, val
		key = @conv.cto_s key
		idx = gen_idx key
		print gen_entry( key, val)
		@idx.print idx
		sync
		@idx.sync
		true
	end

	def put val
		push UUIDTools::UUID.timestamp_create, val
	end

	# Read the entry.
	# First you should seek, if you won't read sequential
	def get
		if m = read( DBP_SIZE)
			key, length, chk = m.unpack DBP_PACK
			val = read length
			valchk = Zlib::crc32 val
			raise Corrupt, "#{path} is corrupt: #{pos-length-CHK_SIZE-DBP_SIZE} #{chk} -- #{valchk}"  unless chk == valchk
			[@conv.cto_key( key), length, val, chk]
		end
	end
	alias next get

	# yield(idx): must return:
	#    -1:   to small
	#    0:    found!  return true
	#    1:    to big
	# else:    like you use break nil
	# yield is allowed to use break
	def self.binary_search size
		idx = 1
		begin
			i = size
			while 0 < i
				idx <<= 1
				i >>= 1
			end
		end
		idx >>= 1
		t = idx
		p idx

		while t > 0
			t >>= 1
			i = yield idx
			case i
			when -1 then idx -= t
			when 1  then idx += t
			when 0  then return true
			else return nil
			end
		end
	end

	# Get the value.
	# key must provide: #<=> uuid
	def search_ key
		idx = self.length
		position = nil
		self.class.binary_search( idx) do |idx|
			p idx
			idx *= IDXE_SIZE
			if idx > size
				size = @idx.size
				break  if idx > size
			end
			# Read entry i. p is position and k is key
			@idx.seek idx
			k, position = @idx.read( IDXE_SIZE).unpack IDXE_PACK
			p pos: position, key: k
			key <=> @conv.cto_key( k)
		end ? position : nil
	end

	def [] key
		if position = search_( key)
			self.pos = position+KEY_SIZE
			length,_ = read( SIZE_SIZE).unpack( SIZE_PACK)
			read( length)[2]
		end
	end

	def each
		return Enumerator.new( self)  unless block_given?
		yield *get  while !eof?
	end

	# counts entries (size of the idx): O(1)
	def length
		@idx.size/IDXE_SIZE
	end
end
