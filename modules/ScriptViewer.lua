--[[
	Script Viewer App Module
	
	A script viewer that is basically a notepad
]]

-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer, Properties, ScriptViewer, Notebook -- Major Apps
local API,RMD,env,service,plr,create,createSimple -- Main Locals

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings

	API = data.API
	RMD = data.RMD
	env = data.env
	service = data.service
	plr = data.plr
	create = data.create
	createSimple = data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	Properties = Apps.Properties
	ScriptViewer = Apps.ScriptViewer
	Notebook = Apps.Notebook
end

local function main()
	local ScriptViewer = {}

	local window,codeFrame

	ScriptViewer.ViewScript = function(scr)
		ScriptViewer.CurrentScript = scr
		local s,source = pcall(env.decompile or function() end,scr)
		if not s or not source then
			source = "local test = 5\n\nlocal c = test + tick()\ngame.Workspace.Board:Destroy()\nstring.match('wow\\'f',\"yes\",3.4e-5,true)\ngame. Workspace.Wow\nfunction bar() print(54) end\n string . match() string 4 .match()"
			source = source.."\n"..[==[
			function a.sad() end
			function a.b:sad() end
			function 4.why() end
			function a b() end
			function string.match() end
			function string.match.why() end
			function local() end
			function local.thing() end
			string  . "sad" match
			().magnitude = 3
			a..b
			a..b()
			a...b
			a...b()
			a....b
			a....b()
			string..match()
			string....match()
			]==]
		end

		codeFrame:SetText(source)
		window:Show()
	end

	-- Helper: create a toolbar button for Script Viewer
	local function makeToolbarButton(parent, text, posX, sizeX)
		local btn = Instance.new("TextButton")
		btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		btn.BackgroundTransparency = 0
		btn.BorderSizePixel = 0
		btn.Position = UDim2.new(0, posX, 0, 0)
		btn.Size = UDim2.new(0, sizeX, 0, 20)
		btn.Text = text
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Font = Enum.Font.SourceSans
		btn.TextSize = 13
		btn.AutoButtonColor = true
		btn.Parent = parent

		-- Hover effect
		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		end)

		return btn
	end

	ScriptViewer.CurrentScript = nil

	ScriptViewer.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Script Viewer")
		window:Resize(500,400)
		ScriptViewer.Window = window

		-- Toolbar frame
		local toolbar = Instance.new("Frame")
		toolbar.Name = "Toolbar"
		toolbar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		toolbar.BorderSizePixel = 0
		toolbar.Size = UDim2.new(1, 0, 0, 20)
		toolbar.Parent = window.GuiElems.Content

		-- Code frame below toolbar
		codeFrame = Lib.CodeFrame.new()
		codeFrame.Frame.Position = UDim2.new(0, 0, 0, 20)
		codeFrame.Frame.Size = UDim2.new(1, 0, 1, -20)
		codeFrame.Frame.Parent = window.GuiElems.Content

		-- Button: Copy to Clipboard
		local copyBtn = makeToolbarButton(toolbar, "Copy to Clipboard", 0, 130)
		copyBtn.MouseButton1Click:Connect(function()
			if not env.setclipboard then
				warn("[Dex] Copy to Clipboard: executor does not expose setclipboard.")
				return
			end
			local source = codeFrame:GetText()
			local ok, err = pcall(env.setclipboard, source)
			if ok then
				-- Brief visual feedback
				local orig = copyBtn.Text
				copyBtn.Text = "Copied!"
				copyBtn.TextColor3 = Color3.fromRGB(100, 220, 100)
				task.delay(1.2, function()
					copyBtn.Text = orig
					copyBtn.TextColor3 = Color3.new(1, 1, 1)
				end)
			else
				warn("[Dex] Copy to Clipboard failed: " .. tostring(err))
			end
		end)

		-- Button: Save to File
		local saveBtn = makeToolbarButton(toolbar, "Save to File", 132, 100)
		saveBtn.MouseButton1Click:Connect(function()
			if not env.writefile then
				warn("[Dex] Save to File: executor does not expose writefile.")
				return
			end

			local source = codeFrame:GetText()
			local scriptName = "Script"
			if ScriptViewer.CurrentScript then
				scriptName = tostring(ScriptViewer.CurrentScript.Name):gsub("[^%w_%-]", "_")
			end
			local filename = "dex/saved/" .. scriptName .. "_" .. game.PlaceId .. "_" .. os.time() .. ".lua"

			-- Ensure folder exists
			if env.makefolder then
				pcall(env.makefolder, "dex")
				pcall(env.makefolder, "dex/saved")
			end

			local ok, err = pcall(env.writefile, filename, source)
			if ok then
				print("[Dex] Script saved to: " .. filename)
				local orig = saveBtn.Text
				saveBtn.Text = "Saved!"
				saveBtn.TextColor3 = Color3.fromRGB(100, 220, 100)
				task.delay(1.2, function()
					saveBtn.Text = orig
					saveBtn.TextColor3 = Color3.new(1, 1, 1)
				end)
			else
				warn("[Dex] Save to File failed: " .. tostring(err))
			end
		end)

		-- Button: Dump Function
		local dumpBtn = makeToolbarButton(toolbar, "Dump Function", 234, 110)
		dumpBtn.MouseButton1Click:Connect(function()
			local scr = ScriptViewer.CurrentScript
			if not scr then
				warn("[Dex] Dump Function: no script selected.")
				return
			end

			-- Collect available debug info
			local lines = {}
			local function addLine(label, value)
				lines[#lines+1] = string.format("%-20s %s", label..":", tostring(value))
			end

			addLine("Script", tostring(scr))
			addLine("ClassName", scr.ClassName)
			addLine("Disabled", tostring(pcall(function() return scr.Disabled end) and scr.Disabled or "N/A"))

			-- Script path
			local path = ""
			local cur = scr
			local parts = {}
			while cur and cur ~= game do
				table.insert(parts, 1, tostring(cur.Name))
				local ok, par = pcall(function() return cur.Parent end)
				if not ok or not par then break end
				cur = par
			end
			table.insert(parts, 1, "game")
			addLine("Path", table.concat(parts, "."))

			-- getscriptfunction / getscripthash if available
			if env.getscripthash then
				local ok, hash = pcall(env.getscripthash, scr)
				addLine("Script Hash", ok and hash or "unavailable")
			end

			if env.getscriptfunction then
				local ok, fn = pcall(env.getscriptfunction, scr)
				if ok and fn then
					addLine("Closure Type", tostring(env.islclosure and env.islclosure(fn) and "LClosure" or "CClosure"))
					-- Upvalues
					if env.getupvalues then
						local ok2, ups = pcall(env.getupvalues, fn)
						if ok2 and ups then
							addLine("Upvalue Count", tostring(#ups))
							for i, v in ipairs(ups) do
								addLine("  Upvalue["..i.."]", tostring(v))
							end
						end
					end
					-- Constants
					if env.getconstants then
						local ok2, consts = pcall(env.getconstants, fn)
						if ok2 and consts then
							addLine("Constant Count", tostring(#consts))
							for i, v in ipairs(consts) do
								if type(v) == "string" and #v < 80 then
									addLine("  Const["..i.."]", v)
								end
							end
						end
					end
				else
					addLine("getscriptfunction", "unavailable for this script")
				end
			else
				addLine("getscriptfunction", "not exposed by executor")
			end

			local dump = "-- Dex Function Dump\n-- " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n" .. table.concat(lines, "\n")

			-- Show dump in code viewer
			codeFrame:SetText(dump)

			-- Also save to file if possible
			if env.writefile then
				local scriptName = tostring(scr.Name):gsub("[^%w_%-]", "_")
				local filename = "dex/saved/dump_" .. scriptName .. "_" .. os.time() .. ".txt"
				if env.makefolder then
					pcall(env.makefolder, "dex")
					pcall(env.makefolder, "dex/saved")
				end
				pcall(env.writefile, filename, dump)
				print("[Dex] Dump saved to: " .. filename)
			end

			print("[Dex] Function dump complete for: " .. tostring(scr))
		end)
	end

	return ScriptViewer
end

-- TODO: Remove when open source
if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end