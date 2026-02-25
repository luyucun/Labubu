--[[
脚本名称: IconDisplayHelper
脚本类型: ModuleScript
脚本位置: ReplicatedStorage/Modules/IconDisplayHelper
版本: V1.1
职责: 统一图标显示参数并对图标资源做重试预加载，降低图标长期发糊概率
]]

local ContentProvider = game:GetService("ContentProvider")

local IconDisplayHelper = {}

local readyAssets = {}
local failedAssets = {}
local lastPendingWarnAt = 0

local FAILED_RETRY_INTERVAL = 30
local ATTEMPT_WAIT_SECONDS = {
	0.8,
	1.2,
	1.6,
}
local PENDING_WARN_COOLDOWN = 10

local function normalizeContentId(contentId)
	if type(contentId) ~= "string" then
		return nil
	end
	local trimmed = string.gsub(contentId, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return nil
	end
	return trimmed
end

local function collectPending(contentIds)
	local pending = {}
	local seen = {}
	local now = os.clock()
	if type(contentIds) ~= "table" then
		return pending
	end
	for _, value in ipairs(contentIds) do
		local contentId = normalizeContentId(value)
		local failedAt = contentId and failedAssets[contentId] or nil
		local canRetryFailed = failedAt == nil or (now - failedAt) >= FAILED_RETRY_INTERVAL
		if contentId and canRetryFailed and not readyAssets[contentId] and not seen[contentId] then
			seen[contentId] = true
			table.insert(pending, contentId)
		end
	end
	return pending
end

local function classifyFetchStatus(contentId)
	local ok, status = pcall(function()
		return ContentProvider:GetAssetFetchStatus(contentId)
	end)
	if not ok then
		return "pending"
	end
	local name = tostring(status)
	if name == "Enum.AssetFetchStatus.Success" then
		readyAssets[contentId] = true
		return "success"
	end
	if string.find(name, "Fail", 1, true) then
		failedAssets[contentId] = os.clock()
		return "failed"
	end
	return "pending"
end

local function addUnique(targetList, targetSet, contentId)
	if not targetSet[contentId] then
		targetSet[contentId] = true
		table.insert(targetList, contentId)
	end
end

local function collectRetryTargets(contentIds, failedList, failedSet)
	local retryTargets = {}
	for _, contentId in ipairs(contentIds) do
		local state = classifyFetchStatus(contentId)
		if state == "success" then
			readyAssets[contentId] = true
		elseif state == "failed" then
			addUnique(failedList, failedSet, contentId)
		else
			table.insert(retryTargets, contentId)
		end
	end
	return retryTargets
end

function IconDisplayHelper.Preload(contentIds, maxRetry)
	local pending = collectPending(contentIds)
	if #pending <= 0 then
		return true
	end

	local failed = {}
	local failedSet = {}
	local retryCount = math.max(1, tonumber(maxRetry) or 2)
	for attempt = 1, retryCount do
		pcall(function()
			ContentProvider:PreloadAsync(pending)
		end)

		local waitSeconds = ATTEMPT_WAIT_SECONDS[attempt] or ATTEMPT_WAIT_SECONDS[#ATTEMPT_WAIT_SECONDS]
		local deadline = os.clock() + waitSeconds
		repeat
			pending = collectRetryTargets(pending, failed, failedSet)
			if #pending <= 0 then
				break
			end
			task.wait(0.1)
		until os.clock() >= deadline

		if #pending <= 0 then
			break
		end
	end

	if #failed > 0 then
		local samples = {}
		local sampleCount = math.min(3, #failed)
		for index = 1, sampleCount do
			table.insert(samples, failed[index])
		end
		warn(string.format("[IconDisplayHelper] Some icons fetch failed: %d, sample=%s", #failed, table.concat(samples, ", ")))
	end

	if #pending > 0 then
		local now = os.clock()
		if now - lastPendingWarnAt >= PENDING_WARN_COOLDOWN then
			lastPendingWarnAt = now
			local samples = {}
			local sampleCount = math.min(3, #pending)
			for index = 1, sampleCount do
				table.insert(samples, pending[index])
			end
			warn(string.format("[IconDisplayHelper] Some icons are still pending: %d, sample=%s", #pending, table.concat(samples, ", ")))
		end
	end
	return #pending <= 0 and #failed <= 0
end

function IconDisplayHelper.Apply(imageObject, contentId)
	if not imageObject then
		return
	end
	if not (imageObject:IsA("ImageLabel") or imageObject:IsA("ImageButton")) then
		return
	end

	-- 重置图集裁切与采样参数，避免模板残留导致图标发糊。
	imageObject.ImageRectOffset = Vector2.new(0, 0)
	imageObject.ImageRectSize = Vector2.new(0, 0)
	imageObject.ResampleMode = Enum.ResamplerMode.Default
	imageObject.Image = normalizeContentId(contentId) or ""
end

function IconDisplayHelper.ApplyAndPreload(imageObject, contentId)
	IconDisplayHelper.Apply(imageObject, contentId)
	local normalized = normalizeContentId(contentId)
	if not normalized then
		return
	end
	task.spawn(function()
		IconDisplayHelper.Preload({ normalized }, 2)
	end)
end

return IconDisplayHelper
