--!strict
-- MenuSignals — client-side bus between DDSClient (pad + session loop) and
-- MenuController (the Import gui). Both are LocalScripts, so they share this instance.

local MenuSignals = {
	-- DDSClient -> menu: the pad's Start prompt was used; show the song select.
	OpenSongSelect = Instance.new("BindableEvent"),
	-- menu -> DDSClient: the player pressed Select on a row. Payload: song id.
	SongChosen = Instance.new("BindableEvent"),
	-- DDSClient -> menu: a session started (true) or ended (false). Menu hides while true.
	SessionState = Instance.new("BindableEvent"),
	-- menu -> panels: the left-nav tab that is now highlighted ("Nav_Settings"), or nil.
	NavSelected = Instance.new("BindableEvent"),
	-- panels -> menu: a panel's own close button; clears the nav highlight.
	CloseNav = Instance.new("BindableEvent"),
	activeNav = nil :: string?,
	-- Latest session state, for a menu that (re)spawns mid-session.
	playing = false,
}

MenuSignals.NavSelected.Event:Connect(function(navName: string?)
	MenuSignals.activeNav = navName
end)

MenuSignals.SessionState.Event:Connect(function(playing: boolean)
	MenuSignals.playing = playing
end)

return MenuSignals
