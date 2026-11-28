--!strict
local RunService = game:GetService("RunService")

local Telemetry = {}

local funnelRemote: RemoteEvent? = nil

-- A Studio trace only; what is measured goes through step and FunnelCatalog.
function Telemetry.track(eventName: string, data: any?)
	if not RunService:IsStudio() then
		return
	end

	if data ~= nil then
		print(("[DanceDanceStep][Funnel] %s %s"):format(eventName, tostring(data)))
	else
		print(("[DanceDanceStep][Funnel] %s"):format(eventName))
	end
end

-- Main hands over ReportFunnelStep; the server logs the step (FunnelCatalog).
function Telemetry.bindFunnels(remote: RemoteEvent)
	funnelRemote = remote
end

function Telemetry.step(funnel: string, step: string)
	if funnelRemote ~= nil then
		funnelRemote:FireServer({ funnel = funnel, step = step })
	end
end

return Telemetry
