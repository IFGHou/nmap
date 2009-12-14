---
-- This module was written by Patrik Karlsson and facilitates communication
-- with the Citrix XML Service. It is not feature complete and is missing several 
-- functions and parameters. 
--
-- The library makes little or no effort to verify that the parameters submitted
-- to each function are compliant with the DTD
--
-- As all functions handling requests take their parameters in the form of tables,
-- additional functionality can be added while not breaking existing scripts
--
-- Details regarding the requests/responses and their parameters can be found in
-- the NFuse.DTD included with Citrix MetaFrame/Xenapp
--
-- This code is based on the information available in: 
-- NFuse.DTD - Version 5.0 (draft 1)   24 January 2008
--


require 'http'

module(... or "citrix",package.seeall)

--- Decodes html-entities to chars eg. &#32; => <space>
-- 
-- @param str string to convert
-- @return string an e
function decode_xml_document(xmldata)
	
	local hexval
	
	if not xmldata then
		return ""
	end
	
	local newstr = xmldata
	
	for m in xmldata:gmatch("(\&\#%d+;)") do
		hexval = m:match("(%d+)")
		
		if ( hexval ) then
			newstr = xmldata:gsub(m, string.char(hexval))
		end
	end
	
	return newstr
	
end

--- Sends the request to the server using the http lib
-- 
-- NOTE: 
--   At the time of the development (20091128) the http
--   lib does not properly handle text/xml content. It also doesn't 
--   handle HTTP 100 Continue properly. Workarounds are in place, 
--   please consult comments.
--
-- @param host string, the ip of the remote server
-- @param port number, the port of the remote server
-- @param xmldata string, the HTTP data part of the request as XML
--
-- @return string with the response body
--
function send_citrix_xml_request(host, port, xmldata)	

	local header = "POST /scripts/WPnBr.dll HTTP/1.1\r\n"
	  	  header = header .. "Content-type: text/xml\r\n"
	  	  header = header .. "Host: " .. host .. ":" .. port .. "\r\n"
  		  header = header .. "Content-Length: " .. xmldata:len() .. "\r\n"
	      header = header .. "Connection: Close\r\n"
	  	  header = header .. "\r\n"

	local request = header .. xmldata
	
	-- this would have been really great! Unfortunately buildPost substitutes all spaces for plus'
	-- this ain't all great when the content-type is text/xml
	-- local response = http.post( host, port, "/scripts/WPnBr.dll", { header={["Content-Type"]="text/xml"}}, nil, xmldata)

	-- let's build the content ourselves and let the http module do the rest
	local response = http.request(host, port, request)
 	local parse_options = {method="post"}

	-- we need to handle another bug within the http module
	-- it doesn't seem to recognize the HTTP/100 Continue correctly
	-- So, we need to chop that part of from the response
  	if response and response:match("^HTTP/1.1 100 Continue") and response:match( "\r?\n\r?\n" ) then
		response = response:match( "\r?\n\r?\n(.*)$" )
  	end 
	
	-- time for next workaround
	-- The Citrix XML Service returns the header Transfer-Coding, rather than Transfer-Encoding
	-- Needless to say, this screws things up for the http library
	if response and response:match("Transfer[-]Coding") then
		response = response:gsub("Transfer[-]Coding", "Transfer-Encoding")
	end	
	
 	local response = http.parseResult(response, parse_options)

	-- this is *probably* not the right way to do stuff
	-- decoding should *probably* only be done on XML-values
	-- this is *probably* defined in the standard, for anyone interested
	return decode_xml_document(response.body)
	
end

--- Request information about the Citrix Server Farm
--
-- Consult the NFuse.DTD for a complete list of supported parameters
-- This function implements all the supported parameters described in: 
-- Version 5.0 (draft 1)   24 January 2008
--
-- @param socket socket, connected to the remote web server
-- @return string HTTP response data
--
function request_server_farm_data( host, port )

	local xmldata = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\r\n"
	  	  xmldata = xmldata .. "<!DOCTYPE NFuseProtocol SYSTEM \"NFuse.dtd\">\r\n"
		  xmldata = xmldata .. "<NFuseProtocol version=\"1.1\">"
		  xmldata = xmldata .. "<RequestServerFarmData></RequestServerFarmData>"
		  xmldata = xmldata .. "</NFuseProtocol>\r\n"
		
	return send_citrix_xml_request(host, port, xmldata)
end

--- Parses the response from the request_server_farm_data request
-- @param response string with the XML response
-- @return table containing server farm names
--
function parse_server_farm_data_response( response )

	local farms = {}
	
	response = response:gsub("\r?\n","")
	for farm in response:gmatch("<ServerFarmName.->([^\<]+)</ServerFarmName>") do
		table.insert(farms, farm)
	end
		
	return farms
	
end

--- Sends a request for application data to the Citrix XML service
--
-- Consult the NFuse.DTD for a complete list of supported parameters
-- This function does NOT implement all the supported parameters
--
-- Supported parameters are Scope, ServerType, ClientType, DesiredDetails
--
-- @param host string the host which is to be queried
-- @param port number the port number of the XML service
-- @param params table with parameters
-- @return string HTTP response data
--
function request_appdata(host, port, params)

	-- setup the mandatory parameters if they're missing
	local scope = params['Scope'] or "onelevel"
	local server_type = params['ServerType'] or "all"
	local client_type = params['ClientType'] or "ica30"
	local desired_details = params['DesiredDetails'] or nil

	local xmldata = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\r\n"
	  	  xmldata = xmldata .. "<!DOCTYPE NFuseProtocol SYSTEM \"NFuse.dtd\">\r\n"
		  xmldata = xmldata .. "<NFuseProtocol version=\"5.0\">"
		  xmldata = xmldata .. "<RequestAppData>"
		  xmldata = xmldata .. "<Scope traverse=\"" .. scope .. "\" />"
		  xmldata = xmldata .. "<ServerType>" .. server_type .. "</ServerType>"
		  xmldata = xmldata .. "<ClientType>" .. client_type .. "</ClientType>"

		  if desired_details then
			if type(desired_details) == "string" then
		  		xmldata = xmldata .. "<DesiredDetails>" .. desired_details .. "</DesiredDetails>" 
			elseif type(desired_details) == "table" then
				for _, v in ipairs(desired_details) do
			  		xmldata = xmldata .. "<DesiredDetails>" .. v .. "</DesiredDetails>" 					
				end
			else
				assert(desired_details)
			end
			
		  end

		  xmldata = xmldata .. "</RequestAppData>"
		  xmldata = xmldata .. "</NFuseProtocol>\r\n"
		
	return send_citrix_xml_request(host, port, xmldata)
end


--- Extracts the Accesslist section of the XML response
--
-- @param xmldata string containing results from the request app data request
-- @return table containing settings extracted from the accesslist section of the response
local function extract_appdata_acls(xmldata)

	local acls = {}
	local users = {}
	local groups = {}

	for acl in xmldata:gmatch("<AccessList>(.-)</AccessList>") do

		if acl:match("AnonymousUser") then
			table.insert(users, "Anonymous")
		else

			for user in acl:gmatch("<User>(.-)</User>") do
				local user_name = user:match("<UserName.->(.-)</UserName>") or ""
				local domain_name = user:match("<Domain.->(.-)</Domain>") or ""
			
				if user_name:len() > 0 then
					if domain_name:len() > 0 then
						domain_name = domain_name .. "\\"
					end
					table.insert(users, domain_name .. user_name)
				end
				
			end
			
			for group in acl:gmatch("<Group>(.-)</Group>") do
				

				local group_name = group:match("<GroupName.->(.-)</GroupName>") or ""
				local domain_name = group:match("<Domain.->(.-)</Domain>") or "" 
			
				if group_name:len() > 0 then
					if domain_name:len() > 0 then
						domain_name = domain_name .. "\\"
					end
					table.insert(groups, domain_name .. group_name)	
				end
							
			end
			
		end 

		if #users> 0 then
			acls['User'] = users
		end
		if #groups>0 then
			acls['Group'] = groups
		end
		
	end

	return acls

end


--- Extracts the settings section of the XML response
-- 
-- @param xmldata string containing results from the request app data request
-- @return table containing settings extracted from the settings section of the response
local function extract_appdata_settings(xmldata)

	local settings = {}

	settings['appisdisabled'] = xmldata:match("<Settings.-appisdisabled=\"(.-)\".->")
	settings['appisdesktop'] = xmldata:match("<Settings.-appisdesktop=\"(.-)\".->")	

	for s in xmldata:gmatch("<Settings.->(.-)</Settings>") do
		settings['Encryption'] = s:match("<Encryption.->(.-)</Encryption>")
		settings['AppOnDesktop'] = s:match("<AppOnDesktop.-value=\"(.-)\"/>")
		settings['AppInStartmenu'] = s:match("<AppInStartmenu.-value=\"(.-)\"/>")
		settings['PublisherName'] = s:match("<PublisherName.->(.-)</PublisherName>")
		settings['SSLEnabled'] = s:match("<SSLEnabled.->(.-)</SSLEnabled>")
		settings['RemoteAccessEnabled'] = s:match("<RemoteAccessEnabled.->(.-)</RemoteAccessEnabled>")
	end

	return settings
	
end

--- Parses the appdata XML response
--
-- @param xmldata string response from request_appdata
-- @return table containing nestled tables closely resembling the DOM model of the XML response
function parse_appdata_response(xmldata)

	local apps = {}
	xmldata = xmldata:gsub("\r?\n",""):gsub(">%s+<", "><")
		
	for AppData in xmldata:gmatch("<AppData>(.-)</AppData>") do

		local app_name = AppData:match("<FName.->(.-)</FName>") or ""	
		local app = {}
		
		app['FName'] = app_name
		app['AccessList'] = extract_appdata_acls(AppData)
		app['Settings'] = extract_appdata_settings(AppData)

		table.insert(apps, app)
		
	end
	
	return apps	
end

--
--
-- @param flags string, should be any of following: alt-addr, no-load-bias
--
function request_address(host, port, flags, appname)

		local xmldata = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\r\n"
		  	  xmldata = xmldata .. "<!DOCTYPE NFuseProtocol SYSTEM \"NFuse.dtd\">\r\n"
			  xmldata = xmldata .. "<NFuseProtocol version=\"4.1\">"
			  xmldata = xmldata .. "<RequestAddress>"

		if flags then
			  xmldata = xmldata .. "<Flags>" .. flags .. "</Flags>"
		end
			
		if appname then
			  xmldata = xmldata .. "<Name>"
			  xmldata = xmldata .. "<AppName>" .. appname .. "</AppName>"
			  xmldata = xmldata .. "</Name>"
		end
		
			  xmldata = xmldata .. "</RequestAddress>"
			  xmldata = xmldata .. "</NFuseProtocol>\r\n"

		return send_citrix_xml_request(host, port, xmldata)
end

--- Request information about the Citrix protocol
--
-- Consult the NFuse.DTD for a complete list of supported parameters
-- This function implements all the supported parameters described in: 
-- Version 5.0 (draft 1)   24 January 2008
--
-- @param host string the host which is to be queried
-- @param port number the port number of the XML service
-- @param params table with parameters
-- @return string HTTP response data
--
function request_server_data(host, port, params)
		
			local params = params or {}
			local server_type = params.ServerType or {"all"}
			local client_type = params.ClientType or {"all"}
			
			local xmldata = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\r\n"
			  	  xmldata = xmldata .. "<!DOCTYPE NFuseProtocol SYSTEM \"NFuse.dtd\">\r\n"
				  xmldata = xmldata .. "<NFuseProtocol version=\"1.1\">"
				  xmldata = xmldata .. "<RequestServerData>"
				
			for _, srvtype in pairs(server_type) do
				  xmldata = xmldata .. "<ServerType>" .. srvtype .. "</ServerType>"
			end
			
			for _, clitype in pairs(client_type) do
				  xmldata = xmldata .. "<ClientType>" .. clitype .. "</ClientType>"
			end
	
				  xmldata = xmldata .. "</RequestServerData>"
				  xmldata = xmldata .. "</NFuseProtocol>\r\n"

			return send_citrix_xml_request(host, port, xmldata)
end

--- Parses the response from the request_server_data request
-- @param response string with the XML response
-- @return table containing the server names
--
function parse_server_data_response(response)

	local servers = {}
	
	response = response:gsub("\r?\n","")	
	for s in response:gmatch("<ServerName>([^\<]+)</ServerName>") do
		table.insert(servers, s)
	end
		
	return servers
	
end

--- Request information about the Citrix protocol
--
-- Consult the NFuse.DTD for a complete list of supported parameters
-- This function implements all the supported parameters described in: 
-- Version 5.0 (draft 1)   24 January 2008
--
-- @param host string the host which is to be queried
-- @param port number the port number of the XML service
-- @param params table with parameters
-- @return string HTTP response data
--
function request_protocol_info( host, port, params )

	local params = params or {}

	local xmldata = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\r\n"
	  	  xmldata = xmldata .. "<!DOCTYPE NFuseProtocol SYSTEM \"NFuse.dtd\">\r\n"
		  xmldata = xmldata .. "<NFuseProtocol version=\"1.1\">"
		  xmldata = xmldata .. "<RequestProtocolInfo>"
			
	if params['ServerAddress'] then
		  xmldata = xmldata .. "<ServerAddress addresstype=\"" .. params['ServerAddress']['attr']['addresstype'] .. "\">"
		  xmldata = xmldata .. params['ServerAddress'] .. "</ServerAddress>"
	end

		  xmldata = xmldata .. "</RequestProtocolInfo>"
		  xmldata = xmldata .. "</NFuseProtocol>\r\n"
		
	return send_citrix_xml_request(host, port, xmldata)
end

--- Request capability information 
--
-- Consult the NFuse.DTD for a complete list of supported parameters
-- This function implements all the supported parameters described in: 
-- Version 5.0 (draft 1)   24 January 2008
--
-- @param host string the host which is to be queried
-- @param port number the port number of the XML service
-- @param params table with parameters
-- @return string HTTP response data
--
function request_capabilities( host, port )

	local xmldata = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\r\n"
	  	  xmldata = xmldata .. "<!DOCTYPE NFuseProtocol SYSTEM \"NFuse.dtd\">\r\n"
		  xmldata = xmldata .. "<NFuseProtocol version=\"1.1\">"
		  xmldata = xmldata .. "<RequestCapabilities>"
		  xmldata = xmldata .. "</RequestCapabilities>"
		  xmldata = xmldata .. "</NFuseProtocol>\r\n"
		
	return send_citrix_xml_request(host, port, xmldata)
end

--- Parses the response from the request_capabilities request
-- @param response string with the XML response
-- @return table containing the server capabilities
--
function parse_capabilities_response(response)

	local servers = {}
	
	response = response:gsub("\r?\n","")	
	for s in response:gmatch("<CapabilityId.->([^\<]+)</CapabilityId>") do
		table.insert(servers, s)
	end
		
	return servers
	
end

--- Tries to validate user credentials against the XML service
--
-- Consult the NFuse.DTD for a complete list of supported parameters
-- This function implements all the supported parameters described in: 
-- Version 5.0 (draft 1)   24 January 2008
--
--
-- @param host string the host which is to be queried
-- @param port number the port number of the XML service
-- @param params table with parameters
-- @return string HTTP response data
--
function request_validate_credentials(host, port, params )

	local params = params or {}
	local credentials = params['Credentials'] or {}

	local xmldata = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\r\n"
	  	  xmldata = xmldata .. "<!DOCTYPE NFuseProtocol SYSTEM \"NFuse.dtd\">\r\n"
		  xmldata = xmldata .. "<NFuseProtocol version=\"5.0\">"
		  xmldata = xmldata .. "<RequestValidateCredentials>"
		  xmldata = xmldata .. "<Credentials>"
		  
	if credentials['UserName'] then
		  xmldata = xmldata .. "<UserName>" .. credentials['UserName'] .. "</UserName>"
	end

	if credentials['Password'] then
		  xmldata = xmldata .. "<Password encoding=\"cleartext\">" .. credentials['Password'] .. "</Password>"
	end
		
	if credentials['Domain'] then
		  xmldata = xmldata .. "<Domain type=\"NT\">" .. credentials['Domain'] .. "</Domain>"
	end
				
		  xmldata = xmldata .. "</Credentials>"
		  xmldata = xmldata .. "</RequestValidateCredentials>"
		  xmldata = xmldata .. "</NFuseProtocol>\r\n"
		
	return send_citrix_xml_request(host, port, xmldata)
	
end


--- Parses the response from request_validate_credentials
-- @param response string with the XML response
-- @return table containing the results
--
function parse_validate_credentials_response(response)
	local tblResult = {}
	
	response = response:gsub("\r?\n","")	
	tblResult['DaysUntilPasswordExpiry'] = response:match("<DaysUntilPasswordExpiry>(.+)</DaysUntilPasswordExpiry>")
	tblResult['ShowPasswordExpiryWarning'] = response:match("<ShowPasswordExpiryWarning>(.+)</ShowPasswordExpiryWarning>")
	tblResult['ErrorId'] = response:match("<ErrorId>(.+)</ErrorId>")
	
	return tblResult
	
end

--- Sends a request to reconnect session data
--
-- Consult the NFuse.DTD for a complete list of supported parameters
-- This function does NOT implement all the supported parameters
----
-- @param host string the host which is to be queried
-- @param port number the port number of the XML service
-- @param params table with parameters
--
function request_reconnect_session_data(host, port, params)

	local params = params or {}
	local Credentials = params.Credentials or {}
	
	params.ServerType = params.ServerType or {}
	params.ClientType = params.ClientType or {}

	local xmldata = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\r\n"
	  	  xmldata = xmldata .. "<!DOCTYPE NFuseProtocol SYSTEM \"NFuse.dtd\">\r\n"
		  xmldata = xmldata .. "<NFuseProtocol version=\"5.0\">"
		  xmldata = xmldata .. "<RequestReconnectSessionData>"

		  xmldata = xmldata .. "<Credentials>"
		  
	if Credentials.UserName then
		  xmldata = xmldata .. "<UserName>" .. Credentials.UserName .. "</UserName>"
	end

	if Credentials.Password then
		  xmldata = xmldata .. "<Password encoding=\"cleartext\">" .. Credentials.Password .. "</Password>"
	end
		
	if Credentials.Domain then
		  xmldata = xmldata .. "<Domain type=\"NT\">" .. Credentials.Domain .. "</Domain>"
	end
				
		  xmldata = xmldata .. "</Credentials>"

	if params.ClientName then
		  xmldata = xmldata .. "<ClientName>" .. params.ClientName .. "</ClientName>"
	end

	if params.DeviceId then
		  xmldata = xmldata	.. "<DeviceId>" .. params.DeviceId .. "</DeviceId>"
	end
	
	for _, srvtype in pairs(params.ServerType) do
		  xmldata = xmldata .. "<ServerType>" .. srvtype .. "</ServerType>"
	end
	
	for _, clitype in pairs(params.ClientType) do
		  xmldata = xmldata .. "<ClientType>" .. clitype .. "</ClientType>"
	end

		  xmldata = xmldata .. "</RequestReconnectSessionData>"
		  xmldata = xmldata .. "</NFuseProtocol>\r\n"
		
	return send_citrix_xml_request(host, port, xmldata)
	
	
end
