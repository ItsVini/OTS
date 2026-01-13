-- Advanced NPC System by Jiddo

if KeywordHandler == nil then
	KeywordNode = {
		keywords = nil,
		callback = nil,
		parameters = nil,
		children = nil,
		parent = nil
	}

	-- Created a new keywordnode with the given keywords, callback function and parameters and without any childNodes.
	function KeywordNode:new(keys, func, param)
		local obj = {}
		obj.keywords = keys
		obj.callback = func
		obj.parameters = param
		obj.children = {}
		setmetatable(obj, self)
		self.__index = self
		return obj
	end

	-- Calls the underlying callback function if it is not nil.
	function KeywordNode:processMessage(cid, message)
		return (self.callback == nil or self.callback(cid, message, self.keywords, self.parameters, self))
	end

	-- Returns true if message contains all patterns/strings found in keywords.
	function KeywordNode:checkMessage(message)
		if self.keywords.callback ~= nil then
			return self.keywords.callback(self.keywords, message)
		end

		for _, v in ipairs(self.keywords) do
			if type(v) == 'string' then
				local a, b = string.find(message, v)
				if a == nil or b == nil then
					return false
				end
			end
		end
		return true
	end

	-- Returns the parent of this node or nil if no such node exists.
	function KeywordNode:getParent()
		return self.parent
	end

	-- Returns an array of the callback function parameters assosiated with this node.
	function KeywordNode:getParameters()
		return self.parameters
	end

	-- Returns an array of the triggering keywords assosiated with this node.
	function KeywordNode:getKeywords()
		return self.keywords
	end

	-- Adds a childNode to this node. Creates the childNode based on the parameters (k = keywords, c = callback, p = parameters)
	function KeywordNode:addChildKeyword(keywords, callback, parameters)
		local new = KeywordNode:new(keywords, callback, parameters)
		return self:addChildKeywordNode(new)
	end

	-- Adds a pre-created childNode to this node. Should be used for example if several nodes should have a common child.
	function KeywordNode:addChildKeywordNode(childNode)
		self.children[#self.children + 1] = childNode
		childNode.parent = self
		return childNode
	end

	KeywordHandler = {
		root = nil,
		lastNode = nil
	}

	-- Creates a new keywordhandler with an empty rootnode.
	function KeywordHandler:new()
		local obj = {}
		obj.root = KeywordNode:new(nil, nil, nil)
		obj.lastNode = {}
		setmetatable(obj, self)
		self.__index = self
		return obj
	end

	-- Resets the lastNode field, and this resetting the current position in the node hierarchy to root.
	function KeywordHandler:reset(cid)
		if self.lastNode[cid] then
			self.lastNode[cid] = nil
		end
	end

	-- Makes sure the correct childNode of lastNode gets a chance to process the message.
	function KeywordHandler:processMessage(cid, message)
		local node = self:getLastNode(cid)
		if node == nil then
			error('No root node found.')
			return false
		end

		local ret = self:processNodeMessage(node, cid, message)
		if ret then
			return true
		end

		if node:getParent() then
			node = node:getParent() -- Search through the parent.
			local ret = self:processNodeMessage(node, cid, message)
			if ret then
				return true
			end
		end

		if node ~= self:getRoot() then
			node = self:getRoot() -- Search through the root.
			local ret = self:processNodeMessage(node, cid, message)
			if ret then
				return true
			end
		end
		return false
	end

	-- Tries to process the given message using the node parameter's children and calls the node's callback function if found.
	--	Returns the childNode which processed the message or nil if no such node was found.
	function KeywordHandler:processNodeMessage(node, cid, message)
		local messageLower = string.lower(message)
		for i, childNode in pairs(node.children) do
			if childNode:checkMessage(messageLower) then
				local oldLast = self.lastNode[cid]
				self.lastNode[cid] = childNode
				childNode.parent = node -- Make sure node is the parent of childNode (as one node can be parent to several nodes).
				if childNode:processMessage(cid, message) then
					return true
				end
				self.lastNode[cid] = oldLast
			end
		end
		return false
	end

	-- Returns the root keywordnode
	function KeywordHandler:getRoot()
		return self.root
	end

	-- Returns the last processed keywordnode or root if no last node is found.
	function KeywordHandler:getLastNode(cid)
		return self.lastNode[cid] or self:getRoot()
	end

	-- Adds a new keyword to the root keywordnode. Returns the new node.
	function KeywordHandler:addKeyword(keys, callback, parameters)
		return self:getRoot():addChildKeyword(keys, callback, parameters)
	end

	-- Moves the current position in the keyword hierarchy steps upwards. Steps defalut value = 1.
	function KeywordHandler:moveUp(cid, steps)
		if steps == nil or type(steps) ~= "number" then
			steps = 1
		end

		for i = 1, steps do
			if self.lastNode[cid] == nil then
				return nil
			end
			self.lastNode[cid] = self.lastNode[cid]:getParent() or self:getRoot()
		end
		return self.lastNode[cid]
	end


	---------------------------------------------------------------------------
	-- Compatibility helpers (TFS 8.0 / mixed datapacks)
	-- Some newer NPC scripts expect:
	--   keywordHandler:addAliasKeyword(...)
	--   keywordHandler:addGreetKeyword(...)
	--   keywordHandler:addFarewellKeyword(...)
	--
	-- This is a lightweight implementation that works with the classic Jiddo NPCSystem.

	-- Keep track of the last added keyword node (used by addAliasKeyword).
	do
		local _oldAddKeyword = KeywordHandler.addKeyword
		function KeywordHandler:addKeyword(keys, callback, parameters)
			local node = _oldAddKeyword(self, keys, callback, parameters)
			self._lastAddedKeywordNode = node
			return node
		end
	end

	-- Adds a synonym keyword for the previously added keyword node.
	-- Example usage in scripts:
	--   keywordHandler:addKeyword({'bye'}, ...)
	--   keywordHandler:addAliasKeyword({'farewell'})
	function KeywordHandler:addAliasKeyword(keys)
		local last = self._lastAddedKeywordNode
		if not last then
			return nil
		end

		local parent = last.parent or self:getRoot()
		local aliasNode = parent:addChildKeyword(keys, last.callback, last.parameters)

		-- If the original keyword has children (yes/no nodes etc.), copy references as well.
		-- (Shared children are fine in this NPCSystem.)
		if last.children and #last.children > 0 then
			for _, child in ipairs(last.children) do
				aliasNode:addChildKeywordNode(child)
			end
		end

		self._lastAddedKeywordNode = aliasNode
		return aliasNode
	end

	-- Message matcher similar to the one used in some module implementations.
	local function _defaultMessageMatcher(keywords, message)
		-- message is already lowercased by KeywordHandler:processNodeMessage
		for _, word in pairs(keywords) do
			if type(word) == "string" then
				local w = word:lower()
				-- word boundary match:
				-- %f[%w] ... %f[%W] makes sure we don't match inside other words.
				if message:find("%f[%w]" .. w .. "%f[%W]") then
					return true
				end
			end
		end
		return false
	end

	-- Internal greet handler used by addGreetKeyword.
	local function _onGreetKeyword(cid, message, keywords, parameters)
		local npcHandler = parameters and parameters.npcHandler or nil
		if not npcHandler then
			return false
		end

		local player = Player and Player(cid) or nil

		-- Optional condition (if returns false -> allow other greet keywords to try).
		if parameters._check then
			local ok = parameters._check(player or cid)
			if not ok then
				return false
			end
		end

		-- Focus the player (so follow-up keywords work like in typical NPC scripts).
		if npcHandler.isFocused and npcHandler.addFocus then
			if not npcHandler:isFocused(cid) then
				npcHandler:addFocus(cid)
			end
		end

		-- Say custom greet text if provided, otherwise fall back to npcHandler:onGreet / greet.
		if parameters.text and npcHandler.say then
			local name = player and player:getName() or getCreatureName(cid)
			local out = tostring(parameters.text):gsub("|PLAYERNAME|", name)
			npcHandler:say(out, cid, true)
		elseif npcHandler.onGreet then
			npcHandler:onGreet(cid, message)
		elseif npcHandler.greet then
			npcHandler:greet(cid, message)
		end

		-- Optional action after greeting (heal, teleport etc.)
		if parameters._action then
			parameters._action(player or cid)
		end

		return true
	end

	-- Internal farewell handler used by addFarewellKeyword.
	local function _onFarewellKeyword(cid, message, keywords, parameters)
		local npcHandler = parameters and parameters.npcHandler or nil
		if not npcHandler then
			return false
		end

		local player = Player and Player(cid) or nil

		if parameters._check then
			local ok = parameters._check(player or cid)
			if not ok then
				return false
			end
		end

		-- Say custom farewell text if provided; otherwise call npcHandler:onFarewell / unGreet.
		if parameters.text and npcHandler.say then
			local name = player and player:getName() or getCreatureName(cid)
			local out = tostring(parameters.text):gsub("|PLAYERNAME|", name)
			npcHandler:say(out, cid, true)
			-- try to unfocus after saying
			if npcHandler.unGreet then
				npcHandler:unGreet(cid)
			elseif npcHandler.releaseFocus then
				npcHandler:releaseFocus(cid)
			end
		elseif npcHandler.onFarewell then
			npcHandler:onFarewell(cid)
		elseif npcHandler.unGreet then
			npcHandler:unGreet(cid)
		end

		if parameters._action then
			parameters._action(player or cid)
		end

		return true
	end

	-- Adds a greeting keyword that supports newer script format:
	--   keywordHandler:addGreetKeyword({'hi'}, {npcHandler = npcHandler, text = '...'}, conditionFunc, actionFunc)
	function KeywordHandler:addGreetKeyword(keys, parameters, checkFunc, actionFunc)
		if type(keys) ~= "table" then
			keys = {keys}
		end

		local kw = {}
		for i, v in ipairs(keys) do
			kw[i] = type(v) == "string" and v:lower() or v
		end
		kw.callback = (FocusModule and FocusModule.messageMatcher) or _defaultMessageMatcher

		parameters = parameters or {}
		parameters._check = checkFunc
		parameters._action = actionFunc

		return self:addKeyword(kw, _onGreetKeyword, parameters)
	end

	-- Adds a farewell keyword that supports newer script format:
	--   keywordHandler:addFarewellKeyword({'bye'}, {npcHandler = npcHandler, text = '...'}, conditionFunc, actionFunc)
	function KeywordHandler:addFarewellKeyword(keys, parameters, checkFunc, actionFunc)
		if type(keys) ~= "table" then
			keys = {keys}
		end

		local kw = {}
		for i, v in ipairs(keys) do
			kw[i] = type(v) == "string" and v:lower() or v
		end
		kw.callback = (FocusModule and FocusModule.messageMatcher) or _defaultMessageMatcher

		parameters = parameters or {}
		parameters._check = checkFunc
		parameters._action = actionFunc

		return self:addKeyword(kw, _onFarewellKeyword, parameters)
	end

end
