alias Converge.Unit
alias Gears.{FileUtil, IOUtil}

defmodule Converge.FilePresent do
	@enforce_keys [:filename, :content, :mode]
	defstruct filename: nil, content: nil, mode: nil
end

defimpl Unit, for: Converge.FilePresent do
	use Bitwise

	import Record, only: [defrecordp: 2, extract: 2]
	defrecordp :file_info, extract(:file_info, from_lib: "kernel/include/file.hrl")

	defp met_contents?(p) do
		case File.open(p.filename, [:read]) do
			# TODO: guard against giant files
			{:ok, file} -> case IO.binread(file, :all) do
				{:error, _} -> false
				existing -> p.content == existing
			end
			{:error, _} -> false
		end
	end

	defp mode_without_type(mode) do
		mode &&& 0o7777
	end

	defp met_mode?(p) do
		case :file.read_file_info(p.filename) do
			{:ok, file_info(mode: mode)} ->
				mode_without_type(mode) == p.mode
			_ -> false
		end
	end

	def met?(p) do
		met_mode?(p) and met_contents?(p)
	end

	def meet(p) do
		# It's safer to unlink the file first, because it may be a shell script, and
		# shells handle modified scripts very poorly.  If unlinked first, the shell
		# will continue running the old (unlinked) script instead of crashing.
		FileUtil.rm_f!(p.filename)

		# After opening, must chmod before writing possibly-secret content
		f = File.open!(p.filename, [:write])
		File.chmod!(p.filename, p.mode)

		try do
			IOUtil.binwrite!(f, p.content)
		after
			File.close(f)
		end
	end
end


defmodule Converge.FileMissing do
	@enforce_keys [:filename]
	defstruct filename: nil
end

defimpl Unit, for: Converge.FileMissing do
	def met?(p) do
		not File.exists?(p.filename)
	end

	def meet(p) do
		FileUtil.rm_f!(p.filename)
	end
end
