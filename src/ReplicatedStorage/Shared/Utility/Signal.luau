--!strict
local LemonSignal = require(script.Parent.Parent.Packages.LemonSignal)

export type Signal<T...> = LemonSignal.Signal<T...>
export type Connection<U...> = LemonSignal.Connection<U...>

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	return LemonSignal.new()
end

function Signal.wrap<T...>(signal: RBXScriptSignal): Signal<T...>
	return LemonSignal.wrap(signal)
end

return Signal
