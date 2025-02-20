tArgs = {...}

if not term.isColor or not term.isColor() then
	error('Jopa chlen requires (gold) Computer')
end

_jstr = [[
	local base = _G

	-----------------------------------------------------------------------------
	-- Module declaration
	-----------------------------------------------------------------------------

	-- Public functions

	-- Private functions
	local decode_scanArray
	local decode_scanComment
	local decode_scanConstant
	local decode_scanNumber
	local decode_scanObject
	local decode_scanString
	local decode_scanWhitespace
	local encodeString
	local isArray
	local isEncodable

	-----------------------------------------------------------------------------
	-- PUBLIC FUNCTIONS
	-----------------------------------------------------------------------------
	--- Encodes an arbitrary Lua object / variable.
	-- @param v The Lua object / variable to be JSON encoded.
	-- @return String containing the JSON encoding in internal Lua string format (i.e. not unicode)
	function encode (v)
	  -- Handle nil values
	  if v==nil then
	    return "null"
	  end
	  
	  local vtype = base.type(v)  

	  -- Handle strings
	  if vtype=='string' then    
	    return '"' .. encodeString(v) .. '"'      -- Need to handle encoding in string
	  end
	  
	  -- Handle booleans
	  if vtype=='number' or vtype=='boolean' then
	    return base.tostring(v)
	  end
	  
	  -- Handle tables
	  if vtype=='table' then
	    local rval = {}
	    -- Consider arrays separately
	    local bArray, maxCount = isArray(v)
	    if bArray then
	      for i = 1,maxCount do
	        table.insert(rval, encode(v[i]))
	      end
	    else -- An object, not an array
	      for i,j in base.pairs(v) do
	        if isEncodable(i) and isEncodable(j) then
	          table.insert(rval, '"' .. encodeString(i) .. '":' .. encode(j))
	        end
	      end
	    end
	    if bArray then
	      return '[' .. table.concat(rval,',') ..']'
	    else
	      return '{' .. table.concat(rval,',') .. '}'
	    end
	  end
	  
	  -- Handle null values
	  if vtype=='function' and v==null then
	    return 'null'
	  end
	  
	  base.assert(false,'encode attempt to encode unsupported type ' .. vtype .. ':' .. base.tostring(v))
	end


	--- Decodes a JSON string and returns the decoded value as a Lua data structure / value.
	-- @param s The string to scan.
	-- @param [startPos] Optional starting position where the JSON string is located. Defaults to 1.
	-- @param Lua object, number The object that was scanned, as a Lua table / string / number / boolean or nil,
	-- and the position of the first character after
	-- the scanned JSON object.
	function decode(s, startPos)
	  startPos = startPos and startPos or 1
	  startPos = decode_scanWhitespace(s,startPos)
	  base.assert(startPos<=string.len(s), 'Unterminated JSON encoded object found at position in [' .. s .. ']')
	  local curChar = string.sub(s,startPos,startPos)
	  -- Object
	  if curChar=='{' then
	    return decode_scanObject(s,startPos)
	  end
	  -- Array
	  if curChar=='[' then
	    return decode_scanArray(s,startPos)
	  end
	  -- Number
	  if string.find("+-0123456789.e", curChar, 1, true) then
	    return decode_scanNumber(s,startPos)
	  end
	  -- String
	  if curChar=='"' or curChar=="'" then
	    return decode_scanString(s,startPos)
	  end
	  if string.sub(s,startPos,startPos+1)=='/*' then
	    return decode(s, decode_scanComment(s,startPos))
	  end
	  -- Otherwise, it must be a constant
	  return decode_scanConstant(s,startPos)
	end

	--- The null function allows one to specify a null value in an associative array (which is otherwise
	-- discarded if you set the value with 'nil' in Lua. Simply set t = { first=json.null }
	function null()
	  return null -- so json.null() will also return null ;-)
	end
	-----------------------------------------------------------------------------
	-- Internal, PRIVATE functions.
	-- Following a Python-like convention, I have prefixed all these 'PRIVATE'
	-- functions with an underscore.
	-----------------------------------------------------------------------------

	--- Scans an array from JSON into a Lua object
	-- startPos begins at the start of the array.
	-- Returns the array and the next starting position
	-- @param s The string being scanned.
	-- @param startPos The starting position for the scan.
	-- @return table, int The scanned array as a table, and the position of the next character to scan.
	function decode_scanArray(s,startPos)
	  local array = {}   -- The return value
	  local stringLen = string.len(s)
	  base.assert(string.sub(s,startPos,startPos)=='[','decode_scanArray called but array does not start at position ' .. startPos .. ' in string:\n'..s )
	  startPos = startPos + 1
	  -- Infinite loop for array elements
	  repeat
	    startPos = decode_scanWhitespace(s,startPos)
	    base.assert(startPos<=stringLen,'JSON String ended unexpectedly scanning array.')
	    local curChar = string.sub(s,startPos,startPos)
	    if (curChar==']') then
	      return array, startPos+1
	    end
	    if (curChar==',') then
	      startPos = decode_scanWhitespace(s,startPos+1)
	    end
	    base.assert(startPos<=stringLen, 'JSON String ended unexpectedly scanning array.')
	    object, startPos = decode(s,startPos)
	    table.insert(array,object)
	  until false
	end

	--- Scans a comment and discards the comment.
	-- Returns the position of the next character following the comment.
	-- @param string s The JSON string to scan.
	-- @param int startPos The starting position of the comment
	function decode_scanComment(s, startPos)
	  base.assert( string.sub(s,startPos,startPos+1)=='/*', "decode_scanComment called but comment does not start at position " .. startPos)
	  local endPos = string.find(s,'*/',startPos+2)
	  base.assert(endPos~=nil, "Unterminated comment in string at " .. startPos)
	  return endPos+2  
	end

	--- Scans for given constants: true, false or null
	-- Returns the appropriate Lua type, and the position of the next character to read.
	-- @param s The string being scanned.
	-- @param startPos The position in the string at which to start scanning.
	-- @return object, int The object (true, false or nil) and the position at which the next character should be 
	-- scanned.
	function decode_scanConstant(s, startPos)
	  local consts = { ["true"] = true, ["false"] = false, ["null"] = nil }
	  local constNames = {"true","false","null"}

	  for i,k in base.pairs(constNames) do
	    --print ("[" .. string.sub(s,startPos, startPos + string.len(k) -1) .."]", k)
	    if string.sub(s,startPos, startPos + string.len(k) -1 )==k then
	      return consts[k], startPos + string.len(k)
	    end
	  end
	  base.assert(nil, 'Failed to scan constant from string ' .. s .. ' at starting position ' .. startPos)
	end

	--- Scans a number from the JSON encoded string.
	-- (in fact, also is able to scan numeric +- eqns, which is not
	-- in the JSON spec.)
	-- Returns the number, and the position of the next character
	-- after the number.
	-- @param s The string being scanned.
	-- @param startPos The position at which to start scanning.
	-- @return number, int The extracted number and the position of the next character to scan.
	function decode_scanNumber(s,startPos)
	  local endPos = startPos+1
	  local stringLen = string.len(s)
	  local acceptableChars = "+-0123456789.e"
	  while (string.find(acceptableChars, string.sub(s,endPos,endPos), 1, true)
	   and endPos<=stringLen
	   ) do
	    endPos = endPos + 1
	  end
	  local stringValue = 'return ' .. string.sub(s,startPos, endPos-1)
	  local stringEval = base.loadstring(stringValue)
	  base.assert(stringEval, 'Failed to scan number [ ' .. stringValue .. '] in JSON string at position ' .. startPos .. ' : ' .. endPos)
	  return stringEval(), endPos
	end

	--- Scans a JSON object into a Lua object.
	-- startPos begins at the start of the object.
	-- Returns the object and the next starting position.
	-- @param s The string being scanned.
	-- @param startPos The starting position of the scan.
	-- @return table, int The scanned object as a table and the position of the next character to scan.
	function decode_scanObject(s,startPos)
	  local object = {}
	  local stringLen = string.len(s)
	  local key, value
	  base.assert(string.sub(s,startPos,startPos)=='{','decode_scanObject called but object does not start at position ' .. startPos .. ' in string:\n' .. s)
	  startPos = startPos + 1
	  repeat
	    startPos = decode_scanWhitespace(s,startPos)
	    base.assert(startPos<=stringLen, 'JSON string ended unexpectedly while scanning object.')
	    local curChar = string.sub(s,startPos,startPos)
	    if (curChar=='}') then
	      return object,startPos+1
	    end
	    if (curChar==',') then
	      startPos = decode_scanWhitespace(s,startPos+1)
	    end
	    base.assert(startPos<=stringLen, 'JSON string ended unexpectedly scanning object.')
	    -- Scan the key
	    key, startPos = decode(s,startPos)
	    base.assert(startPos<=stringLen, 'JSON string ended unexpectedly searching for value of key ' .. key)
	    startPos = decode_scanWhitespace(s,startPos)
	    base.assert(startPos<=stringLen, 'JSON string ended unexpectedly searching for value of key ' .. key)
	    base.assert(string.sub(s,startPos,startPos)==':','JSON object key-value assignment mal-formed at ' .. startPos)
	    startPos = decode_scanWhitespace(s,startPos+1)
	    base.assert(startPos<=stringLen, 'JSON string ended unexpectedly searching for value of key ' .. key)
	    value, startPos = decode(s,startPos)
	    object[key]=value
	  until false  -- infinite loop while key-value pairs are found
	end

	--- Scans a JSON string from the opening inverted comma or single quote to the
	-- end of the string.
	-- Returns the string extracted as a Lua string,
	-- and the position of the next non-string character
	-- (after the closing inverted comma or single quote).
	-- @param s The string being scanned.
	-- @param startPos The starting position of the scan.
	-- @return string, int The extracted string as a Lua string, and the next character to parse.
	function decode_scanString(s,startPos)
	  base.assert(startPos, 'decode_scanString(..) called without start position')
	  local startChar = string.sub(s,startPos,startPos)
	  base.assert(startChar=="'" or startChar=='"','decode_scanString called for a non-string')
	  local escaped = false
	  local endPos = startPos + 1
	  local bEnded = false
	  local stringLen = string.len(s)
	  repeat
	    local curChar = string.sub(s,endPos,endPos)
	    -- Character escaping is only used to escape the string delimiters
	    if not escaped then 
	      if curChar=='\\' then
	        escaped = true
	      else
	        bEnded = curChar==startChar
	      end
	    else
	      -- If we're escaped, we accept the current character come what may
	      escaped = false
	    end
	    endPos = endPos + 1
	    base.assert(endPos <= stringLen+1, "String decoding failed: unterminated string at position " .. endPos)
	  until bEnded
	  local stringValue = 'return ' .. string.sub(s, startPos, endPos-1)
	  local stringEval = base.loadstring(stringValue)
	  base.assert(stringEval, 'Failed to load string [ ' .. stringValue .. '] in JSON4Lua.decode_scanString at position ' .. startPos .. ' : ' .. endPos)
	  return stringEval(), endPos  
	end

	--- Scans a JSON string skipping all whitespace from the current start position.
	-- Returns the position of the first non-whitespace character, or nil if the whole end of string is reached.
	-- @param s The string being scanned
	-- @param startPos The starting position where we should begin removing whitespace.
	-- @return int The first position where non-whitespace was encountered, or string.len(s)+1 if the end of string
	-- was reached.
	function decode_scanWhitespace(s,startPos)
	  local whitespace=" \n\r\t"
	  local stringLen = string.len(s)
	  while ( string.find(whitespace, string.sub(s,startPos,startPos), 1, true)  and startPos <= stringLen) do
	    startPos = startPos + 1
	  end
	  return startPos
	end

	--- Encodes a string to be JSON-compatible.
	-- This just involves back-quoting inverted commas, back-quotes and newlines, I think ;-)
	-- @param s The string to return as a JSON encoded (i.e. backquoted string)
	-- @return The string appropriately escaped.
	function encodeString(s)
	  s = string.gsub(s,'\\','\\\\')
	  s = string.gsub(s,'"','\\"')
	  s = string.gsub(s,"'","\\'")
	  s = string.gsub(s,'\n','\\n')
	  s = string.gsub(s,'\t','\\t')
	  return s 
	end

	-- Determines whether the given Lua type is an array or a table / dictionary.
	-- We consider any table an array if it has indexes 1..n for its n items, and no
	-- other data in the table.
	-- I think this method is currently a little 'flaky', but can't think of a good way around it yet...
	-- @param t The table to evaluate as an array
	-- @return boolean, number True if the table can be represented as an array, false otherwise. If true,
	-- the second returned value is the maximum
	-- number of indexed elements in the array. 
	function isArray(t)
	  -- Next we count all the elements, ensuring that any non-indexed elements are not-encodable 
	  -- (with the possible exception of 'n')
	  local maxIndex = 0
	  for k,v in base.pairs(t) do
	    if (base.type(k)=='number' and math.floor(k)==k and 1<=k) then   -- k,v is an indexed pair
	      if (not isEncodable(v)) then return false end   -- All array elements must be encodable
	      maxIndex = math.max(maxIndex,k)
	    else
	      if (k=='n') then
	        if v ~= table.getn(t) then return false end  -- False if n does not hold the number of elements
	      else -- Else of (k=='n')
	        if isEncodable(v) then return false end
	      end  -- End of (k~='n')
	    end -- End of k,v not an indexed pair
	  end  -- End of loop across all pairs
	  return true, maxIndex
	end

	--- Determines whether the given Lua object / table / variable can be JSON encoded. The only
	-- types that are JSON encodable are: string, boolean, number, nil, table and json.null.
	-- In this implementation, all other types are ignored.
	-- @param o The object to examine.
	-- @return boolean True if the object should be JSON encoded, false if it should be ignored.
	function isEncodable(o)
	  local t = base.type(o)
	  return (t=='string' or t=='boolean' or t=='number' or t=='nil' or t=='table') or (t=='function' and o==null) 
	end
]]

function loadJSON()
	local sName = 'JSON'
		
	local tEnv = {}
	setmetatable( tEnv, { __index = _G } )
	local fnAPI, err = loadstring(_jstr)
	if fnAPI then
		setfenv( fnAPI, tEnv )
		fnAPI()
	else
		printError( err )
		return false
	end
	
	local tAPI = {}
	for k,v in pairs( tEnv ) do
		tAPI[k] =  v
	end
	
	_G[sName] = tAPI
	return true
end

local mainTitle = 'UltimateOS Installer'
local subTitle = 'Please wait...'

function Draw()
	sleep(0)
	term.setBackgroundColour(colours.white)
	term.clear()
	local w, h = term.getSize()
	term.setTextColour(colours.lightBlue)
	term.setCursorPos(math.ceil((w-#mainTitle)/2), 8)
	term.write(mainTitle)
	term.setTextColour(colours.blue)
	term.setCursorPos(math.ceil((w-#subTitle)/2), 10)
	term.write(subTitle)
end

tArgs = {...}

Settings = {
	InstallPath = '/', --Where the program's installed, don't always asume root (if it's run under something like OneOS)
	Hidden = false, --Whether or not the update is hidden (doesn't write to the screen), useful for background updates
	GitHubUsername = 'PlushPersik', --Your GitHub username as it appears in the URL
	GitHubRepoName = 'UltimateOS', --The repo name as it appears in the URL
	DownloadReleases = true, --If true it will download the latest release, otherwise it will download the files as they currently appear
	UpdateFunction = nil, --Sent when something happens (file downloaded etc.)
	TotalBytes = 0, --Do not change this value (especially programatically)!
	DownloadedBytes = 0, --Do not change this value (especially programatically)!
	Status = '',
	SecondaryStatus = '',
}

loadJSON()

function downloadJSON(path)
	local _json = http.get(path)
	if not _json then
		error('Could not download: '..path..' Check your connection.')
	end
	return JSON.decode(_json.readAll())
end

if http then
	subTitle = 'HTTP enabled, attempting update...'
	Draw()
else
	subTitle = 'HTTP is required to update.'
	Draw()
	error('')
end

subTitle = 'Determining Latest Version'
Draw()
local releases = downloadJSON('https://api.github.com/repos/'..Settings.GitHubUsername..'/'..Settings.GitHubRepoName..'/releases')
local latestReleaseTag = releases[1].tag_name
if not tArgs or #tArgs ~= 1 and tArgs[1] ~= 'beta' then
	for i, v in ipairs(releases) do
		if not v.prerelease then
			latestReleaseTag = v.tag_name
			break
		end
	end
end
subTitle = 'Optaining Latest Version URL'
Draw()
local refs = downloadJSON('https://api.github.com/repos/'..Settings.GitHubUsername..'/'..Settings.GitHubRepoName..'/git/refs/tags/'..latestReleaseTag)
local latestReleaseSha = refs.object.sha

subTitle = 'Downloading File Listing'
Draw()

local tree = downloadJSON('https://api.github.com/repos/'..Settings.GitHubUsername..'/'..Settings.GitHubRepoName..'/git/trees/'..latestReleaseSha..'?recursive=1').tree

local blacklist = {
	'/.gitignore',
	'/README.md',
	'/TODO',
	'/Desktop/.Desktop.settings',
	'/.version'
}

function isBlacklisted(path)
	for i, item in ipairs(blacklist) do
		if item == path then
			return true
		end
	end
	return false
end

Settings.TotalFiles = 0
Settings.TotalBytes = 0
for i, v in ipairs(tree) do
	if not isBlacklisted(Settings.InstallPath..v.path) and v.size then
		Settings.TotalBytes = Settings.TotalBytes + v.size
		Settings.TotalFiles = Settings.TotalFiles + 1
	end
end

Settings.DownloadedBytes = 0
Settings.DownloadedFiles = 0
function downloadBlob(v)
	if isBlacklisted(Settings.InstallPath..v.path) then
		return
	end
	if v.type == 'tree' then
		-- subTitle = 'Making folder: '..'/'..Settings.InstallPath..v.path
		Draw()
		fs.makeDir('/'..Settings.InstallPath..v.path)
	else
		-- subTitle = 'Starting download for: '..Settings.InstallPath..v.path
		Draw()

        local tries, f = 0
        repeat 
			f = http.get(('https://raw.github.com/'..Settings.GitHubUsername..'/'..Settings.GitHubRepoName..'/'..latestReleaseTag..Settings.InstallPath..v.path):gsub(' ','%%20'))
                if not f then sleep(5) end
                tries = tries + 1
        until tries > 5 or f

		if not f then
			error('Downloading failed, try again. '..('https://raw.github.com/'..Settings.GitHubUsername..'/'..Settings.GitHubRepoName..'/'..latestReleaseTag..Settings.InstallPath..v.path):gsub(' ','%%20'))
		end

		local h = fs.open('/'..Settings.InstallPath..v.path, 'w')
		h.write(f.readAll())
		h.close()
		-- subTitle = 'Downloading: ' .. math.floor(100*(Settings.DownloadedBytes/Settings.TotalBytes))..'%'
		subTitle = 'Downloading: ' .. math.floor(100*(Settings.DownloadedFiles/Settings.TotalFiles))..'%' -- using the number of files over the number of bytes actually appears to be more accurate, the connection takes longer than sending the data
		-- subTitle = '('..math.floor(100*(Settings.DownloadedBytes/Settings.TotalBytes))..'%) Downloaded: '..Settings.InstallPath..v.path
		Draw()
		if v.size then
			Settings.DownloadedBytes = Settings.DownloadedBytes + v.size
			Settings.DownloadedFiles = Settings.DownloadedFiles + 1
		end
	end
end

local connectionLimit = 5
local downloads = {}
for i, v in ipairs(tree) do
	local queueNumber = math.ceil(i / connectionLimit)
	if not downloads[queueNumber] then
		downloads[queueNumber] = {}
	end
	table.insert(downloads[queueNumber], function()
		downloadBlob(v)
	end)
end

for i, queue in ipairs(downloads) do
	parallel.waitForAll(unpack(queue))
end

local h = fs.open('/System/.version', 'w')
h.write(latestReleaseTag)
h.close()

mainTitle = 'Installation Complete!'
subTitle = 'Rebooting in 1 second...'
Draw()
sleep(1)
os.reboot()
