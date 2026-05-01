local Logger = require("lib.log")

---@class EventHandlers
---@field private nekovim NekoVim
local EventHandlers = {}

---@param nekovim NekoVim
function EventHandlers:setup(nekovim)
	self.nekovim = nekovim

	local events = {
		["VimLeavePre"] = function()
			self.nekovim:shutdown()
		end,
		["FocusGained"] = function()
			self.nekovim:update()
		end,

		---@param props {buf: integer}
		["BufEnter"] = function(props)
			self:handle_BufEnter(props)
		end,
		["BufWinEnter"] = function(props)
			self:handle_BufEnter(props)
		end,
		["WinEnter"] = function(props)
			self:handle_BufEnter(props)
		end,

		---@param props {buf: integer}
		["ModeChanged"] = function(props)
			self:handle_ModeChanged(props)
		end,

		---@param props {buf: integer}
		["BufWipeout"] = function(props)
			self:handle_BufWipeout(props)
		end,
	}

	---@param event string
	local function trigger(event, props)
		Logger:debug("EventHandlers:setup.trigger", event)

		vim.schedule(function()
			self.nekovim:restart_idle_timer()
			events[event](props)
		end)
	end

	self.update_timer = vim.loop.new_timer()
	self.update_timer:start(
		15000,
		15000,
		vim.schedule_wrap(function()
			local buf = self.nekovim.current_buf
			if buf and vim.api.nvim_buf_is_valid(buf) then
				self.nekovim.buffers_props[buf] = nil
				self.nekovim:make_buf_props(buf)
				self.nekovim:update()
			end
		end)
	)

	for event in pairs(events) do
		vim.api.nvim_create_autocmd(event, {
			callback = function(props)
				trigger(event, props)
			end,
		})
	end
end

function EventHandlers:handle_ModeChanged(props)
	local buf = props.buf
	if buf == 0 then
		buf = vim.api.nvim_get_current_buf()
	end
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	if not self.nekovim.buffers_props[buf] then
		self.nekovim:make_buf_props(buf)
	end

	if self.nekovim.buffers_props[buf] then
		self.nekovim.buffers_props[buf].mode = vim.api.nvim_get_mode().mode
		self.nekovim:update()
	end
end

function EventHandlers:handle_BufEnter(props)
	if not vim.api.nvim_buf_is_valid(props.buf) then
		return
	end

	local bt = vim.bo[props.buf].buftype
	local ft = vim.bo[props.buf].filetype
	if bt == "nofile" or bt == "prompt" or bt == "quickfix" or ft == "noice" then
		return
	end

	self.nekovim.current_buf = props.buf
	self.nekovim:make_buf_props(props.buf)
	self.nekovim:update()
end

function EventHandlers:handle_BufWipeout(props)
	-- Telescope creates temporary internal buffers that get destroyed using
	-- BufWipeout after usage.
	if not self.nekovim.buffers_props[props.buf] then
		return
	end

	self.nekovim.buffers_props[props.buf] = nil
end

return EventHandlers
