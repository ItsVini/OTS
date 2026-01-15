-- Prevent spam commands --
-- Returns true if command can be used now, false if the player is exhausted.
function checkExhausted(player, storage, seconds)
	local cid = player:getId()
	local v = exhaustion.get(cid, storage)
	if not v then
		exhaustion.set(cid, storage, seconds)
		return true
	end

	player:sendTextMessage(MESSAGE_EVENT_DEFAULT, "Please wait " .. v .. " seconds before trying this command again.")
	return false
end
