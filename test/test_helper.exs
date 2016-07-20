defmodule SilentReporter do
	def running(_) do end
	def meeting(_) do end
	def already_met(_) do end
	def just_met(_) do end
	def failed(_) do end
	def done(_) do end
end

ExUnit.start()
