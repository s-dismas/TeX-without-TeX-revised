

--- Everything is global, so that it will be available in the REPL


--- For use in REPL, not used here

util = require("utils")

sp_to_p  = util.sp_to_p
sp_to_in = util.sp_to_in

node_type    = util.node_type
node_subtype = util.node_subtype

link_nodes = util.link_nodes

make_glyph     = util.make_glyph
make_glue      = util.make_glue
make_glue_spec = util.make_glue_spec
make_rule      = util.make_rule
make_penalty   = util.make_penalty

fil   = util.fil
fill  = util.fill
filll = util.filll

is_whitespace         = util.is_whitespace
is_linefeed           = util.is_linefeed
is_nobreak            = util.is_nobreak
is_command_terminator = util.is_command_terminator

copy_table = util.copy_table

read_string = util.read_string
read_group  = util.read_group

walk_table = util.walk_table
show_node  = util.show_node
walk_list  = util.walk_list


--- For use here


repl = require("repl")

repl = repl.repl


reader = require("reader")

push_reader = reader.push_reader


commands = require("commands")


pages = require("pages")

build_pages = pages.build_pages
build_page = pages.build_page


main = require("main")

main_loop = main.main_loop


format = require("format")

main_text_tbl = format.main_text_tbl
push_tbl      = format.push_tbl


--- Do the job


function do_job()
  push_reader("file:text.txt")
  push_tbl(main_text_tbl)
  main_loop()
  build_pages()
end

do_job()


--- Enter REPL for exploration

--- repl()
