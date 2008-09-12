--- The datafiles module provides functions for reading and parsing Nmap's
-- data files. For example nmap-protocol, nmap-rpc, etc. These functions'
-- return values are setup for use with exception handling via nmap.new_try().
-- @author Kris Katterjohn 03/2008
-- @author jah 08/2008

module(... or "datafiles", package.seeall)

local stdnse = require "stdnse"


---
-- Holds tables containing captures for common data files, indexed by filename.
-- @type table
-- @name common_files
local common_files = {
    ["nmap-rpc"]       = { [function(ln) return tonumber( ln:match( "^%s*[^%s#]+%s+(%d+)" ) ) end] = "^%s*([^%s#]+)%s+%d+" },
    ["nmap-protocols"] = { [function(ln) return tonumber( ln:match( "^%s*[^%s#]+%s+(%d+)" ) ) end] = "^%s*([^%s#]+)%s+%d+" },
    ["nmap-services"]  = { ["tcp"] = { [function(ln) return tonumber( ln:match( "^%s*[^%s#]+%s+(%d+)/tcp" ) ) end] = "^%s*([^%s#]+)%s+%d+/tcp" },
                           ["udp"] = { [function(ln) return tonumber( ln:match( "^%s*[^%s#]+%s+(%d+)/udp" ) ) end] = "^%s*([^%s#]+)%s+%d+/udp" }
    }

}


---
-- This function reads and parses Nmap's nmap-protocols file.
-- bool is a Boolean value indicating success. If bool is true, then the
-- second returned value is a table with protocol numbers indexing the
-- protocol names. If bool is false, an error message is returned as the
-- second value instead of the table.
-- @return bool, table|err
-- @see parse_file
parse_protocols = function()
  local status, protocols_table = parse_file("nmap-protocols")
  if not status then
    return false, "Error parsing nmap-protocols"
  end

  return true, protocols_table
end


---
-- This function reads and parses Nmap's nmap-rpc  file. bool is a
-- Boolean value indicating success. If bool is true, then the second
-- returned value is a table with RPC numbers indexing the RPC names.
-- If bool is false, an error message is returned as the second value
-- instead of the table.
-- @return bool, table|err
-- @see parse_file
parse_rpc = function()
  local status, rpc_table = parse_file("nmap-rpc")
  if not status then
    return false, "Error parsing nmap-rpc"
  end

  return true, rpc_table
end


---
-- This function reads and parses Nmap's nmap-services file.
-- bool is a Boolean value indicating success. If bool is true,
-- then the second returned value is a table containing two other
-- tables: tcp{} and udp{}. tcp{} contains services indexed by TCP port
-- numbers. udp{} is the same, but for UDP. You can pass "tcp" or "udp"
-- as an argument to parse_services() to only get the corresponding table.
-- If bool is false, an error message is returned as the second value instead
-- of the table.
-- @param protocol The protocol table to return.
-- @return bool, table|err
-- @see parse_file
parse_services = function(protocol)
  if protocol and protocol ~= "tcp" and protocol ~= "udp" then
    return false, "Bad protocol for nmap-services: use tcp or udp"
  end

  local status, services_table = parse_file("nmap-services", protocol)
  if not status then
    return false, "Error parsing nmap-services"
  end

  return true, services_table
end


---
-- Generic parsing of datafiles.  By supplying this function with a table containing captures to be applied to each line
-- of a datafile a table will be returned which mirrors the structure of the supplied table and which contains any captured
-- values.  A capture will be applied to each line using string.match() and may also be enclosed within a table or a function.
-- A function must accept a line as its paramater and should return one value derived from that line.

function parse_file( filename, ... )

  local data_struct

  -- must have a filename
  if type( filename ) ~= "string" or filename == "" then
    return false, "Error in datafiles.parse_file: No file to parse."
  end

  -- is filename a member of common_files? is second parameter a key in common_files or is it a table?
  if common_files[filename] then
    if type( arg[1] ) == "string" and common_files[filename][arg[1]] then
      data_struct = {{ [arg[1]] = common_files[filename][arg[1]] }}
    elseif type( arg[1] ) == "table" then
      data_struct = { arg[1] }
    else
      data_struct = { common_files[filename] }
    end
  end

  if type( data_struct ) ~= "table" then
    local t = {}
    for _, a in ipairs( arg ) do
      if type( a ) == "table" then
        if not next( a ) then a = { "^(.+)$" } end -- empty table? no problem, you'll get the whole line
        t[#t+1] = a
      end
    end
    if #t == 0 then
      return false, "Error in datafiles.parse_file: I've no idea how you want your data."
    end
    data_struct = t
  end

  -- get a table of lines
  local status, lines = read_from_file( filename )
  if not status then
    return false, ( "Error in datafiles.parse_file: %s could not be read: %s." ):format( filepath, lines )
  end

  -- do the actual parsing
  local ret = {}
  for _, ds in ipairs( data_struct ) do
    status, ret[#ret+1] = parse_lines( lines, ds )
    -- hmmm should we fail all if there are any failures? yes? ok
    if not status then return false, ret[#ret] end
  end

  return true, unpack( ret )

end


---
-- Generic parsing of an array of strings.  By supplying this function with a table containing captures to be applied to each value
-- of a array-like table of strings a table will be returned which mirrors the structure of the supplied table and which contains any captured
-- values.  A capture will be applied to each array member using string.match() and may also be enclosed within a table or a function.
-- A function must accept an array member as its paramater and should return one value derived from that member.

function parse_lines( lines, data_struct  )

  if type( lines ) ~= "table" or #lines < 1 then
    return false, "Error in datafiles.parse_lines: No lines to parse."
  end

  if type( data_struct ) ~= "table" or not next( data_struct ) then
    return false, "Error in datafiles.parse_lines: No patterns for data capture."
  end

  local ret = {}

  -- traverse data_struct and enforce sensible index-value pairs.  Call functions to process the members of lines.
  for index, value in pairs( data_struct ) do
    if type(index) == nil then return false, "Error in datafiles.parse_lines: Invalid index." end
    if type(index) == "number" or type(value) == "table" then
      if type(value) == "number" then
        return false, "Error in datafiles.parse_lines: No patterns for data capture."
      elseif type(value) == "string" or type(value) == "function" then
        ret = get_array( lines, value )
      elseif type(value) == "table" then
        _, ret[index] = parse_lines( lines, value )
      else
        -- TEMP
        stdnse.print_debug("Unexpected value %s", type(value))
      end
    elseif type(index) == "string" or type(index) == "function"  then
      if type( value ) == "string" or type( value ) == "function" then
        ret = get_assoc_array( lines, index, value )
      else
        return false, ( "Error in datafiles.parse_lines: Invalid value for index %s." ):format( index )
      end
    else
      -- TEMP
      stdnse.print_debug("unexpexted index %s %s", type(index), type(value))
    end
  end

  return true, ret
end


---
-- Reads a file, line by line, into a table.
-- @param file  String with the name of the file to read.
-- @return      Boolean True on success, False on error
-- @return      Table (array-style) of lines read from the file or error message in case of an error.

function read_from_file( file )

  -- get path to file
  local filepath = nmap.fetchfile( file )
  if not filepath then
    return false, ( "Error in nmap.fetchfile: Could not find file %s." ):format( filename )
  end

  local f, err, _ = io.open( filepath, "r" )
  if not f then
    return false, ( "Error in datafiles.read_from_file: Cannot open %s for reading: %s" ):format( file, err )
  end

  local line, ret = nil, {}
  while true do
    line = f:read()
    if not line then break end
    ret[#ret+1] = line
  end

  f:close()

  return true, ret

end

--- return an array-like table of values captured from each line
--@param lines table of strings containing the lines to process
--@param v_pattern pattern to use on the lines to produce the value for the array
get_array = function( lines, v_pattern )
  local ret = {}
  for _, line in ipairs( lines ) do
    assert( type( line ) == "string" )
    local captured
    if type( v_pattern ) == "function" then
      captured = v_pattern( line )
    else
      captured = line:match( v_pattern )
    end
    table.insert( ret, captured )
  end
  return ret
end

--- return an associative array table of index-value pairs captured from each line
--@param lines table of strings containing the lines to process
--@param i_pattern pattern to use on the lines to produce the key for the associative array
--@param v_pattern pattern to use on the lines to produce the value for the associative array
get_assoc_array = function( lines, i_pattern, v_pattern )
  local ret = {}
  for _, line in ipairs(lines) do
    assert( type( line ) == "string" )
    if type(i_pattern) == "function" then
      index = i_pattern(line)
    else
      index = line:match(i_pattern)
    end
    if index and type(v_pattern) == "function" then
      ret[index] = v_pattern(line)
    elseif index then
      ret[index] = line:match(v_pattern)
    end
  end
  return ret
end

