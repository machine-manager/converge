alias Converge.Unit
alias Gears.{FileUtil, IOUtil}

use Bitwise

import Record, only: [defrecordp: 2, extract: 2]

defmodule Converge.DirectoryPresent do
	@enforce_keys [:path, :mode]
	defstruct path: nil, mode: nil
end

defimpl Unit, for: Converge.DirectoryPresent do
	defrecordp :file_info, extract(:file_info, from_lib: "kernel/include/file.hrl")

	defp mode_without_type(mode) do
		mode &&& 0o7777
	end

	defp met_mode?(p) do
		case :file.read_file_info(p.path) do
			{:ok, file_info(mode: mode)} ->
				mode_without_type(mode) == p.mode
			_ -> false
		end
	end

	def met?(p) do
		File.dir?(p.path) and met_mode?(p)
	end

	def meet(p) do
		File.mkdir_p!(p.path)
		File.chmod!(p.path, p.mode)
	end
end


defmodule Converge.FilePresent do
	@enforce_keys [:path, :content, :mode]
	defstruct path: nil, content: nil, mode: nil
end

defimpl Unit, for: Converge.FilePresent do
	defrecordp :file_info, extract(:file_info, from_lib: "kernel/include/file.hrl")

	defp met_contents?(p) do
		case File.open(p.path, [:read]) do
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
		case :file.read_file_info(p.path) do
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
		FileUtil.rm_f!(p.path)

		# After opening, must chmod before writing possibly-secret content
		f = File.open!(p.path, [:write])
		File.chmod!(p.path, p.mode)

		try do
			IOUtil.binwrite!(f, p.content)
		after
			File.close(f)
		end
	end
end


defmodule Converge.FileMissing do
	@enforce_keys [:path]
	defstruct path: nil
end

defimpl Unit, for: Converge.FileMissing do
	def met?(p) do
		not File.exists?(p.path)
	end

	def meet(p) do
		FileUtil.rm_f!(p.path)
	end
end
