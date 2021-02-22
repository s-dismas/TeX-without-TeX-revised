

--- Copyright (c) 2021 by Toadstone Enterprises.
--- ISC-type license, see License.txt for details.


-----------------------------------------------------------------


local util = require("utils")

local node_type        = util.node_type
local link_nodes       = util.link_nodes
local make_glue        = util.make_glue
local make_rule        = util.make_rule


local format = require("format")

local text_height   = format.text_height

local top_margin    = format.top_margin
local left_margin   = format.left_margin

local header_height = format.header_height
local header_sep    = format.header_sep

local footer_height = format.footer_height
local footer_sep    = format.footer_sep

local page_number   = format.page_number

local header_tbl    = format.header_tbl
local footer_tbl    = format.footer_tbl
local push_tbl      = format.push_tbl
local pop_tbl       = format.pop_tbl
local top_tbl       = format.top_tbl


local reader = require("reader")

local push_reader = reader.push_reader
local pop_reader  = reader.pop_reader


local main = main or require("main")

local main_loop = main.main_loop


-----------------------------------------------------------------


local par_height = function(par)
  -- But can really be used on any list of lines including
  -- multiple paragraphs.
  local height = 0
  while par do
    if (node_type(par) == "hlist") then
      height = height + par.height + par.depth
    elseif (node_type(par) == "glue") then
      height = height + par.width
    else
      -- A penalty has zero height, but what else might we find?
      assert((node_type(par) == "penalty"), "Found a: " .. node_type(par))
    end
    par = par.next
  end
  return height
end


local build_par = function(head, tail)
  -- We have a linked list of nodes, starting with head, and ending
  -- with tail. We insert the initial parindent and final penalty
  -- and parfillskip.

  local tbl = top_tbl()

  local n
  if State.first_paragraph_of_chapter then
    -- This is the first paragraph after a title. Do not indent.
    n = make_glue(0, 0)
    State.first_paragraph_of_chapter = false
  else
    --indent.
    n = make_glue(0,
                  tbl.parindent or tex.parindent)
  end
  link_nodes(n, head)
  head = n

  local penalty = node.new("penalty")
  penalty.penalty = 10000

  local parfillskip = make_glue("parfillskip",
                                0,
                                tbl.parfillskipstretch  or 2^16, 0,
                                tbl.parfillskipstretch_order or 2, 0)

  link_nodes(tail, penalty, parfillskip)

  -- hyphenate, kern, and ligature
  lang.hyphenate(head)
  -- With otf fonts, use this rather than kern and ligature.
  nodes.simple_font_handler(head)

  -- and make the paragraph.
  local par = tex.linebreak(head, tbl)

  return par
end


local process_par = function(par)
  -- Move par to the appropriate place, based on State.mode
  
  -- If we want to build pages as we go, instead of in batches,
  -- we can call the page builder from in here.

  local a_par_is_already_there
  if (State.mode == "main_text") then
    a_par_is_already_there = State.main
  elseif (State.mode == "header") then
    a_par_is_already_there = State.header
  elseif (State.mode == "footer") then
    a_par_is_already_there = State.footer
  elseif (State.mode == "footnote") then
    a_par_is_already_there = State.notes[State.max_notes]
  else
    assert(false, "Invalid mode seen in process_par")
  end
  
  if a_par_is_already_there then
  
    -- at least one paragraph has already been processed, so we link
    -- the new par to the old one.
    local tail = node.tail(a_par_is_already_there)
    if ((node_type(tail) == "hlist") and
        (node_type(par)  == "hlist")) then
      -- add tex.baselineskip
      local glue_needed = tex.baselineskip.width - (par.height + tail.depth)
      local n = make_glue("baselineskip",
                          glue_needed)
      link_nodes(tail, n, par)
    else
      -- tail or par is glue?
      assert(((node_type(tail) == "glue") or
              (node_type(par)  == "glue")), "Not glue!")
      -- We assume that this glue is enough.
      link_nodes(tail, par)
    end
    
  else

    -- This is the first par, so we just put it where it belongs.
    if (State.mode == "main_text") then
      State.main = par
    elseif (State.mode == "header") then
      State.header = par
    elseif (State.mode == "footer") then
      State.footer = par
    elseif (State.mode == "footnote") then
      State.notes[State.max_notes] = par
    else
      assert(false, "Invalid mode seen in process_par")
    end
  end
end


local pop_line = function()
  -- Pop the top line from State.main.
  -- This is used by build_page to incrementally build a page.

  if State.main then
    local line = State.main
    State.main = State.main.next
    if State.main then
      State.main.prev = nil
    end
    line.next = nil
    return line
  else
    return nil
  end
end


local return_line = function(line)
  -- Return a (previously popped) line to State.main

  line.next = State.main
  if State.main then
    State.main.prev = line
  end
  State.main = line

end


-----------------------------------------------------------------


--- Now, on to build_page.


local make_header = function()
  -- Make the header

  -- The text of our header.
  -- When we call main_loop, this will be the reader used.
  if State.header_text then
    push_reader(State.header_text)
  else
    push_reader("Header")
  end

  -- This is the tbl that will be used by main_loop.
  push_tbl(header_tbl)
  local old_mode = State.mode
  State.mode = "header"
  -- Now we do the work.
  -- When pages and main became mutually dependant, I had to
  -- prefix main_loop with the package name. Otherwise:
  -- attempt to call a nil value (upvalue 'main_loop')
  -- Similarly in make_footer.
  -- Why is this?
  main.main_loop()
  State.mode = old_mode

  -- Restore the old reader and tbl.
  pop_reader()
  pop_tbl()

  -- We assume that the header is only one line
  local line = State.header
  State.header = nil
  assert((line.next == nil), "Header is not just one line.")

  -- We center the header (vertically) in its header_height box
  local needed_height  = header_height - line.height
  local top_glue       = make_glue(0, needed_height / 2)
  local bot_glue       = make_glue(0, needed_height / 2)

  -- Add a rule
  local header_rule = make_rule("normal", text_width, tex.sp("1pt"))
  header_rule_box   = node.hpack(header_rule)  -- Must hpack. Why?

  -- centered (vertically) in its header_sep height box
  local top_sep_glue = make_glue(0, (header_sep - tex.sp("1pt") / 2))
  local bot_sep_glue = make_glue(0, (header_sep - tex.sp("1pt") / 2))

  -- link it al together
  link_nodes(top_glue, line, bot_glue,
             top_sep_glue, header_rule_box, bot_sep_glue)

  -- and package it up in a vbox
  local header = node.vpack(top_glue)

  return header
end


local make_footer = function()

  -- the text of our footer
  push_reader(tostring(page_number))

  push_tbl(footer_tbl)
  
  local old_mode = State.mode
  State.mode = "footer"
  main.main_loop()
  State.mode = old_mode

  pop_reader()
  pop_tbl()

  local line = State.footer
  State.footer = nil
  assert((line.next == nil), "Footer is not just one line.")

  local needed_height  = footer_height - line.height
  local foot_glue      = make_glue(0, needed_height)

  local sep_glue = make_glue(0, footer_sep)

  link_nodes(sep_glue, foot_glue, line)
  
  local footer = node.vpack(foot_glue)

  return footer
end


local build_page_step_one = function(line)
  -- 1) get the main text from main_text, a line at a time until
  --    we either run out of lines or text_height.

  local head = line
  local tail = line
  local note = nil
  local notes = nil
  local current_height = 0   
  while ((current_height < text_height) and line) do

    if node_type(line) == "hlist" then
      -- See if this line has an associated footnote.
      local v, _ = node.find_attribute(line.head, 444)
      if v then
        -- Get the note, and account for its height.
        note = State.notes[v]
        local extra = par_height(note)
        if notes then
          -- The separation between notes.
          extra = extra + tex.sp("4pt")
        else
          -- The separation before the first note.
          extra = extra + tex.sp("8pt")
        end
        -- Does the line still fit on the page?
        if (current_height + line.height + line.depth + extra) < text_height then
          -- Add the line to the end of the text.
          link_nodes(tail, line)
          tail = line
          current_height = (current_height + line.height + line.depth + par_height(note))
          if notes then
            -- Add the note to the notes.
            local n = make_glue(0, tex.sp("4pt"))
            link_nodes(node.tail(notes), n, note)
          else
            -- This is the first note.
            notes = note
          end
        else
          -- The line plus the note do not fit on the page.
          return_line(line, main_text)
          return current_height, head, tail, notes
        end
      elseif (current_height + line.height + line.depth) < text_height then
        -- We have a line without a note, that fits on the page.
        link_nodes(tail, line)
        tail = line
        current_height = (current_height + line.height + line.depth)
      else
        -- The line does not fit on the page.
        return_line(line, main_text)
        return current_height, head, tail, notes
      end
    elseif node_type(line) == "glue" then
      -- line is glue, not an hlist.
      if (current_height + line.width) < text_height then
        -- line fits on the page.
        link_nodes(tail, line)
        tail = line
        current_height = current_height + line.width
      else
        -- line does not fit on the page.
        return_line(line, main_text)
        return current_height, head, tail, notes
      end
    else
      -- line is neither an hlist nor glue.
      assert((node_type(line) == "penalty"), "Threw away a non-penalty: " .. node_type(line))
    end

    -- Get the next line, and go to the top of the while loop
    line = pop_line()

  end
  return current_height, head, tail, notes
end


local build_page_step_four = function(text_box, notes, header_box, footer_box)
  -- 4) put it all together
  
  local top_margin_glue = make_glue(0, top_margin)

  if State.first_page_of_chapter then
    -- No header
    if notes then
      local n = make_glue(0, tex.sp("8pt"))
      link_nodes(top_margin_glue, text_box, n, notes)
    else
      link_nodes(top_margin_glue, text_box)
    end
    State.first_page_of_chapter = false
  else
    -- Include a header
    if notes then
      local n = make_glue(0, tex.sp("8pt"))
      link_nodes(top_margin_glue, header_box, text_box, n, notes, footer_box)
    else
      link_nodes(top_margin_glue, header_box, text_box, footer_box)
    end
  end

  -- 4a) Finish the assembly of the page, and ship it out.
  
  local main_box = node.vpack(top_margin_glue)

  local left_margin_glue = make_glue(0, left_margin)

  link_nodes(left_margin_glue, main_box)

  local page_box = node.hpack(left_margin_glue)

  tex.setbox(666, page_box)

  tex.shipout(666)

  -- Increment the page counters, both tex's and ours.
  tex.count[0] = tex.count[0] + 1
  page_number = page_number + 1
end


local build_page = function()
  -- Build a page by:
  -- 1) get the main text from main_text, a line at a time until
  --    we either run out of lines or text_height.
  -- 2) pad out the text to fill text_height
  -- 3) make our header and footer
  -- 4) put it all together

  local line = pop_line()
  local current_height = 0
  local head, tail
  local notes

  -- We are at the top of the page, so we throw away anything
  -- that is not an hlist
  while node_type(line) ~= "hlist" do
    print("Throwing away a: " .. node_type(line))
    line = pop_line(main_text)
  end

  -- 1) get the main text from State.text, a line at a time until
  --    we either run out of lines or text_height.
  current_height, head, tail, notes = build_page_step_one(line)  


  -- We have fit all the text that will fit on the page.
  -- 2) pad out the text to fill text_height
  
  if (current_height < text_height) then
    local needed_height = text_height - current_height
    local n = make_glue(0, needed_height)
    link_nodes(tail, n)
  end

  local text_box = node.vpack(head)

  -- 3) make our header and footer

  local header_box = make_header()
  local footer_box = make_footer()

  -- 4) put it all together

  build_page_step_four(text_box, notes, header_box, footer_box)

end


local build_pages = function()
  -- While there is text to fill a page, we build pages.
  while State.main do
    build_page()
  end
end


return {build_par   = build_par,
        process_par = process_par,
        build_pages = build_pages}
