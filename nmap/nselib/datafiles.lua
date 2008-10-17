--- Read and parse some of Nmap's data files: nmap-protocols, nmap-rpc,
-- and nmap-services.
-- \n\n
-- The functions in this module return values appropriate for use with
-- exception handling via nmap.new_try(). On success, they return true
-- and the function result. On failure, they return false and an error
-- message.
-- @author Kris Katterjohn 03/2008
-- @author jah 08/2008

module(... or "datafiles", package.seeall)

local stdnse = require "stdnse"


---
-- Capture patterns for common data files, indexed by filename.
-- @type table
-- @name common_files
-- @see parse_file
local common_files = {
    ["nmap-rpc"]       = { [function(ln) return tonumber( ln:match( "^%s*[^%s#]+%s+(%d+)" ) ) end] = "^%s*([^%s#]+)%s+%d+" },
    ["nmap-protocols"] = { [function(ln) return tonumber( ln:match( "^%s*[^%s#]+%s+(%d+)" ) ) end] = "^%s*([^%s#]+)%s+%d+" },
    ["nmap-services"]  = { ["tcp"] = { [function(ln) return tonumber( ln:match( "^%s*[^%s#]+%s+(%d+)/tcp" ) ) end] = "^%s*([^%s#]+)%s+%d+/tcp" },
                           ["udp"] = { [function(ln) return tonumber( ln:match( "^%s*[^%s#]+%s+(%d+)/udp" ) ) end] = "^%s*([^%s#]+)%s+%d+/udp" }
    }

}


---
-- Read and parse nmap-protocols.
-- \n\n
-- On success, return true and a table mapping protocol numbers to
-- protocol names.
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
-- Read and parse nmap-rpc.
-- \n\n
-- On success, return true and a table mapping RPC numbers to RPC names.
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
-- Read and parse nmap-services.
-- \n\n
-- On success, return true and a table containing two subtables, indexed
-- by the keys "tcp" and "udp". The tcp table maps TCP port numbers to
-- service names, and the udp table is the same for UDP. You can pass
-- "tcp" or "udp" as an argument to parse_services to get only one of
-- the results tables.
-- @param protocol The protocol table to return ("tcp" of "udp").
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
-- Read and parse a generic data file. The other parse functions are
-- defined in terms of this one.
-- \n\n
-- If filename is a key in common_files, use the corresponding capture
-- pattern. Otherwise the second argument must be a table of the kind
-- taken by parse_lines.
--
-- @return A table whose structure mirrors that of the capture table,
-- filled in with captured values.
function parse_file( filename, ... )

  local data_struct

  -- must have a filename
  if type( filename ) ~= "string" or filename == "" then
    return false, "Error in datafiles.parse_file: No file to parse."
  end

  -- is filename a member of common_files? is second parameter a key in common_files or is it a table?
  if common_files[filename] and type( arg[1] ) == "string" and common_files[filename][arg[1]] then
    data_struct = { common_files[filename][arg[1]] }
  elseif common_files[filename] and #arg == 0 then
    data_struct = { common_files[filename] }
  elseif type( arg[1] ) == "table" then
    data_struct = arg
  elseif type( arg[1] ) ~= "table" then
    return false, "Error in datafiles.parse_file: Expected second parameter as table."
  end

  if type( data_struct ) == "table" then
    for i, struc in ipairs( data_struct ) do
      -- check that all varargs are tables
      if type( struc ) ~= "table" then return false, "Error in datafiles.parse_file: Bad Parameter." end
      -- allow empty table as sugar for ^(.+)$ capture the whole line
      if not next( struc ) and #struc == 0 then data_struct[i] = { "^(.+)$" } end
    end
    if #data_struct == 0 then
      return false, "Error in datafiles.parse_file: I've no idea how you want your data."
    end
  end

  -- get a table of lines
  local status, lines = read_from_file( filename )
  if not status then
    return false, ( "Error in datafiles.parse_file: %s could not be read: %s." ):format( filename, lines )
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
-- Generic parsing of an array of strings.
-- 
-- @param lines An array of strings to operate on.
-- @param data_struct A table containing capture patterns to be applied
-- to each string in the array. A capture will be applied to each string
-- using string.match() and may also be enclosed within a table or a
-- function. If a function, it must accept a string as its parameter and
-- should return one value derived from that string.
-- @return A table whose structure mirrors that of the capture table,
-- filled in with captured values.
function parse_lines( lines, data_struct  )

  if type( lines ) ~= "table" or #lines < 1 then
    return false, "Error in datafiles.parse_lines: No lines to parse."
  end

  if type( data_struct ) ~= "table" or not next( data_struct ) then
    return false, "Error in datafiles.parse_lines: Expected second parameter as a non-empty table."
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
        stdnse.print_debug( "Error in datafiles.parse_lines: Index with type %s has unexpected value %s", type(index), type(value))
      end
    elseif type(index) == "string" or type(index) == "function"  then
      if type( value ) == "string" or type( value ) == "function" then
        ret = get_assoc_array( lines, index, value )
      else
        return false, ( "Error in datafiles.parse_lines: Invalid value for index %s." ):format( index )
      end
    else
      -- TEMP
      stdnse.print_debug( "Error in datafiles.parse_lines: Index with type %s has unexpected value %s", type(index), type(value))
    end
  end

  return true, ret

end


---
-- Read a file, line by line, into a table.
-- @param file  String with the name of the file to read.
-- @return      Boolean True on success, False on error
-- @return      Table (array-style) of lines read from the file or error message in case of an error.
function read_from_file( file )

  -- get path to file
  local filepath = nmap.fetchfile( file )
  if not filepath then
    return false, ( "Error in nmap.fetchfile: Could not find file %s." ):format( file )
  end

  local f, err, _ = io.open( filepath, "r" )
  if not f then
    return false, ( "Error in datafiles.read_from_file: Cannot open %s for reading: %s" ):format( filepath, err )
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


---
-- Return an array-like table of values captured from each line.
-- @param lines      table of strings containing the lines to process
-- @param v_pattern  pattern to use on the lines to produce the value for the array
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


---
-- Return an associative array table of index-value pairs captured from each line.
-- @param lines      table of strings containing the lines to process
-- @param i_pattern  pattern to use on the lines to produce the key for the associative array
-- @param v_pattern  pattern to use on the lines to produce the value for the associative array
get_assoc_array = function( lines, i_pattern, v_pattern )
  local ret = {}
  for _, line in ipairs(lines) do
    assert( type( line ) == "string" )
    local index
    if type(i_pattern) == "function" then
      index = i_pattern(line)
    else
      index = line:match(i_pattern)
    end
    if index and type(v_pattern) == "function" then
      local m = v_pattern(line)
      if m then ret[index] = m end
    elseif index then
      local m = line:match(v_pattern)
      if m then ret[index] = m end
    end
  end
  return ret
end
