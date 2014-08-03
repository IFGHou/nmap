--- A tiny implementation of the Netware Core Protocol (NCP).
-- While NCP was originally a Netware only protocol it's now present on
-- both Linux and Windows platforms running Novell eDirectory.
--
-- The library implements a small amount of NCP functions based on various
-- packet dumps generated by Novell software, such as the Novell Client and
-- Console One. The functions are mainly used for enumeration and discovery
--
-- The library implements a number of different classes where the Helper is
-- the one that should be the easiest to use from scripts.
--
-- The following classes exist:
--
-- * Packet
--    - Implements functions for creating and serializing a NCP packet
--
-- * ResponseParser
--    - A static class containing a bunch of functions to decode server
--      responses
--
-- * Response
--    - Class responsible for decoding NCP responses
--
-- * NCP
--    - Contains the "native" NCP functions sending the actual request to the
--      server.
--
-- * Helper
--    - The preferred script interface to the library containing functions
--      that wrap functions from the NCP class using more descriptive names
--      and easier interface.
--
-- * Util
--    - A class containing mostly decoding and helper functions
--
-- The following example code illustrates how to use the Helper class from a
-- script. The example queries the server for all User objects from the root.
--
-- <code>
--  local helper = ncp.Helper:new(host,port)
--  local status, resp = helper:connect()
--  status, resp = helper:search("[Root]", "User", "*")
--  status = helper:close()
-- </code>
--

--@author Patrik Karlsson <patrik@cqure.net>
--@copyright Same as Nmap--See http://nmap.org/book/man-legal.html

-- Version 0.1
-- Created 24/04/2011 - v0.1 - created by Patrik Karlsson <patrik@cqure.net>

local bin = require "bin"
local bit = require "bit"
local ipOps = require "ipOps"
local match = require "match"
local nmap = require "nmap"
local stdnse = require "stdnse"
local string = require "string"
local table = require "table"
_ENV = stdnse.module("ncp", stdnse.seeall)


NCPType = {
  CreateConnection = 0x1111,
  ServiceRequest = 0x2222,
  ServiceReply = 0x3333,
  DestroyConnection = 0x5555,
}

Status = {
  CONNECTION_OK = 0,
  COMPLETION_OK = 0,
}

NCPFunction = {
  GetMountVolumeList = 0x16,
  GetFileServerInfo = 0x17,
  Ping = 0x68,
  EnumerateNetworkAddress = 0x7b,
  SendFragmentedRequest = 0x68,
}

NCPVerb = {
  Resolve = 1,
  List = 5,
  Search = 6,
}

-- The NCP Packet
Packet = {

  --- Creates a new instance of Packet
  -- @return o instance of Packet
  new = function(self)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.ncp_ip = { signature = "DmdT", replybuf = 0, version = 1 }
    o.task = 1
    o.func = 0
    return o
  end,

  --- Sets the NCP Reply buffer size
  -- @param n number containing the buffer size
  setNCPReplyBuf = function(self, n) self.ncp_ip.replybuf = n end,

  --- Sets the NCP packet length
  -- @param n number containing the length
  setNCPLength = function(self, n) self.ncp_ip.length = n end,

  --- Gets the NCP packet length
  -- @return n number containing the NCP length
  getNCPLength = function(self) return self.ncp_ip.length end,

  --- Sets the NCP packet type
  -- @param t number containing the NCP packet type
  setType = function(self, t) self.type = t end,

  --- Gets the NCP packet type
  -- @return type number containing the NCP packet type
  getType = function(self) return self.type end,

  --- Sets the NCP packet function
  -- @param t number containing the NCP function
  setFunc = function(self, f) self.func = f end,

  --- Gets the NCP packet function
  -- @return func number containing the NCP packet function
  getFunc = function(self) return self.func end,

  --- Sets the NCP sequence number
  -- @param seqno number containing the sequence number
  setSeqNo = function(self, n) self.seqno = n end,

  --- Sets the NCP connection number
  -- @param conn number containing the connection number
  setConnNo = function(self, n) self.conn = n end,

  --- Gets the NCP connection number
  -- @return conn number containing the connection number
  getConnNo = function(self) return self.conn end,

  --- Sets the NCP sub function
  -- @param subfunc number containing the subfunction
  setSubFunc = function(self, n) self.subfunc = n end,

  --- Gets the NCP sub function
  -- @return subfunc number containing the subfunction
  getSubFunc = function(self) return self.subfunc end,

  --- Gets the Sequence number
  -- @return seqno number containing the sequence number
  getSeqNo = function(self) return self.seqno end,

  --- Sets the packet length
  -- @param len number containing the packet length
  setLength = function(self, n) self.length = n end,

  --- Sets the packet data
  -- @param data string containing the packet data
  setData = function(self, data) self.data = data end,

  --- Gets the packet data
  -- @return data string containing the packet data
  getData = function(self) return self.data end,

  --- Sets the packet task
  -- @param task number containing the packet number
  setTask = function(self, task) self.task = task end,

  --- "Serializes" the packet to a string
  __tostring = function(self)
    local UNKNOWN = 0
    local data = bin.pack(">AIIISCCCCC", self.ncp_ip.signature,
      self.ncp_ip.length or 0, self.ncp_ip.version,
      self.ncp_ip.replybuf, self.type, self.seqno,
      self.conn, self.task, UNKNOWN, self.func )

    if ( self.length ) then data = data .. bin.pack(">S", self.length) end
    if ( self.subfunc ) then data = data .. bin.pack("C", self.subfunc) end
    if ( self.data ) then data = data .. bin.pack("A", self.data) end

    return data
  end,

}

-- Parses different responses into suitable tables
ResponseParser = {

  --- Determines what parser to call based on the contents of the client
  -- request and server response.
  -- @param req instance of Packet containing the request to the server
  -- @param resp instance of Response containing the server response
  -- @return status true on success, false on failure
  -- @return resp table (on success) containing the decoded response
  -- @return err string (on failure) containing the error message
  parse = function(req, resp)
    local func, subfunc, typ = req:getFunc(), req:getSubFunc(), req:getType()

    if ( ResponseParser[func] ) then
      return ResponseParser[func](resp)
    elseif ( NCPFunction.SendFragmentedRequest == func ) then
      if ( 1 == subfunc ) then
        return ResponseParser.Ping(resp)
      elseif ( 2 == subfunc ) then
        local data = req:getData()
        if ( #data < 21 ) then
          return false, "Invalid NCP request, could not parse"
        end
        local pos, verb = bin.unpack("<I", data, 17)

        if ( NCPVerb.Resolve == verb ) then
          return ResponseParser.Resolve(resp)
        elseif ( NCPVerb.List == verb ) then
          return ResponseParser.List(resp)
        elseif ( NCPVerb.Search == verb ) then
          return ResponseParser.Search(resp)
        end
        return false, "ResponseParser: Failed to parse response"
      end
    end

    return false, "ResponseParser: Failed to parse response"
  end,

  --- Decodes a GetFileServerInfo response
  -- @param resp string containing the response as received from the server
  -- @return status true on success, false on failure
  -- @return response table (if status is true) containing:
  --         <code>srvname</code>
  --         <code>os_major</code>
  --         <code>os_minor</code>
  --         <code>conns_supported</code>
  --         <code>conns_inuse</code>
  --         <code>vols_supported</code>
  --         <code>os_rev</code>
  --         <code>sft_support</code>
  --         <code>tts_level</code>
  --         <code>conns_max_use</code>
  --         <code>acct_version</code>
  --         <code>vap_version</code>
  --         <code>qms_version</code>
  --         <code>print_version</code>
  --         <code>internet_bridge_ver</code>
  --         <code>mixed_mode_path</code>
  --         <code>local_login_info</code>
  --         <code>product_major</code>
  --         <code>product_minor</code>
  --         <code>product_rev</code>
  --         <code>os_lang_id</code>
  --         <code>support_64_bit</code>
  -- @return error message (if status is false)
  [NCPFunction.GetFileServerInfo] = function(resp)
    local data = resp:getData()
    local len = #data

    if ( len < 78 ) then
      return false, "Failed to decode GetFileServerInfo"
    end

    local result = {}
    local pos

    pos, result.srvname, result.os_major, result.os_minor,
      result.conns_supported, result.conns_inuse,
      result.vols_supported, result.os_rev, result.sft_support,
      result.tts_level, result.conns_max_use, result.acct_version,
      result.vap_version, result.qms_version, result.print_version,
      result.virt_console_ver, result.sec_restrict_ver,
      result.internet_bridge_ver, result.mixed_mode_path,
      result.local_login_info, result.product_major,
      result.product_minor, result.product_rev, result.os_lang_id,
      result.support_64_bit = bin.unpack(">A48CCSSSCCCSCCCCCCCCCSSSCC", data)

    return true, result
  end,

  --- Decodes a GetMountVolumeList response
  -- @param resp string containing the response as received from the server
  -- @return status true on success, false on failure
  -- @return response table of vol entries (if status is true)
  --         Each vol entry is a table containing the following fields:
  --         <code>vol_no</code> and <code>vol_name</code>
  -- @return error message (if status is false)
  [NCPFunction.GetMountVolumeList] = function(resp)
    local data = resp:getData()
    local len = #data

    local pos, items, next_vol_no = bin.unpack("<II", data)
    local vols = {}
    for i=1, items do
      local vol = {}
      pos, vol.vol_no, vol.vol_name = bin.unpack("<Ip", data, pos)
      table.insert(vols, vol)
    end
    return true, vols
  end,

  --- Decodes a Ping response
  -- @param resp string containing the response as received from the server
  -- @return status true on success, false on failure
  -- @return response table (if status is true) containing:
  --         <code>tree_name</code>
  -- @return error message (if status is false)
  Ping = function(resp)
    local data = resp:getData()
    local len = #data
    local pos
    local result = {}

    if ( len < 40 ) then return false, "NCP Ping result too short" end

    pos, result.nds_version = bin.unpack("C", data)
    -- move to the offset of the
    pos = pos + 7
    pos, result.tree_name = bin.unpack("A32", data, pos)

    result.tree_name = (result.tree_name:match("^([^_]*)_*$"))

    return true, result
  end,

  --- Decodes a EnumerateNetworkAddress response
  -- @param resp string containing the response as received from the server
  -- @return status true on success, false on failure
  -- @return response table (if status is true) containing:
  --         <code>ip</code>, <code>port</code> and <code>proto</code>
  -- @return error message (if status is false)
  [NCPFunction.EnumerateNetworkAddress] = function(resp)
    local pos, result = 1, {}
    local items
    local data = resp:getData()
    local len = #data

    pos, result.time_since_boot, result.console_version, result.console_revision,
    result.srvinfo_flags, result.guid, result.next_search,
    items = bin.unpack("<ICCSA16II", data)

    local function DecodeAddress(data, pos)
      local COMM_TYPES = { [5] = "udp", [6] = "tcp" }
      local comm_type, port, ip, _
      pos, comm_type, _, _, _, port, ip = bin.unpack(">CCISS<I", data, pos)

      return pos, { port = port, ip = ipOps.fromdword(ip),
        proto = COMM_TYPES[comm_type] or "unknown" }
    end

    if ( ( pos - 1 ) + (items * 14 ) > len ) then
      return false, "EnumerateNetworkAddress packet too short"
    end

    result.addr = {}
    for i=1, items do
      local addr = {}
      pos, addr = DecodeAddress(data, pos)
      table.insert(result.addr, addr )
    end
    return true, result
  end,


  --- Decodes a Resolve response
  -- @param resp string containing the response as received from the server
  -- @return status true on success, false on failure
  -- @return response table (if status is true) containing:
  --         <code>tag</code> and <code>id</code>
  -- @return error message (if status is false)
  Resolve = function(resp)
    local data = resp:getData()
    local len = #data

    if ( len < 12 ) then
      return false, "ResponseParser: NCP Resolve, packet too short"
    end

    local pos, frag_size, frag_handle, comp_code = bin.unpack("<III", data)

    if ( len < 38 ) then
      return false, "ResponseParser: message too short"
    end

    if ( comp_code ~= 0 ) then
      return false, ("ResponseParser: Completion code returned" ..
        " non-zero value (%d)"):format(comp_code)
    end

    local pos, tag, entry = bin.unpack("<II", data, pos)

    return true, { tag = tag, id = entry }
  end,


  --- Decodes a Search response
  -- @param resp string containing the response as received from the server
  -- @return status true on success, false on failure
  -- @return entries table (if status is true) as return by:
  --         <code>EntryDecoder</code>
  -- @return error message (if status is false)
  Search = function(resp)
    local data = resp:getData()
    local len = #data
    local entries = {}

    if ( len < 12 ) then
      return false, "ResponseParser: NCP Resolve, packet too short"
    end

    local pos, frag_size, frag_handle, comp_code, iter_handle = bin.unpack("<IIII", data)

    if ( comp_code ~= 0 ) then
      return false, ("ResponseParser: Completion code returned" ..
        " non-zero value (%d)"):format(comp_code)
    end

    pos = pos + 12
    local entry_count
    pos, entry_count = bin.unpack("<I", data, pos)

    for i=1, entry_count do
      local entry
      pos, entry = ResponseParser.EntryDecoder(data, pos)
      -- pad for unknown trailing data in searches
      pos = pos + 8
      table.insert(entries, entry)
    end
    return true, entries
  end,

  --- The EntryDecoder is used by the Search and List function, for decoding
  -- the returned entries.
  -- @param data containing the response as returned by the server
  -- @param pos number containing the offset into data to start decoding
  -- @return pos number containing the new offset after decoding
  -- @return entry table containing the decoded entry, currently it contains
  --    one or more of the following fields:
  --      <code>flags</code>
  --      <code>mod_time</code>
  --      <code>sub_count</code>
  --      <code>baseclass</code>
  --      <code>rdn</code>
  --      <code>name</code>
  EntryDecoder = function(data, pos)

    -- The InfoFlags class takes a numeric value and facilitates
    -- bit decoding into InfoFlag fields, the current supported fields
    -- are:
    --  <code>Output</code>
    --  <code>Entry</code>
    --  <code>Count</code>
    --  <code>ModTime</code>
    --  <code>BaseClass</code>
    --  <code>RelDN</code>
    --  <code>DN</code>
    local InfoFlags = {
      -- Creates a new instance
      -- @param val number containing the numeric representation of flags
      -- @return a new instance of InfoFlags
      new = function(self, val)
        local o = {}
        setmetatable(o, self)
        self.__index = self
        o.val = val
        o:parse()
        return o
      end,

      -- Parses the numeric value and creates a number of class fields
      parse = function(self)
        local fields = { "Output", "_u1", "Entry", "Count", "ModTime",
          "_u2", "_u3", "_u4", "_u5", "_u6", "_u7", "BaseClass",
          "RelDN", "DN" }
        local bits = 1
        for _, field in ipairs(fields) do
          self[field] = ( bit.band(self.val, bits) == bits )
          bits = bits * 2
        end
      end
    }

    local entry = {}
    local f, len
    pos, f = bin.unpack("<I", data, pos)
    local iflags = InfoFlags:new(f)

    if ( iflags.Entry ) then
      pos, entry.flags, entry.sub_count = bin.unpack("<II", data, pos)
    end

    if ( iflags.ModTime ) then
      pos, entry.mod_time = bin.unpack("<I", data, pos)
    end

    if ( iflags.BaseClass ) then
      pos, len = bin.unpack("<I", data, pos)
      pos, entry.baseclass = bin.unpack("A" .. len, data, pos)
      entry.baseclass = Util.FromWideChar(entry.baseclass)
      entry.baseclass = Util.CToLuaString(entry.baseclass)
      pos = ( len % 4 == 0 ) and pos or pos + ( 4 - ( len % 4 ) )
    end

    if ( iflags.RelDN ) then
      pos, len = bin.unpack("<I", data, pos)
      pos, entry.rdn = bin.unpack("A" .. len, data, pos)
      entry.rdn = Util.FromWideChar(entry.rdn)
      entry.rdn = Util.CToLuaString(entry.rdn)
      pos = ( len % 4 == 0 ) and pos or pos + ( 4 - ( len % 4 ) )
    end

    if ( iflags.DN ) then
      pos, len = bin.unpack("<I", data, pos)
      pos, entry.name = bin.unpack("A" .. len, data, pos)
      entry.name = Util.FromWideChar(entry.name)
      entry.name = Util.CToLuaString(entry.name)
      pos = ( len % 4 == 0 ) and pos or pos + ( 4 - ( len % 4 ) )
    end

    return pos, entry
  end,


  --- Decodes a List response
  -- @param resp string containing the response as received from the server
  -- @return status true on success, false on failure
  -- @return entries table (if status is true) as return by:
  --         <code>EntryDecoder</code>
  -- @return error message (if status is false)
  List = function(resp)
    local data = resp:getData()
    local len = #data

    if ( len < 12 ) then
      return false, "ResponseParser: NCP Resolve, packet too short"
    end

    local pos, frag_size, frag_handle, comp_code, iter_handle = bin.unpack("<IIII", data)

    if ( comp_code ~= 0 ) then
      return false, ("ResponseParser: Completion code returned" ..
        " non-zero value (%d)"):format(comp_code)
    end

    local entry_count
    pos, entry_count = bin.unpack("<I", data, pos)

    local entries = {}

    for i=1, entry_count do
      local entry = {}
      pos, entry = ResponseParser.EntryDecoder(data, pos)
      table.insert(entries, entry)
    end

    return true, entries
  end,
}

-- The response class holds the NCP data. An instance is usually created
-- using the fromSocket static function that reads a NCP packet of the
-- the socket and makes necessary parsing.
Response = {

  --- Creates a new Response instance
  -- @param header string containing the header part of the response
  -- @param data string containing the data part of the response
  -- @return o new instance of Response
  new = function(self, header, data)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.header = header
    o.data = data
    o:parse()
    return o
  end,

  --- Parses the Response
  parse = function(self)
    local pos, _

    pos, self.signature, self.length, self.type,
    self.seqno, self.conn, _, self.compl_code,
    self.status_code = bin.unpack(">IISCCSCC", self.header)

    if ( self.data ) then
      local len = #self.data - pos
      if ( ( #self.data - pos ) ~= ( self.length - 33 ) ) then
        stdnse.debug1("NCP packet length mismatched")
        return
      end
    end
  end,

  --- Gets the sequence number
  -- @return seqno number
  getSeqNo = function(self) return self.seqno end,

  --- Gets the connection number
  -- @return conn number
  getConnNo = function(self) return self.conn end,

  --- Gets the data portion of the response
  -- @return data string
  getData = function(self) return self.data end,

  --- Gets the header portion of the response
  getHeader = function(self) return self.header end,

  --- Returns true if there are any errors
  -- @return error true if the response error code is anything else than OK
  hasErrors = function(self)
    return not( ( self.compl_code == Status.COMPLETION_OK ) and
      ( self.status_code == Status.CONNECTION_OK ) )

  end,

  --- Creates a Response instance from the data read of the socket
  -- @param socket socket connected to server and ready to receive data
  -- @return Response containing a new Response instance
  fromSocket = function(socket)
    local status, header = socket:receive_buf(match.numbytes(16), true)
    if ( not(status) ) then return false, "Failed to receive data" end

    local pos, sig, len = bin.unpack(">II", header)
    if ( len < 8 ) then return false, "NCP packet too short" end

    local data

    if ( 0 < len - 16 ) then
      status, data = socket:receive_buf(match.numbytes(len - 16), true)
      if ( not(status) ) then return false, "Failed to receive data" end
    end
    return true, Response:new(header, data)
  end,

  --- "Serializes" the Response instance to a string
  __tostring = function(self)
    return bin.pack("AA", self.header, self.data)
  end,

}

-- The NCP class
NCP = {

  --- Creates a new NCP instance
  -- @param socket containing a socket connected to the NCP server
  -- @return o instance of NCP
  new = function(self, socket)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.socket = socket
    o.seqno = -1
    o.conn = 0
    return o
  end,

  --- Handles sending and receiving a NCP message
  -- @param p Packet containing the request to send to the server
  -- @return status true on success false on failure
  -- @return response table (if status is true) containing the parsed
  --         response
  -- @return error string (if status is false) containing the error
  Exch = function(self, p)
    local status, err = self:SendPacket(p)
    if ( not(status) ) then return status, err end

    local status, resp = Response.fromSocket(self.socket)
    if ( not(status) or resp:hasErrors() ) then return false, resp end

    self.seqno = resp:getSeqNo()
    self.conn = resp:getConnNo()

    return ResponseParser.parse(p, resp)
  end,

  --- Sends a packet to the server
  -- @param p Packet to be sent to the server
  -- @return status true on success, false on failure
  -- @return err string containing the error message on failure
  SendPacket = function(self, p)
    if ( not(p:getSeqNo() ) ) then p:setSeqNo(self.seqno + 1) end
    if ( not(p:getConnNo() ) ) then p:setConnNo(self.conn) end

    if ( not(p:getNCPLength()) ) then
      local len = #(tostring(p))
      p:setNCPLength(len)
    end

    local status, err = self.socket:send(tostring(p))
    if ( not(status) ) then return status, "Failed to send data" end

    return true
  end,

  --- Creates a connection to the NCP server
  -- @return status true on success, false on failure
  CreateConnect = function(self)
    local p = Packet:new()
    p:setType(NCPType.CreateConnection)

    local resp = self:Exch( p )
    return true
  end,

  --- Destroys a connection established with the NCP server
  -- @return status true on success, false on failure
  DestroyConnect = function(self)
    local p = Packet:new()
    p:setType(NCPType.DestroyConnection)

    local resp = self:Exch( p )
    return true
  end,

  --- Gets file server information
  -- @return status true on success, false on failure
  -- @return response table (if status is true) containing:
  --         <code>srvname</code>
  --         <code>os_major</code>
  --         <code>os_minor</code>
  --         <code>conns_supported</code>
  --         <code>conns_inuse</code>
  --         <code>vols_supported</code>
  --         <code>os_rev</code>
  --         <code>sft_support</code>
  --         <code>tts_level</code>
  --         <code>conns_max_use</code>
  --         <code>acct_version</code>
  --         <code>vap_version</code>
  --         <code>qms_version</code>
  --         <code>print_version</code>
  --         <code>internet_bridge_ver</code>
  --         <code>mixed_mode_path</code>
  --         <code>local_login_info</code>
  --         <code>product_major</code>
  --         <code>product_minor</code>
  --         <code>product_rev</code>
  --         <code>os_lang_id</code>
  --         <code>support_64_bit</code>
  -- @return error message (if status is false)
  GetFileServerInfo = function(self)
    local p = Packet:new()
    p:setType(NCPType.ServiceRequest)
    p:setFunc(NCPFunction.GetFileServerInfo)
    p:setNCPReplyBuf(128)
    p:setLength(1)
    p:setSubFunc(17)
    return self:Exch( p )
  end,


  -- NEEDS authentication, disabled for now
  --
  -- Get the logged on user for the specified connection
  -- @param conn_no number containing the connection number
  -- GetStationLoggedInfo = function(self, conn_no)
  --   local p = Packet:new()
  --   p:setType(NCPType.ServiceRequest)
  --   p:setFunc(NCPFunction.GetFileServerInfo)
  --   p:setNCPReplyBuf(62)
  --   p:setLength(5)
  --   p:setSubFunc(28)
  --   p:setTask(4)
  --
  --   local data = bin.pack("<I", conn_no)
  --   p:setData(data)
  --   return self:Exch( p )
  -- end,

  --- Sends a PING to the server which responds with the tree name
  -- @return status true on success, false on failure
  -- @return response table (if status is true) containing:
  --         <code>tree_name</code>
  -- @return error message (if status is false)
  Ping = function(self)
    local p = Packet:new()
    p:setType(NCPType.ServiceRequest)
    p:setFunc(NCPFunction.Ping)
    p:setSubFunc(1)
    p:setNCPReplyBuf(45)
    p:setData("\0\0\0")

    return self:Exch( p )
  end,

  --- Enumerates the IP addresses associated with the server
  -- @return status true on success, false on failure
  -- @return response table (if status is true) containing:
  --         <code>ip</code>, <code>port</code> and <code>proto</code>
  -- @return error message (if status is false)
  EnumerateNetworkAddress = function(self)
    local p = Packet:new()
    p:setType(NCPType.ServiceRequest)
    p:setFunc(NCPFunction.EnumerateNetworkAddress)
    p:setSubFunc(17)
    p:setNCPReplyBuf(4096)
    p:setData("\0\0\0\0")
    p:setLength(5)
    return self:Exch( p )
  end,

  --- Resolves an directory entry id from a name
  -- @param name string containing the name to resolve
  -- @return status true on success, false on failure
  -- @return response table (if status is true) containing:
  --         <code>tag</code> and <code>id</code>
  -- @return error message (if status is false)
  ResolveName = function(self, name)
    local p = Packet:new()
    p:setType(NCPType.ServiceRequest)
    p:setFunc(NCPFunction.SendFragmentedRequest)
    p:setSubFunc(2)
    p:setNCPReplyBuf(4108)

    local pad = (4 - ( #name % 4 ) )
    name = Util.ZeroPad(name, #name + pad)

    local w_name = Util.ToWideChar(name)
    local frag_handle, frag_size = 0xffffffff, 64176
    local msg_size, unknown, proto_flags, nds_verb = 44 + #w_name, 0, 0, 1
    local nds_reply_buf, version, flags, scope = 4096, 1, 0x2062, 0
    local unknown2 = 0x0e
    local ZERO = 0

    local data = bin.pack("<IIISSIIISSIIA", frag_handle, frag_size, msg_size,
      unknown, proto_flags, nds_verb, nds_reply_buf, version, flags,
      unknown, scope, #w_name, w_name, ZERO)

    local comms = { { transport = "TCP" } }
    local walkers= { { transport = "TCP" } }
    local PROTOCOLS = { ["TCP"] = 9 }

    data = data .. bin.pack("<I", #comms)
    for _, comm in ipairs(comms) do
      data = data .. bin.pack("<I", PROTOCOLS[comm.transport])
    end

    data = data .. bin.pack("<I", #walkers)
    for _, walker in ipairs(walkers) do
      data = data .. bin.pack("<I", PROTOCOLS[walker.transport])
    end

    p:setData(data)
    return self:Exch( p )
  end,

  --- Gets a list of volumes from the server
  -- @return status true on success, false on failure
  -- @return response table of vol entries (if status is true)
  --         Each vol entry is a table containing the following fields:
  --         <code>vol_no</code> and <code>vol_name</code>
  -- @return error message (if status is false)
  GetMountVolumeList = function(self)
    local p = Packet:new()
    p:setType(NCPType.ServiceRequest)
    p:setFunc(NCPFunction.GetMountVolumeList)
    p:setSubFunc(52)
    p:setNCPReplyBuf(538)
    p:setTask(4)
    p:setLength(12)

    local start_vol = 0
    local vol_req_flags = 1
    local src_name_space = 0

    local data = bin.pack("<III", start_vol, vol_req_flags, src_name_space )
    p:setData(data)
    return self:Exch( p )
  end,

  --- Searches the directory
  -- @param base entry as resolved by <code>Resolve</code>
  -- @param class string containing a class name (or * wildcard)
  -- @param name string containing a entry name (or * wildcard)
  -- @param options table containing one or more of the following
  --  <code>numobjs</code>
  -- @return status true on success false on failure
  -- @return entries table (if status is true) as return by:
  --         <code>ResponseDecoder.EntryDecoder</code>
  -- @return error string (if status is false) containing the error
  Search = function(self, base, class, name, options)
    assert( ( base and base.id ), "No base entry was specified")

    local class = class and class .. '\0' or '*\0'
    local name = name and name .. '\0' or '*\0'
    local w_name = Util.ToWideChar(name)
    local w_class = Util.ToWideChar(class)
    local options = options or {}
    local p = Packet:new()
    p:setType(NCPType.ServiceRequest)
    p:setFunc(NCPFunction.SendFragmentedRequest)
    p:setSubFunc(2)
    p:setNCPReplyBuf(64520)
    p:setTask(5)

    local frag_handle, frag_size, msg_size = 0xffffffff, 64176, 98
    local unknown, proto_flags, nds_verb, version, flags = 0, 0, 6, 3, 0
    local nds_reply_buf = 64520
    local iter_handle = 0xffffffff
    local repl_type = 2 -- base and all subordinates
    local numobjs = options.numobjs or 0
    local info_types = 1 -- Names
    local info_flags = 0x0000381d
    -- a bunch of unknowns
    local u2, u3, u4, u5, u6, u7, u8, u9 = 0, 0, 2, 2, 0, 0x10, 0, 0x11

    local data = bin.pack("<IIISSIIIIIIIIIIIIIIIIIAIIIA",
      frag_handle, frag_size, msg_size, unknown, proto_flags,
      nds_verb, nds_reply_buf, version, flags, iter_handle,
      base.id, repl_type, numobjs, info_types, info_flags, u2, u3, u4,
      u5, u6, u7, #w_name, w_name, u8, u9, #w_class, w_class )
    p:setData(data)
    return self:Exch( p )
  end,

  --- Lists the contents of entry
  -- @param entry entry as resolved by <code>Resolve</code>
  -- @return status true on success false on failure
  -- @return entries table (if status is true) as return by:
  --         <code>ResponseDecoder.EntryDecoder</code>
  -- @return error string (if status is false) containing the error
  List = function(self, entry)
    local p = Packet:new()
    p:setType(NCPType.ServiceRequest)
    p:setFunc(NCPFunction.SendFragmentedRequest)
    p:setSubFunc(2)
    p:setNCPReplyBuf(4112)
    p:setTask(2)

    local frag_handle, frag_size = 0xffffffff, 64176
    local msg_size, unknown, proto_flags, nds_verb = 40, 0, 0, 5
    local nds_reply_buf, version, flags = 4100, 1, 0x0001
    local iter_handle = 0xffffffff
    local unknown2 = 0x0e
    local ZERO = 0
    local info_flags = 0x0000381d

    local data = bin.pack("<IIISSIIISSIII", frag_handle, frag_size, msg_size,
    unknown, proto_flags, nds_verb, nds_reply_buf, version, flags,
    unknown, iter_handle, entry.id, info_flags )

    -- no name filter
    data = data .. "\0\0\0\0"

    -- no class filter
    data = data .. "\0\0\0\0"

    p:setData(data)
    local status, entries = self:Exch( p )
    if ( not(status) ) then return false, entries end

    return true, entries
  end,

}


Helper = {

  --- Creates a new Helper instance
  -- @return a new Helper instance
  new = function(self, host, port)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.host = host
    o.port = port
    return o
  end,

  --- Connect the socket and creates a NCP connection
  -- @return true on success false on failure
  connect = function(self)
    self.socket = nmap.new_socket()
    self.socket:set_timeout(5000)
    local status, err = self.socket:connect(self.host, self.port)
    if ( not(status) ) then return status, err end

    self.ncp = NCP:new(self.socket)
    return self.ncp:CreateConnect()
  end,

  --- Closes the helper connection
  close = function(self)
    self.ncp:DestroyConnect()
    self.socket:close()
  end,

  --- Performs a directory search
  -- @param base string containing the name of the base to search
  -- @param class string containing the type of class to search
  -- @param name string containing the name of the object to find
  -- @param options table containing on or more of the following
  --                <code>numobjs</code> - number of objects to limit the search to
  search = function(self, base, class, name, options)
    local base = base or "[Root]"
    local status, entry = self.ncp:ResolveName(base)

    if ( not(status) ) then
      return false, "Search failed, base could not be resolved"
    end

    local status, result = self.ncp:Search(entry, class, name, options)
    if (not(status)) then return false, result end

    return status, result
  end,

  --- Retrieves some information from the server using the following NCP
  -- functions:
  --
  --  * <code>GetFileServerInfo</code>
  --  * <code>Ping</code>
  --  * <code>EnumerateNetworkAddress</code>
  --  * <code>GetMountVolumeList</code>
  --
  -- The result contains the Tree name, product versions and mounts
  getServerInfo = function(self)
    local status, srv_info = self.ncp:GetFileServerInfo()
    if ( not(status) ) then return false, srv_info end

    local status, ping_info = self.ncp:Ping()
    if ( not(status) ) then return false, ping_info end

    local status, net_info = self.ncp:EnumerateNetworkAddress()
    if ( not(status) ) then return false, net_info end

    local status, mnt_list = self.ncp:GetMountVolumeList()
    if ( not(status) ) then return false, mnt_list end

    local output = {}
    table.insert(output, ("Server name: %s"):format(srv_info.srvname))
    table.insert(output, ("Tree Name: %s"):format(ping_info.tree_name))
    table.insert(output,
    ("OS Version: %d.%d (rev %d)"):format(srv_info.os_major,
    srv_info.os_minor, srv_info.os_rev))
    table.insert(output,
    ("Product version: %d.%d (rev %d)"):format(srv_info.product_major,
    srv_info.product_minor, srv_info.product_rev))
    table.insert(output, ("OS Language ID: %d"):format(srv_info.os_lang_id))

    local niceaddr = {}
    for _, addr in ipairs(net_info.addr) do
      table.insert(niceaddr, ("%s %d/%s"):format(addr.ip,addr.port,
      addr.proto))
    end

    niceaddr.name = "Addresses"
    table.insert(output, niceaddr)

    local mounts = {}
    for _, mount in ipairs(mnt_list) do
      table.insert(mounts, mount.vol_name)
    end

    mounts.name = "Mounts"
    table.insert(output, mounts)

    if ( nmap.debugging() > 0 ) then
      table.insert(output, ("Acct version: %d"):format(srv_info.acct_version))
      table.insert(output, ("VAP version: %d"):format(srv_info.vap_version))
      table.insert(output, ("QMS version: %d"):format(srv_info.qms_version))
      table.insert(output,
      ("Print server version: %d"):format(srv_info.print_version))
      table.insert(output,
      ("Virtual console version: %d"):format(srv_info.virt_console_ver))
      table.insert(output,
      ("Security Restriction Version: %d"):format(srv_info.sec_restrict_ver))
      table.insert(output,
      ("Internet Bridge Version: %d"):format(srv_info.internet_bridge_ver))
    end

    return true, output
  end,
}

--- "static" Utility class containing mostly conversion functions
Util =
{
  --- Converts a string to a wide string
  --
  -- @param str string to be converted
  -- @return string containing a two byte representation of str where a zero
  --         byte character has been tagged on to each character.
  ToWideChar = function( str )
    return str:gsub("(.)", "%1" .. string.char(0x00) )
  end,


  --- Concerts a wide string to string
  --
  -- @param wstr containing the wide string to convert
  -- @return string with every other character removed
  FromWideChar = function( wstr )
    local str = ""
    if ( nil == wstr ) then return nil end
    for i=1, wstr:len(), 2 do str = str .. wstr:sub(i, i) end
    return str
  end,

  --- Pads a string with zeroes
  --
  -- @param str string containing the string to be padded
  -- @param len number containing the length of the new string
  -- @return str string containing the new string
  ZeroPad = function( str, len )
    if len < str:len() then return end
    for i=1, len - str:len() do str = str .. string.char(0) end
    return str
  end,

  -- Removes trailing nulls
  --
  -- @param str containing the string
  -- @return ret the string with any trailing nulls removed
  CToLuaString = function( str )
    local ret

    if ( not(str) ) then return "" end
    if ( str:sub(-1, -1 ) ~= "\0" ) then return str end

    for i=1, #str do
      if ( str:sub(-i,-i) == "\0" ) then
        ret = str:sub(1, -i - 1)
      else
        break
      end
    end
    return ret
  end,

}

return _ENV;
