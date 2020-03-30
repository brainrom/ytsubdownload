-- start of VLC required functions


currVid=nil

languagesList_string="ru, en, ja"
languagesList={}

conffile_path=nil


-- VLC Extension Descriptor
function descriptor()
	return {
				title = "YT Subtitles Downloader",
				version = "0.1",
				author = "kokokoshka",
				url = 'n/a',
				description = "",
				shortdesc = "YTSubDownload",
				capabilities = { "input-listener"; "meta-listener" }
			}
end

-- Function triggered when the extension is activated
function activate()
	--vlc.msg.dbg(_VERSION)
	vlc.msg.dbg("[YTSubDownload] Activated")

	conffile_path=vlc.config.userdatadir().."/lua/extensions/userdata/ytsubdownload.conf"

	local conffile=io.open(conffile_path, 'r')
	if conffile then
		languagesList_string=conffile:read("*a")
		conffile:close()
		vlc.msg.dbg("[YTSubDownload] Config read!")
	end


	i=1
	languagesList={}
	for lang in string.gmatch(languagesList_string, '([^,]+)') do
    	languagesList[i]=lang:gsub("%s+", "")
    	i=i+1
	end


	if vlc.input.item() then
		local item = vlc.input.item()

		if string.match(item:uri(), "googlevideo.com/videoplayback") then
			meta_changed()
		end
	else
		show_dialog()
	end
	return true

end

-- Function triggered when the extension is deactivated
function deactivate()
	close()
	vlc.msg.dbg("[YTSubDownload] Deactivated")
	return true
end

function new_dialog(title)
	dlg=vlc.dialog(title)
end

-- Function triggered when the dialog is closed
function close()
	dlg:delete()
	--reset_variables()
	--vlc.deactivate()
end

function save()
	languagesList_stringnew=languagesList_textinput:get_text()


		i=1
		languagesList={}
		for lang in string.gmatch(languagesList_stringnew, '([^,]+)') do
	    	languagesList[i]=lang:gsub("%s+", "")
	    	i=i+1
		end
	if languagesList_stringnew ~= languagesList_string then
		local conffile=io.open(conffile_path, 'w')
		conffile:write(languagesList_stringnew)
		conffile:close()
		languagesList_string=languagesList_stringnew
	end
	dlg:delete()
end

function show_dialog()
	if dlg == nil then
		new_dialog("YTSubDownload")
	end

	-- column, row, col_span, row_span, width, height

	dlg:add_label("Language list:", 1, 1, 1, 1)
	languagesList_textinput = dlg:add_text_input(languagesList_string, 2, 1, 3, 1)

	--dlg:add_label("Default language:", 1, 2, 1, 1)
	--defatulLanguage_textinput = dlg:add_text_input("ru", 2, 2, 3, 1)
	
	dlg:add_button("Save settings", save, 1, 2, 1, 1)
	--dlg:add_button("Get Lyrics", click_lyrics_button, 2, 3, 2, 1)
	dlg:add_button("Close", close, 2, 2, 1, 1)
	return true
end

-- Resets Dialog




function safeToNumber(strnum)
	intpart, floatpart=string.match(strnum,"(%d+)%D(%d+)")
	if floatpart==nil then
	return tonumber(strnum)
else
	return tonumber(intpart)+tonumber(floatpart)/(10^(string.len(floatpart)))
end
end


function SecondsToClock(seconds)
  --local seconds = safeToNumber(seconds_str)
  if seconds <= 0 then
    return "00:00:00";
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
    return hours..":"..mins..":"..secs..""
  end
end


function parseSubs(data)
ret=""
local i=1;
for start, dur, text in string.gmatch(
    data,
    "<text start=\"(%S+)\" dur=\"(%S+)\">(%D+)</text>")
  do
  	ret=ret ..i.."\n"
  	ret=ret .. SecondsToClock(safeToNumber(start)).." --> "..SecondsToClock(safeToNumber(start)+safeToNumber(dur)) .. "\n"
  	ret=ret .. text .. "\n\n"
  	i=i+1
end
return ret
end


function addYtSubs(vid, lang, isDefault)
	local xmlSubs=get("video.google.com","/timedtext?lang="..lang.."&v="..vid)
	if string.match(xmlSubs, "transcript") then --If subtitles exist
	local subfile = io.open("/tmp/ytsub_"..lang..".srt", "w")
	local srtSubs=parseSubs(xmlSubs)
	vlc.msg.dbg(srtSubs)
	subfile:write(srtSubs)
	subfile:flush()
	subfile:close()
	vlc.input.add_subtitle("/tmp/ytsub_"..lang..".srt", isDefault)
	return true --If subtitles downloaded
else
	return false --If no success to download
end
end


function meta_changed()

vlc.msg.dbg("videoplayback: META CHANGED")

local vid="";

if vlc.input.item() then
	local item = vlc.input.item()

	if string.match(item:uri(), "googlevideo.com/videoplayback") then
		vid=string.match(item:metas().url, "?v=(.+)")
		if vid==currVid then
			return false
		end

		local isDefaultSelected = false

		for languagesListCount = 1, #languagesList do
			vlc.msg.dbg("[YTSubDownload] "..languagesList[languagesListCount])
			if isDefaultSelected==false then
				isDefaultSelected=addYtSubs(vid, languagesList[languagesListCount], true)
				vlc.msg.dbg("[YTSubDownload] Selected default language:"..languagesList[languagesListCount])
			else
				addYtSubs(vid, languagesList[languagesListCount], false)
			end
		end

		currVid=vid;
		vlc.msg.dbg("videoplayback subtitles added")
		return false
	else 
		currVid=nil
	end
end
end


-- end of VLC functions




--http stuff
function get(host,path)
  --local host, path = parse_url(url)
  local header = {
    "GET "..path.." HTTP/1.1", 
    "Host: "..host, 
    "",
    ""
  }
  local request = table.concat(header, "\r\n")

  local status, response = http_req(host, 80, request)
  
  if status == 200 then 
    return response
  else
    vlc.msg.err("[VLSub] HTTP "..tostring(status).." : "..response)
    return false
  end
end

function http_req(host, port, request)
	local fd = vlc.net.connect_tcp(host, port)
	if not fd then 
		setError("Unable to connect to server")
		return nil, "" 
	end
	local pollfds = {}
	
	pollfds[fd] = vlc.net.POLLIN
	vlc.net.send(fd, request)
	vlc.net.poll(pollfds)

	local response = vlc.net.recv(fd, 2048)
	local buf = ""
	local headerStr, header, body
	local contentLength, status, TransferEncoding, chunked
	local pct = 0
	
	while response and #response>0 do
		buf = buf..response
		
		if not header then
			headerStr, body = buf:match("(.-\r?\n)\r?\n(.*)")

			if headerStr then
				header = parse_header(headerStr);
				status = tonumber(header["statuscode"]);
				contentLength = tonumber(header["Content-Length"]);
				if not contentLength then
					contentLength = tonumber(header["X-Uncompressed-Content-Length"])
				end
				
				TransferEncoding = trim(header["Transfer-Encoding"]);
				chunked = (TransferEncoding=="chunked");
				
				buf = body;
				body = "";
			end
		end
		
		if chunked then
			chunk_size_hex, chunk_content = buf:match("(%x+)\r?\n(.*)")
			chunk_size = tonumber(chunk_size_hex,16)
			chunk_content_len = chunk_content:len()
			chunk_remaining = chunk_size-chunk_content_len

			while chunk_content_len > chunk_size do
				body = body..chunk_content:sub(0, chunk_size)
				buf = chunk_content:sub(chunk_size+2)
				
				chunk_size_hex, chunk_content = buf:match("(%x+)\r?\n(.*)")
				
				if not chunk_size_hex 
				or chunk_size_hex == "0" then
					chunk_size = 0
					break
				end
				
				chunk_size = tonumber(chunk_size_hex,16)
				chunk_content_len = chunk_content:len()
				chunk_remaining = chunk_size-chunk_content_len
			end
			
			if chunk_size == 0 then
				break
			end
		end

		if contentLength then
      if #body == 0 then
        bodyLength = #buf
      else
        bodyLength = #body
      end
      
			pct = bodyLength / contentLength * 100
			--setMessage(openSub.actionLabel..": "..progressBarContent(pct))
			if bodyLength >= contentLength then
				break
			end
		end

		vlc.net.poll(pollfds)
		response = vlc.net.recv(fd, 1024)
	end
	
	if not chunked then
		body = buf
	end
	
	if status == 301 
	and header["Location"] then
		local host, path = parse_url(trim(header["Location"]))
		request = request
		:gsub("^([^%s]+ )([^%s]+)", "%1"..path)
		:gsub("(Host: )([^\n]*)", "%1"..host)

		return http_req(host, port, request)
	end

	return status, body
end

function parse_header(data)
  local header = {}
  
  for name, s, val in string.gmatch(
    data,
    "([^%s:]+)(:?)%s([^\n]+)\r?\n")
  do
    if s == "" then 
    header['statuscode'] = tonumber(string.sub(val, 1 , 3))
    else 
      header[name] = val
    end
  end
  return header
end 

function parse_url(url)
  local url_parsed = vlc.net.url_parse(url)
  return  url_parsed["host"], 
    url_parsed["path"],
    url_parsed["option"]
end

function trim(str)
  if not str then return "" end
  return string.gsub(str, "^[\r\n%s]*(.-)[\r\n%s]*$", "%1")
end

--end of http stuff
