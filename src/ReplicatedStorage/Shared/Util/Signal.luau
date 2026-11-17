local Connection = {}
Connection.__index = Connection

function Connection.new(signal, callback)
	return setmetatable({ signal = signal, callback = callback, connected = true }, Connection)
end

function Connection:Disconnect()
	if not self.connected then
		return
	end
	self.connected = false
	local handlers = self.signal.handlers
	local index = table.find(handlers, self)
	if index then
		table.remove(handlers, index)
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end

function Signal:Connect(callback)
	local connection = Connection.new(self, callback)
	table.insert(self.handlers, connection)
	return connection
end

function Signal:Once(callback)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Fire(...)
	for _, connection in table.clone(self.handlers) do
		if connection.connected then
			task.spawn(connection.callback, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, connection in self.handlers do
		connection.connected = false
	end
	table.clear(self.handlers)
end

Signal.Destroy = Signal.DisconnectAll

return Signal
