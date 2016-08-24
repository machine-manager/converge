defmodule Converge.PackagesInstalled do
	@enforce_keys [:names]
	defstruct names: nil
end


defmodule Converge.PackagesMissing do
	@enforce_keys [:names]
	defstruct names: nil
end
