--!strict
-- The floor and the arena live in different client scripts. Both require this
-- module, which the client caches once, so the pad can cue the room without a
-- global or a replicated object.
export type Listener = (cue: string, value: any) -> ()

local StageCue = {}

local listeners: { Listener } = {}

function StageCue.connect(listener: Listener)
	table.insert(listeners, listener)
end

function StageCue.fire(cue: string, value: any)
	for _, listener in listeners do
		task.spawn(listener, cue, value)
	end
end

return StageCue
