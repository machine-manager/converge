# Things to implement:
# File with content + user owner + group owner + permissions
# Package installed
# Package uninstalled
# User exists
# File-matches-regexp + edit operation to fix it
# File/directory exists, else run command to fix it
# Git URL cloned and checked out to a specific revision

defmodule PackagesInstalled do
	defstruct names: nil
end

defmodule PackagesMissing do
	defstruct names: nil
end

defmodule UserExists do
	defstruct name: nil
end

defmodule FilePresent do
	defstruct filename: nil, content: nil
end

defmodule FileMissing do
	defstruct filename: nil
end
