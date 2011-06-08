module Backend
end

class Backend::Base
	def initialize opts = {}
		if block_given?
			yield self
		else
			self
		end
	end

	def to_proc
		method :open
	end
end
