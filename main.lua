

--- Copyright (c) 2021 by Toadstone Enterprises.
--- ISC-type license, see License.txt for details.


-----------------------------------------------------------------


--- Why is this needed?
local main = {}
package.loaded[...] = main


local util = require("utils")

local link_nodes     = util.link_nodes
local make_glyph     = util.make_glyph
local make_glue      = util.make_glue
local make_penalty   = util.make_penalty
local is_whitespace  = util.is_whitespace
local is_linefeed    = util.is_linefeed
local is_nobreak     = util.is_nobreak
local copy_table     = util.copy_table
local read_line      = util.read_line


local reader = require("reader")

local read_value   = reader.read_value


local format = require("format")

local update_state         = format.update_state
local update_locals        = format.update_locals
local push_tbl             = format.push_tbl
local pop_tbl              = format.pop_tbl
local top_tbl              = format.top_tbl
local pop_do_command_stop  = format.pop_do_command_stop


local commands = commands or require("commands")

local get_command        = commands.get_command
local initialize_command = commands.initialize_command


local pages = pages or require("pages")

local build_par   = pages.build_par
local process_par = pages.process_par


-----------------------------------------------------------------


local do_char = function(value, head, tail)
  -- We are building the hlist that will be passed on to
  -- tex.linebreak for creating a paragraph.

  local tbl = top_tbl()

  local n = nil
  local p = nil  -- for penalties

  if is_nobreak(value) then
    -- we treat all unbreakable whitespace equally
    p = make_penalty(10000)
    n = make_glue("spaceskip",
                  tbl.space,
                  tbl.space_stretch,
                  tbl.space_shrink)
  elseif is_whitespace(value) then
    -- we treat all (breakable) whitespace equally
    n = make_glue("spaceskip",
                  tbl.space,
                  tbl.space_stretch,
                  tbl.space_shrink)
  else
    -- presumably a glyph
    n = make_glyph(value,
                   tbl.font,
                   tbl.lang,
                   tbl.lefthyphenmin,
                   tbl.righthyphenmin)
  end

  if (head == nil) then
    -- starting a new paragraph, but we add the initial glue in
    -- build_par.
    head = n
  elseif p then
    -- We have a penalty
    link_nodes(tail, p, n)
  else
    -- only a single node
    link_nodes(tail, n)
  end

  -- n is our new tail
  return head, n
end


local reading_par = function(head, tail)
  -- before we start reading a paragraph, head and tail will be nil.
  return (node.is_node(head) and node.is_node(tail))
end


main.main_loop = function()

  local head, tail, eat_the_white, eol_seen = update_locals()

  local value = read_value()

  while value do

    if value == unicode.utf8.byte("%") then
      -- Start of comment. Comment goes to the end of the line.

      read_line()
 
    elseif is_linefeed(value) then
    
      if (eol_seen and reading_par(head, tail)) then
        -- eol_seen ==> this is a blank line,
        -- reading_par(head, tail) ==> we are in the middle of a paragraph.
        -- Thus we avoid building 'empty' paragraphs.
        local par = build_par(head, tail)
        process_par(par)
        -- After we process the par, we reset head and tail to nil
        -- in preparation for the next paragraph to be read in.
        head = nil
        tail = nil
        
      elseif ((not eat_the_white) and reading_par(head, tail)) then
        -- (not eat_the_white) ==> this is the first bit of white space
        -- seen,
        -- reading_par(head, tail) ==> we are in the middle of a paragraph.
        -- Thus, we avoid starting a paragraph with white space.
        head, tail    = do_char(value, head, tail)
        eat_the_white = true
        eol_seen      = true
      end
      
    elseif is_whitespace(value) then
    
      if ((not eat_the_white) and reading_par(head, tail)) then
        -- (not eat_the_white) ==> this is the first bit of white space
        -- seen,
        -- reading_par(head, tail) ==> we are in the middle of a paragraph.
        -- Thus, we avoid starting a paragraph with white space.
        head, tail    = do_char(value, head, tail)
        -- But we do not set eol_seen to false. Thus an "empty" line can
        -- contain white space.
        eat_the_white = true
      end
      
    elseif value == unicode.utf8.byte("\\") then
    
      -- get the command, and initialize it
      command       = get_command()
      update_state(head, tail, false, false)
      initialize_command(command)
      -- initialize_command may hace done some stuff, resetting
      -- head, tail, eat_the_white, and eol_seen so we reset them here.
      head, tail, eat_the_white, eol_seen = update_locals()
      
    elseif value == unicode.utf8.byte("{") then
      -- enter a group or start a command
      
      update_state(head, tail, false , false)
      local do_command_start = State.do_command_start
      if do_command_start then
        -- We have a command, but before executing it, we reset
        -- State.do_command_start so that we do not get into a loop.
        State.do_command_start = nil
        do_command_start()
        head, tail, eat_the_white, eol_seen = update_locals()
        
      else
        -- enter a group.
        push_tbl(copy_table(top_tbl()))
      end
      
    elseif value == unicode.utf8.byte("}") then
      -- leave a group or stop a command

      local do_command_stop = pop_do_command_stop()
      if do_command_stop then
        update_state(head, tail, false, false)
        do_command_stop()
        head, tail, eat_the_white, eol_seen = update_locals()
      else
        pop_tbl()
      end
      
    else
      -- presumably a glyph

      eat_the_white = false
      eol_seen      = false
      head, tail    = do_char(value, head, tail)
    end
    
    value = read_value()
    
  end  -- while (value) do
  
  if reading_par(head, tail) then
    -- eof, and we may have a par to build.
    if reading_par(head, tail) then
      local par = build_par(head, tail)
      process_par(par)
    end
  end

  update_state(nil, nil, false, false)

  -- Check for unpopped tbls or do_command_stops?

end


return main
