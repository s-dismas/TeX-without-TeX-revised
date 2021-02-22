

--- Copyright (c) 2021 by Toadstone Enterprises.
--- ISC-type license, see License.txt for details.


-----------------------------------------------------------------


local util = require("utils")

local read_group            = util.read_group
local is_command_terminator = util.is_command_terminator
local is_whitespace         = util.is_whitespace
local node_type             = util.node_type


local reader = require("reader")

local push_reader   = reader.push_reader
local pop_reader    = reader.pop_reader
local read_value    = reader.read_value
local unread_value  = reader.unread_value
local replace_text  = reader.replace_text
local pos           = reader.pos


local format = require("format")

local update_state         = format.update_state
local update_locals        = format.update_locals
local push_tbl             = format.push_tbl
local pop_tbl              = format.pop_tbl
local top_tbl              = format.top_tbl
local push_do_command_stop = format.push_do_command_stop
local footnote_tbl         = format.footnote_tbl
local emph_text_font        = format.emph_text_font
local bold_text_font        = format.bold_text_font
local title_font            = format.title_font
local superscript_font      = format.superscript_font


local pages = require("pages")

local process_par = pages.process_par
local build_par   = pages.build_par
local build_pages = pages.build_pages


local main = main or require("main")

local main_loop = main.main_loop


-----------------------------------------------------------------


--- We will keep our various commands in a table, so that we
--- can retrieve them by name. We use a metatable to throw
--- a consistent error if a non-existant command is looked
--- for. The idea was that this would throw the error at that
--- time, instead of later on when we tried to use it.

local command_table = {}


local mt = {__index = function (_, command)
              error("Bad Command:" .. command)
            end
           }

setmetatable(command_table, mt)


local register_command = function(name, func)
  command_table[name] = func
end


-----------------------------------------------------------------


local get_command = function()
  -- A command in initiated by a "\", and terminated by a
  -- "[", "{", or whitespace. (But the initiating "\" has
  -- already been read past.) Return the command as a string.
  -- We also 'eat' any extra following whitespace, and then
  -- back up by one character, so the command can see the
  -- terminator; although we may lose the distinction of
  -- which whitespace terminated the command.
  -- This backing up will also allow the main_loop to see
  -- the "{", if there was one, and so doing the do_command_start.

  local command = ""
  local value = read_value()

  if is_command_terminator(value) then
    -- A one character command, consisting solely of a command terminator.
    command = unicode.utf8.char(value)
  else
    while (value and (not is_command_terminator(value))) do
      command = command .. unicode.utf8.char(value)
      value = read_value()
    end
  end

  while is_whitespace(value) do
    -- eat the white
    value = read_value()
  end
  
  -- so command can see the 'terminator'
  -- Note that if the command was terminated by whitespace,
  -- and then followed by more whitespace, we will not be
  -- distinguishing between the various types of whitespace.
  -- Does this matter?
  unread_value()
  
  return command
end


--- WARNING: An Emph in a Footnote will result in a change of font size!
--- There should be some notion of a font family where given the current
--- font, an appropriate Emph font can be chosen. At least consider size.

--- Emph displays most of the standard ways to do a command.
--- We define a function do_emph, which will then be registered.

local do_emph = function()
  -- We start off with some initialization. In this case, are we
  -- emphasizing the following group, or are we (presumably) already
  -- within a group?

  local value = read_value()
  unread_value{}

  if value == unicode.utf8.byte("{") then
    -- We emphasize the following group

    -- We now finish the initialization in this branch of the
    -- if statement.
    
    -- We push the current table, to that we can restore it
    -- at the end, namely in the do_command_stop.
    push_tbl(copy_table(top_tbl()))
    
    -- We have finished the initialization, so we define a
    -- do_command_start function to be executed upon encountering
    -- the "{"
    local do_command_start = function()
                               -- Switch over to the Emph font.
                               local tbl = top_tbl()
                               tbl.font = emph_text_font
                             end
 
    -- We then put this function into the proper place in State.
    State.do_command_start = do_command_start
    
    -- We also define a do_command_stop function, to be executed
    -- upon encountering the terminating "}".
    local do_command_stop  = function()
                               -- Pop the table, to return to the
                               -- previous situation.
                               pop_tbl()
                             end
    -- We then put this function into the proper place in State.
    push_do_command_stop(do_command_stop)

  else
    -- Emphasize all the following text (presumably within a group)
    -- This change of font will get reset when the group is exited,
    -- since State.tbl has been copied and pushed upon entrance into
    -- the group.
    local tbl = top_tbl()
    tbl.font = emph_text_font
  end
end

register_command("Emph", do_emph)


local do_bold = function()
  local value = read_value()
  unread_value{}

  if value == unicode.utf8.byte("{") then
    push_tbl(copy_table(top_tbl()))
    local do_command_start = function()
                               local tbl = top_tbl()
                               tbl.font = bold_text_font
                             end
    State.do_command_start = do_command_start
    local do_command_stop  = function()
                               pop_tbl()
                             end
    push_do_command_stop(do_command_stop)
  else
    local tbl = top_tbl()
    tbl.font = bold_text_font
  end
end

register_command("Bold", do_bold)


local do_input = function()
  -- Input a file.

  local filename

  local do_command_start = function()
                             -- so that the following read_group will see the opening "{"
                             unread_value()
                             -- Note that with the argument true to read_group
                             -- Input{filename}
                             -- Input  {  filename  }
                             -- Input{file name}
                             -- wil all read "filename"
                             -- Do we want this? The second seems useful, the
                             -- third does not.
                             filename = read_group(true)
                             -- So that main_loop will see the closing "}"
                             -- and call do_command_stop.
                             unread_value()
                           end
  State.do_command_start = do_command_start
  local do_command_stop = function()
                            -- We could have done all this above.
                            -- Now read in the file
                            push_reader("file:" .. filename)
                            -- Recursively call main_loop to typeset the
                            -- material we have read in. At the end of the
                            -- files contents, main_loop will terminate,
                            -- and execution will resume with the call to
                            -- pop_reader below.
                            -- Why do I need to qualify this?
                            main.main_loop()
                            -- Back to the original reader.
                            pop_reader()
                            -- And we now build the pages. We could probably
                            -- just leave the material there, but I am
                            -- envisioning each of these input files to
                            -- represent a chapter, to be typeset as their
                            -- own set of pages.
                            build_pages()
                          end
 push_do_command_stop(do_command_stop)
end

register_command("Input", do_input)


local do_fix = function()
  -- If one is transcribing a document, one may wish to correct
  -- typos. Three args - {<old>}{<new>}{<reason>}
  -- Perhaps not too useful in general, but a nice demonstration
  -- piece.

  -- Read the three groups, and insert the new text.
  local start  = pos()
  local old    = read_group(false)
  local new    = read_group(false)
  local reason = read_group(false)
  local stop   = pos()
  replace_text(new, start, stop-1)
end

register_command("Fix", do_fix)


local do_nb_space = function()
  -- Non breaking space. Note that we may have eaten any
  -- extra following white space, so the char at pos() may not
  -- be the original space.
  local cur_pos = pos()
  replace_text(unicode.utf8.char(0x00A0), cur_pos -2, cur_pos -1)
end

register_command(" ", do_nb_space)


--- QUESTION: Why, unlike in Footnote, do we not need to save the
--- current head and tail? Why do we set them to nil when we return
--- in do_command_stop?

local do_title = function()
  local value = read_value()
  if value == unicode.utf8.byte("[") then
    -- We use the contents of this optional argument to set the
    -- text of the header.
    unread_value()
    local args = read_group(false)
    -- Set the text of the header.
    State.header_text = args
  else
    -- So that the opening "{" will be seen.
    unread_value()
  end

  local old_baselineskip = tex.baselineskip
  push_tbl(copy_table(top_tbl()))  

  local do_command_start = function()
                             -- Set the new font and baselineskip
                             tex.baselineskip   = make_glue_spec(tex.sp("25pt"))
                             -- Add a title_tbl in format.lua?
                             local tbl = top_tbl()
                             tbl.font      = title_font

                             tbl.parindent = tex.sp("0pt")
                             tbl.leftskip  = filll()
                             tbl.rightskip = filll()
                           end
  State.do_command_start = do_command_start
  local do_command_stop = function()
                            -- We have now read the title, so force
                            -- building a paragraph
                            local head, tail, _, _ = update_locals()
                            local par = build_par(head, tail)
                            process_par(par)
                            -- Insert the (vertical) space after the title.
                            local title_sep = make_glue("userskip", tex.sp("0.25in"))
                            process_par(title_sep)
                            -- Reset various variables
                            update_state(nil, nil, false, false)
                            tex.baselineskip   = old_baselineskip
                            pop_tbl()

                            -- New chapter started
                            State.first_paragraph_of_chapter = true
                            State.first_page_of_chapter      = true
                            State.notes     = {}
                            State.max_notes = 0
                          end
  push_do_command_stop(do_command_stop)
end

register_command("Title", do_title)


local do_footnote = function()

  -- See the QUESTION: before do_title.
  local old_head, old_tail, _, _ = update_locals()
  local old_baselineskip = tex.baselineskip
  State.max_notes = State.max_notes + 1

  local do_command_start = function()
                             -- We want to mark the first preceding glyph
                             -- node with the Footnote marker.
                             local to_be_marked = old_tail
                             -- Search backward
                             while (node_type(to_be_marked) ~= "glyph") do
                               to_be_marked = to_be_marked.prev
                             end
                             -- Naked glyphs cannot go into a vlist:
                             local marker = node.hpack(make_glyph(unicode.utf8.byte(tostring(State.max_notes)),
                                                       superscript_font,
                                                       1, 3, 3))
                             -- Some glue to raise the mark
                             local marker_glue = make_glue(0, tex.sp("5pt"))
                             link_nodes(marker, marker_glue)
                             -- vpack, so that the glue is on the bottom,
                             -- not the left.
                             local packed = node.vpack(marker)
                             -- Link things back up.
                             if (to_be_marked == old_tail) then
                               link_nodes(to_be_marked, packed)
                               old_tail = packed
                             else
                               link_nodes(to_be_marked, packed, to_be_marked.next)
                             end
                             -- Add attribute to to_be_marked, so that we can
                             -- see it while building the page, and get the
                             -- note.
                             node.set_attribute(to_be_marked, 444, State.max_notes)
                             
                             -- Now, set up the first glyph of the footnote
                             -- to also receive the footnote mark. Here we need
                             -- to search forward using the reader.
                             local pos = pos()
                             local value = read_value()
                             -- We make the (possibly false) assumption that
                             -- the footnote starts with a glyph. There should
                             -- be some way to identify glyphs. What if the
                             -- footnote started with an Emph?
                             replace_text("\\Mark{" .. unicode.utf8.char(value) .. "}", pos, pos)
                             
                             -- Switch to footnote mode, and call main_loop
                             -- to typeset the footnote.
                             State.mode = "footnote"
                             update_state(nil, nil, false, false)
                             push_tbl(footnote_tbl)
                             main.main_loop()
                           end
  State.do_command_start = do_command_start
  local do_command_stop = function()
                            -- We now build the (final) paragraph of the
                            -- footnote and process it (put it in
                            -- State.notes[max_notes]). Note that if the
                            -- footnote contains multiple paragraphs, the
                            -- earlier ones have already been processed.
                            -- Note also that, unlike with Input, where
                            -- main_loop will terminate on eol, and so
                            -- build_par, process_par, and build_pages,
                            -- we have to do some of this now.
                            local head, tail, _, _ = update_locals()
                            tex.baselineskip = make_glue_spec(tex.sp("12pt"))
                            local par = build_par(head, tail)
                            process_par(par)
                            tex.baselineskip = old_baselineskip
                            -- and restore the previous mode, head, and tail.
                            pop_tbl()
                            State.mode = "main_text"
                            update_state(old_head, old_tail, false, false)
                          end
  push_do_command_stop(do_command_stop)
end

register_command("Footnote", do_footnote)


local do_mark = function()

  -- Even though we do nothing in do_command_start, we
  -- must define it, so that upon seeing the "{" main_loop
  -- will know that we are starting a command, and not
  -- entering a new group.
  local do_command_start = function()
                           end
  State.do_command_start = do_command_start
  local do_command_stop  = function()
                             local head, tail, _, _ = update_locals()
                             -- We should have just read the single chararcter
                             -- at the start of the footnote. Therefore head
                             -- and tail should be the same. Check this.
                             assert((head == tail), "Head and tail are not the same.")
                             -- add the mark as in Footnote.
                             local marker = node.hpack(make_glyph(unicode.utf8.byte(tostring(State.max_notes)),
                                                         superscript_font,
                                                         1, 3, 3))
                             local marker_glue = make_glue(0, tex.sp("5pt"))
                             link_nodes(marker, marker_glue)
                             local packed = node.vpack(marker)
                             link_nodes(packed, head)
                             update_state(packed, tail, false, false)
                           end
  push_do_command_stop(do_command_stop)

end

register_command("Mark", do_mark)


local initialize_command = function(command)
  return command_table[command]()
end


local commands = {get_command        = get_command,
                  initialize_command = initialize_command,
                  }


return commands
