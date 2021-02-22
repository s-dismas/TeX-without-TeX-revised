

--- Copyright (c) 2021 by Toadstone Enterprises.
--- ISC-type license, see License.txt for details.


-----------------------------------------------------------------


local reader = require("reader")

local read_value   = reader.read_value


-----------------------------------------------------------------


local sp_to_p = function(sp)
  -- Convert scaled points to points.
  return sp/65536
end


local sp_to_in = function(sp)
  -- Convert scaled points to inches.
  return sp_to_p(sp)/72.27
end


local node_type = function(x)
  -- Return the type of a node as a string.
  return node.types()[x.id]
end


local node_subtype = function(x)
  -- Return the subtype of a node as a string.
  local type = node_type(x)
  return node.subtypes(type)[x.subtype]
end


local link_nodes = function(...)
  -- Link the nodes, setting both the next and prev fields.
  local arg = {...}
  for i = 1, (#arg - 1) do
    arg[i].next = arg[i+1]
    arg[i+1].prev = arg[i]
  end
end


local make_glyph = function(value, fnt, lang, lefthyphenmin, righthyphenmin)
  local n   = node.new("glyph")
  n.font    = fnt or font.current()
  n.subtype = 1
  n.char    = value
  n.lang    = lang or tex.language
  n.uchyph  = 1
  n.left    = lefthyphenmin or tex.lefthyphenmin
  n.right   = righthyphenmin or tex.righthyphenmin
  return n
end


local make_glue = function(subtype,
                           width,
                           stretch, shrink,
                           stretch_order, shrink_order)
  local n = node.new("glue", subtype)
  node.setglue(n, width or 0,
                  stretch or 0,
                  shrink or 0,
                  stretch_order or 0,
                  shrink_order or 0)
  return n
end


local make_glue_spec = function(width,
                                stretch, shrink,
                                stretch_order, shrink_order)
  local n         = node.new("glue_spec")
  n.width         = width or 0
  n.stretch       = stretch or 0
  n.shrink        = shrink or 0
  n.stretch_order = stretch_order or 0
  n.shrink_order  = shrink_order or 0
  return n
end


local make_rule = function(subtype, width, height, depth, dir)
  local n  = node.new("rule", subtype or 0)
  n.width  = width or 0
  n.height = height or 0
  n.depth  = depth or 0
  n.dir    = dir or "TLT"
  return n
end


local make_penalty = function(penalty)
  local n   = node.new("penalty")
  n.penalty = penalty
  return n
end


local fil = function()
  -- Return a "fil" glue_spec.
  return make_glue_spec(0, tex.sp("1pt"), 0, 1, 0)
end

local fill = function()
  -- Return a "fill" glue_spec.
  return make_glue_spec(0, tex.sp("1pt"), 0, 2, 0)
end

local filll = function()
  -- Return a "filll" glue_spec.
  return make_glue_spec(0, tex.sp("1pt"), 0, 3, 0)
end


-----------------------------------------------------------------


local read_string = function()
  -- We return a regular (not exploded or anything) string.

  local ans = ""
  local value = read_value()
  
  -- Should we be eat any white space before the string?
  while is_whitespace(value) do
    value = read_value()
  end
  
  if ((value ~= unicode.utf8.byte('"')) and 
      (value ~= unicode.utf8.byte("'"))) then
    error("Not a string. No opening quoteation mark.")
  end

  -- So we can look only for the matching quote
  local delimiter = value

  value = read_value()
  while (value and (value ~= delimiter)) do
    -- We want to return a regular string.
    ans = ans .. unicode.utf8.char(value)
    value = read_value()
  end

  if (not value) then  -- eof
    error("Not a string. No closing quotation mark.")
  end

  return ans
end


local read_group = function(eat_the_white)
  -- We read a group, (delimited by matching "{", "}" or "[", "]")
  -- possibly eating any white space within the group.
  -- We return a regular (not exploded or anything) string.

  local ans = ""
  local value = read_value()
  
  -- Should we eat any white space before the group?
  while is_whitespace(value) do
    value = read_value()
  end

  -- So we can look only for the matching delimiter  
  local delimiter
  if (value == unicode.utf8.byte("{")) then
    delimiter = unicode.utf8.byte("}")
  elseif (value == unicode.utf8.byte("[")) then
    delimiter = unicode.utf8.byte("]")
  else
    error("Not a group. No opening group delimiter.")
  end

  value = read_value()
  while (value and (value ~= delimiter)) do
    if ((not eat_the_white) or (not is_whitespace(value))) then
      ans = ans .. unicode.utf8.char(value)
    end
    value = read_value()
  end

  if (not value) then   -- eof
    error("Not a group. No closing group delimiter.")
  end

  return ans
end


local read_line = function()
  -- Read to the end of the current line (and throw away the result).
  local value = read_value()
  while (not is_linefeed(value)) do
    value = read_value()
  end
end


-----------------------------------------------------------------


local copy_table = function(tbl)
  -- Make a deep copy of the table.
  -- We do not copy the keys.

  local result = {}
  if type(tbl) == "table" then
    for k,v in pairs(tbl) do
      result[k] = copy_table(v)
    end
  else
    result = tbl
  end
  return result

end


-----------------------------------------------------------------


--- Character categories


local whitespace = {[0x0009] = true,  -- Tab
                    [0x000A] = true,  -- LF  -- Line Break
                    [0x000B] = true,  -- Line Tab  -- Line Break
                    [0x000C] = true,  -- Form Feed  -- Line Break
                    [0x000D] = true,  -- CR  -- Line Break
                    [0x0020] = true,  -- Space
                    [0x0085] = true,  -- Next Line  -- Line Break
                    [0x00A0] = true,  -- NB Space  -- No Break
                    [0x1680] = true,  -- Ogham Space Mark
                    [0x2000] = true,  -- EN Quad
                    [0x2001] = true,  -- EM Quad
                    [0x2002] = true,  -- EN Space
                    [0x2003] = true,  -- EM Space
                    [0x2004] = true,  -- Three per EM Space
                    [0x2005] = true,  -- Four per EM Space
                    [0x2006] = true,  -- Six per Em Space
                    [0x2007] = true,  -- Figure Space  -- No Break
                    [0x2008] = true,  -- Punctuation Space
                    [0x2009] = true,  -- Thin Space
                    [0x200A] = true,  -- Hair Space
                    [0x2028] = true,  -- Line Separator  -- Line Break
                    [0x2029] = true,  -- Paragraph Separator  -- Line Break
                    [0x202F] = true,  -- Narrow NB Space  -- No Break
                    [0x205F] = true,  -- Medium Mathematical Space
                    [0x3000] = true   -- Ideographic Space
                   }

local is_whitespace = function(value)
  return whitespace[value]
end


local linefeed = {[0x000A] = true,  -- LF  -- Line Break
                  [0x000B] = true,  -- Line Tab  -- Line Break
                  [0x000C] = true,  -- Form Feed  -- Line Break
                  [0x000D] = true,  -- CR  -- Line Break
                  [0x0085] = true,  -- Next Line  -- Line Break
                  [0x2028] = true,  -- Line Separator  -- Line Break
                  [0x2029] = true   -- Paragraph Separator  -- Line Break
                 }
                      

local is_linefeed = function(value)
  return linefeed[value]  
end


local nobreak = {[0x00A0] = true,  -- NB Space  -- No Break
                 [0x2007] = true,  -- Figure Space  -- No Break
                 [0x202F] = true,  -- Narrow NB Space  -- No Break
                }

local is_nobreak = function(value)
  return nobreak[value]
end


local command_terminator = {[unicode.utf8.byte("{")] = true,
                            [unicode.utf8.byte("[")] = true,
                            -- But we want to terminate on
                            -- whitespace in general
                            -- [unicode.utf8.byte(" ")] = true
                           }

local is_command_terminator = function(value)
  return (command_terminator[value] or is_whitespace(value))
end


-----------------------------------------------------------------


--- Functions for exploring the state of nodes and tables.

--- With this schema, if you are in the REPL and discover that
--- a node you wish to show is not yet supported, for a node of
--- type xxx, define a function (in the REPL):
--- util.show_node_functions.show_xxx_node(n)
--- If you can't remember the correct name of the table,
--- walk_table(util)
--- will remind you.


local show_node_functions = {}


show_node_functions.show_hlist_node = function(n)
  local id      = node_type(n)
  local subtype = node.subtypes(tostring(id))[n.subtype]
  print("id:      " .. id)
  print("subtype: " .. subtype)
  print("width:   " .. sp_to_in(n.width) .. "in")
  print("height:  " .. sp_to_p(n.height) .. "p")
  print("depth:   " .. sp_to_p(n.depth)  .. "p")
  print()
end


show_node_functions.show_vlist_node = function(n)
  local id      = node_type(n)
  local subtype = node_subtype(n)
  print("id:      " .. id)
  print("subtype: " .. subtype)
  print("width:   " .. sp_to_in(n.width)  .. "in")
  print("height:  " .. sp_to_in(n.height) .. "in")
  print("depth:   " .. sp_to_in(n.depth)  .. "in")
  print()
end


show_node_functions.show_glyph_node = function(n)
  local id      = node_type(n)
  local subtype = node_subtype(n)
  print("id:      " .. id)
  -- sometimes a glyph node will not have a subtype?
  if subtype then print("subtype: " .. subtype) end
  print("char:    " .. unicode.utf8.char(n.char))
  print("font:    " .. n.font)
  print("lang:    " .. n.lang)
  print()
end


show_node_functions.show_glue_node = function(n)
  local id      = node_type(n)
  local subtype = node_subtype(n)
  print("id:      " .. id)
  print("subtype: " .. subtype)
  print("width:   " .. sp_to_p(n.width)   .. "p")
  print("stretch: " .. sp_to_p(n.stretch) .. "p")
  print("shrink:  " .. sp_to_p(n.stretch) .. "p")
  print()
end


show_node_functions.show_disc_node = function(n)
  local id      = node_type(n)
  local subtype = node_subtype(n)
  print("id:      " .. id)
  print("subtype: " .. subtype)
  -- pre
  -- post
  -- repl
  print()
end


show_node_functions.show_penalty_node = function(n)
  local id      = node_type(n)
  local subtype = node_subtype(n)
  print("id:      " .. id)
  print("subtype: " .. subtype)
  print("penalty: " .. n.penalty)
  print()
end


show_node_functions.show_kern_node = function(n)
  local id      = node_type(n)
  local subtype = node_subtype(n)
  print("id:               " .. id)
  print("subtype:          " .. subtype)
  print("kern:             " .. sp_to_p(n.kern) .. "p")
  print("expansion_factor: " .. n.expansion_factor)
  print()
end


show_node_functions.show_rule_node = function(n)
  local id      = node_type(n)
  local subtype = node_subtype(n)
  print("id:      " .. id)
  print("subtype: " .. subtype)
  print("width:   " .. sp_to_in(n.width) .. "in")
  print("height:  " .. sp_to_p(n.height) .. "p")
  print("depth:   " .. sp_to_p(n.depth)  .. "p")
  print("dir:     " .. n.dir)
  print()
end


local show_node = function(n)
  local id                 = node_type(n)
  local show_function_name = "show_" .. id .. "_node"
  local show_function      = show_node_functions[show_function_name]
  if show_function then
    show_function(n)
  else
    print("I don't know how to show a " .. id .. " node.")
    print()
  end
end


local walk_list = function(l)
  -- Walk down a list of nodes, showing them as we go.
  for n in node.traverse(l) do
    show_node(n)
  end
end


local walk_table = function(t)
  -- Walk through a table, showing the key/value pairs.
  local k, v
  for k,v in pairs(t) do
    print(k,v)
  end
end


util = {
  sp_to_p  = sp_to_p,
  sp_to_in = sp_to_in,

  node_type    = node_type,
  node_subtype = node_subtype,

  link_nodes = link_nodes,

  make_glyph     = make_glyph,
  make_glue      = make_glue,
  make_glue_spec = make_glue_spec,
  make_rule      = make_rule,
  make_penalty   = make_penalty,

  fil   = fil,
  fill  = fill,
  filll = filll,

  read_string = read_string,
  read_group  = read_group,
  read_line   = read_line,

  copy_table = copy_table,

  is_whitespace         = is_whitespace,
  is_linefeed           = is_linefeed,
  is_nobreak            = is_nobreak,
  is_command_terminator = is_command_terminator,

  show_node           = show_node,
  walk_list           = walk_list,
  walk_table          = walk_table,
 }


return util
