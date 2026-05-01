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

	for event in pairs(events) do
		vim.api.nvim_create_autocmd(event, {
			callback = function(props)
				trigger(event, props)
			end,
		})
	end
end

function EventHandlers:handle_ModeChanged(props)
	if not vim.api.nvim_buf_is_valid(props.buf) then
		return
	end
	local buf = self.nekovim.buffers_props[props.buf]
	if buf then
		self.nekovim.buffers_props[props.buf].mode = vim.api.nvim_get_mode().mode
		self.nekovim:update()
	end
end

function EventHandlers:handle_BufEnter(props)
	if not vim.api.nvim_buf_is_valid(props.buf) then
		return
	end

	local filePath = vim.api.nvim_buf_get_name(props.buf)
	local fileType = vim.bo[props.buf].filetype or nil

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
