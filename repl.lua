--- Copyright (c) 2011-2015 Rob Hoelz <rob@hoelz.ro>
---
--- Further hacked by others.
---
--- Permission is hereby granted, free of charge, to any person
--- obtaining a copy of this software and associated documentation
--- files (the "Software"), to deal in the Software without
--- restriction, including without limitation the rights to use, copy,
--- modify, merge, publish, distribute, sublicense, and/or sell copies
--- of the Software, and to permit persons to whom the Software is
--- furnished to do so, subject to the following conditions:
---
--- The above copyright notice and this permission notice shall be
--- included in all copies or substantial portions of the Software.
---
--- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
--- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
--- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
--- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
--- BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
--- ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
--- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--- SOFTWARE.
---
--- This module implements the core functionality of a REPL.


--- repl() is the REPL.

--- quit() or exit() will terminate the REPL.

--- require("utils") or anything else you will want to use in the
--- REPL as a global, or they will not be visible.

--- Note: The REPL is NOT Unicode aware!


local repl_buffer = ""


local function gather_results(success, ...)
  local n = select("#", ...)
  return success, {n = n, ... }
end


local function detectcontinue(err)
  -- Uses the compilation error to determine whether or not further input
  -- is pending after the last line. That is, is this a fraction of a
  -- statement.
  -- Rather crude, but this seems to work.
  return string.match(err, "'<eof>'$") or string.match(err, "<eof>$")
end


local function compilechunk(chunk)
  -- If this is an expression, rather than a statement, we should
  -- get a function, in f, to return the value of that expression.
  local f, err = load("return " .. chunk, "REPL")
  -- For statements (or fractions thereof).
  if not f then
    f, err = load(chunk, "REPL")
  end
  return f, err
end


local function displayresults(results)
  -- @param results The results to display. The results are a table,
  -- with the integer keys containing the results, and the "n" key
  -- containing the highest integer key.
  if results.n == 0 then return end
  print(table.unpack(results, 1, results.n))
end


local function displayerror(err)
  print(err)
end


local function handleline(line)
  -- Evaluates a line of input, and displays return value(s).
  local chunk  = repl_buffer .. line
  local f, err = compilechunk(chunk)

  if f then
    -- We have a (presumed) function. Try to call it, and display the
    -- results, or error.
    repl_buffer = ""
    local success, results = gather_results(xpcall(f, function(...) return debug.traceback(...) end))
    if success then
      displayresults(results)
    else
      displayerror(results[1])
    end
  elseif detectcontinue(err) then
    -- This is a (presumed) fraction of a statement?
    repl_buffer = chunk .. "\n"
    return 2
  else
    -- An error. Clear the buffer, so this does not keep happening.
    repl_buffer = ""
    displayerror(err)
  end

  return 1
end


local function prompt(level)
  local prompt
  if level == 1 then prompt=">>>" else prompt="..." end
  io.write(prompt)
end


local function repl()
  -- Run a REPL loop in a synchronous fashion.
  print()
  prompt(1)
  for line in io.stdin:lines() do
    if line == "quit()" then
      break
    end
    if line == "exit()" then
      break
    end
    local level = handleline(line)
    prompt(level)
  end
end

return {repl = repl}
