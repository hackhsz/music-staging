--!strict
-- SongCatalog — every playable song. The menu builds its rows from this list and
-- DDSClient resolves the selected "SongId" attribute here to a chart module + audio.
-- To add a song: drop its Sound in ReplicatedStorage.Songs, its charts module in DDS,
-- and append an entry below.

local RS = game:GetService("ReplicatedStorage")
local DDS = script.Parent
local Songs = RS:WaitForChild("Songs")

export type Song = {
	id: string,
	title: string,
	genre: string, -- must match a SongTypeSort tab label: "K-POP" | "POP" | "EDM" | "CUTE"
	stars: number, -- 1..3, shown on the row
	iconId: string?, -- "rbxassetid://…"; nil keeps the placeholder art
	charts: ModuleScript, -- returns { easy = chart, normal = chart, hard = chart }
	sound: Sound, -- SoundId is fed to the MusicRig AudioPlayer
	favorite: boolean?,
}

local songs: { Song } = {
	{
		id = "combo-fever",
		title = "Combo Fever",
		genre = "POP",
		stars = 2,
		charts = DDS:WaitForChild("ComboFeverCharts"),
		sound = Songs:WaitForChild("Combo Fever"),
	},
}

local SongCatalog = {}
SongCatalog.songs = songs

function SongCatalog.byId(id: string?): Song?
	for _, song in songs do
		if song.id == id then
			return song
		end
	end
	return nil
end

return SongCatalog
