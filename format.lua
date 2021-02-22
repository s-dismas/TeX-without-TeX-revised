

--- Copyright (c) 2021 by Toadstone Enterprises.
--- ISC-type license, see License.txt for details.


-----------------------------------------------------------------


local util = require("utils")

local filll = util.filll


-----------------------------------------------------------------


--- Page Layout


-- This should be set based on the current font!
tex.baselineskip = tex.sp("14pt")

-- set tex's margins to the edge of the page, so that we can define
-- our own page layout more easily
tex.hoffset = tex.sp("-1.in")
tex.voffset = tex.sp("-1.in")


-- American paper size. USA!
local paper_width  = tex.sp("8.5in")
local paper_height = tex.sp("11in")

local top_margin    = tex.sp("0.75in")
local right_margin  = tex.sp("0.75in")
local bottom_margin = tex.sp("0.75in")
local left_margin   = tex.sp("0.75in")

-- header_height is the height of the header box, and it is
-- separated from the main text box by header_sep.
local header_height = tex.sp("0.5in")
local header_sep    = tex.sp("0.25in")

local footer_height = tex.sp("0.5in")
local footer_sep    = tex.sp("0.25in")

-- The main text box.
local text_width  = paper_width - (right_margin + left_margin)
local text_height = paper_height - (top_margin +
                                    header_height + header_sep +
                                    footer_height + footer_sep +
                                    bottom_margin)


local page_number = 1


-----------------------------------------------------------------


--- We define all the fonts we will be using here.
--- This requires the luatex-plain format, or (untested) luaotfload.

-- fonts.definers.read returns a table representing the font.
-- font.define ties this font to an integer which we can use to refer
-- to the desired font.

local main_text_font_table   = fonts.definers.read("lmroman12-regular.otf:mode=node;liga=true;kern=true;", tex.sp("12pt"))
local main_text_font         = font.define(main_text_font_table)

local emph_text_font_table   = fonts.definers.read("lmroman12-italic.otf:mode=node;liga=true;kern=true;", tex.sp("12pt"))
local emph_text_font         = font.define(emph_text_font_table)

local bold_text_font_table   = fonts.definers.read("lmroman12-bold.otf:mode=node;liga=true;kern=true;", tex.sp("12pt"))
local bold_text_font         = font.define(bold_text_font_table)

local title_font_table   = fonts.definers.read("lmroman17-regular.otf:mode=node;liga=true;kern=true;", tex.sp("17pt"))
local title_font         = font.define(title_font_table)

local header_font_table      = fonts.definers.read("lmroman12-regular.otf:mode=node;liga=true;kern=true;", tex.sp("12pt"))
local header_font            = font.define(header_font_table)

local footer_font_table      = fonts.definers.read("lmroman12-regular.otf:mode=node;liga=true;kern=true;", tex.sp("12pt"))
local footer_font            = font.define(footer_font_table)

local footnote_font_table    = fonts.definers.read("lmroman10-regular.otf::mode=node;liga=true;kern=true;", tex.sp("10pt"))
local footnote_font          = font.define(footnote_font_table)

-- For the footnote markers.
local superscript_font_table = fonts.definers.read("lmroman7-regular.otf:mode=node;liga=true;kern=true;", tex.sp("7pt"))
local superscript_font       = font.define(superscript_font_table)


-----------------------------------------------------------------


--- This is the state that we will be passing around as we typeset.

State = {-- What are we typesetting now?
         -- One of "main_text", "header", "footer", or "footnote"
         mode = "main_text",

         -- Where we will store the main text as we build our paragraphs.
         main   = nil,
         -- Where we store the header and footer, as we build them.
         header = nil,
         footer = nil,
         -- We use a table of notes, indexed by footnote number
         max_notes = 0,
         notes     = {},

         -- We store some of main_loops local variables, so that we
         -- can pass them around as needed.
         head          = nil,
         tail          = nil,
         eat_the_white = false,
         eol_seen      = false,

         -- We want to be able to use different parameters for typesetting
         -- the different pieces of text. A header is not the same as a
         -- footnote. We therefore keep a stack of tbls containing the
         -- settings for formatting a paragraph (these are passed to
         -- tex.linebreak).
         max_tbls = 0,
         tbls     = {},

         -- When we see a command, do_command_start will (potentially)
         -- be filled in with the part of the command to do upon
         -- encountering a "{"
         do_command_start     = nil,
         -- And a stack of do_command_stops: do_command_stops
         -- We need a stack, because commands can be nested.
         -- e.g., an Emph inside a Bold.
         -- We need only one do_command_start, because that is for
         -- the current command and the next "{" seen.
         max_do_command_stops = 0,
         do_command_stops     = {},

         -- A place to store the text to be made into the header.
         header_text = nil,

         -- So we can format the first paragraph of a chapter
         -- differently from the rest.
         first_paragraph_of_chapter = false,
         -- So we can format the first page of a chapter
         -- differently from the rest.
         first_page_of_chapter      = false,
        }


local main_text_tbl = {hsize = text_width,

                       parindent                = tex.parindent,
                       parfillskipstretch       = 2^16,
                       parfillskipstretch_order = 2,

                       font           = main_text_font,
                       space          = font.fonts[main_text_font].parameters.space,
                       space_stretch  = font.fonts[main_text_font].parameters.space_stretch,
                       space_shrink   = font.fonts[main_text_font].parameters.space_shrink,

                       lang           = tex.language,
                       lefthyphenmin  = tex.lefthyphenmin,
                       righthyphenmin = tex.righthyphenmin,
                      }


local header_tbl = {hsize = text_width,

                    -- The header will be centered.
                    leftskip                 = filll(),
                    rightskip                = filll(),
                    parindent                = 0,
                    parfillskipstretch       = 2^16,
                    parfillskipstretch_order = 2,

                    font           = header_font,
                    space          = font.fonts[header_font].parameters.space,
                    space_stretch  = font.fonts[header_font].parameters.space_stretch,
                    space_shrink   = font.fonts[header_font].parameters.space_shrink,
                          
                    lang           = tex.language,
                    lefthyphenmin  = tex.lefthyphenmin,
                    righthyphenmin = tex.righthyphenmin,
                   }

local footer_tbl = {hsize = text_width,
                
                    leftskip                 = filll(),
                    rightskip                = filll(),
                    parindent                = 0,
                    parfillskipstretch       = 2^16,
                    parfillskipstretch_order = 2,

                    font           = footer_font,
                    space          = font.fonts[footer_font].parameters.space,
                    space_stretch  = font.fonts[footer_font].parameters.space_stretch,
                    space_shrink   = font.fonts[footer_font].parameters.space_shrink,
                          
                    lang           = tex.language,
                    lefthyphenmin  = tex.lefthyphenmin,
                    righthyphenmin = tex.righthyphenmin,
                   }


local footnote_tbl = {hsize = text_width,
                
                       parindent                = 0,
                       parfillskipstretch       = 2^16,
                       parfillskipstretch_order = 2,

                       font           = footnote_font,
                       space          = font.fonts[footnote_font].parameters.space,
                       space_stretch  = font.fonts[footnote_font].parameters.space_stretch,
                       space_shrink   = font.fonts[footnote_font].parameters.space_shrink,
                          
                       lang           = tex.language,
                       lefthyphenmin  = tex.lefthyphenmin,
                       righthyphenmin = tex.righthyphenmin,
                      }


local update_state = function(head, tail, eat_the_white, eol_seen)
  -- As we pass the State around, we wil want to pass along the
  -- current values of head, tail, eat_the_white, and eol_seen.
  -- See main_loop and the commands for examples.
  State.head          = head
  State.tail          = tail
  State.eat_the_white = eat_the_white
  State.eol_seen      = eol_seen
end


local update_locals = function()
  -- As we return from calls in which we passed the State out, the
  -- values of head, tail, eat_the_white, and eol_seen may have been
  -- changed. So we update them from the current State. See main_loop
  -- and the commands for examples.
  local head          = State.head
  local tail          = State.tail
  local eat_the_white = State.eat_the_white
  local eol_seen      = State.eol_seen
  return head, tail, eat_the_white, eol_seen
end


local push_tbl = function(tbl)
  local max           = State.max_tbls
  State.max_tbls      = max + 1
  State.tbls[max + 1] = tbl
end


local pop_tbl = function()
  local max       = State.max_tbls
  if (max > 0) then
    local tbl = State.tbls[max]
    State.tbls[max] = nil
    State.max_tbls  = max - 1
    return tbl
  else
    return nil
  end
end


local top_tbl = function()
  local max       = State.max_tbls
  if (max > 0) then
    return State.tbls[max]
  else
    return nil
  end
end


local push_do_command_stop = function(do_command_stop)
  local max                       = State.max_do_command_stops
  State.max_do_command_stops      = max + 1
  State.do_command_stops[max + 1] = do_command_stop
end


local pop_do_command_stop = function()
  local max                     = State.max_do_command_stops
  if (max > 0) then
    local do_command_stop       = State.do_command_stops[max]
    State.do_command_stops[max] = nil
    State.max_do_command_stops  = max - 1
    return do_command_stop
  else
    return nil
  end
end


local format = {paper_width  = paper_width,
                paper_height = paper_height,
                
                top_margin    = top_margin,
                right_margin  = right_margin,
                bottom_margin = bottom_margin,
                left_margin   = left_margin,
                header_height = header_height,
                header_sep    = header_sep,
                footer_height = footer_height,
                footer_sep    = footer_sep,
                text_width    = text_width,
                text_height   = text_height,
                
                page_number = page_number,

                update_state         = update_state,
                update_locals        = update_locals,
                push_tbl             = push_tbl,
                pop_tbl              = pop_tbl,
                top_tbl              = top_tbl,
                push_do_command_stop = push_do_command_stop,
                pop_do_command_stop  = pop_do_command_stop,
                
                main_text_tbl = main_text_tbl,
                header_tbl    = header_tbl,
                footer_tbl    = footer_tbl,
                footnote_tbl  = footnote_tbl,

                main_text_font   = main_text_font,
                emph_text_font   = emph_text_font,
                bold_text_font   = bold_text_font,
                title_font       = title_font,
                header_font      = header_font,
                footer_font      = footer_font,
                footnote_font    = footnote_font,
                superscript_font = superscript_font,
               }

return format
