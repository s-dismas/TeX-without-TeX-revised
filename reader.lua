

--- Copyright (c) 2021 by Toadstone Enterprises.
--- ISC-type license, see License.txt for details.


-----------------------------------------------------------------


--- We maintain a stack of 'readers'.
--- push_reader will push a new 'reader' onto the stack, and
--- pop_reader will pop it. push_reader should be given a string or a
--- filename (of the form "file:filename") If a string is passed in,
--- its contents will be used by the 'reader'.  If a filename is
--- passed in, the file will be read, and its contents will form the
--- contents of the 'reader'.
--- The top 'reader' is the current one, and read_value will return a
--- char (really a Unicode integer value) from that 'reader'.


-----------------------------------------------------------------


--- The index of the current 'reader'. No 'readers' yet.

local n = 0


local explode = function(s)
  -- This is the lower level function used by push_reader to create
  -- a 'reader'.
  --
  -- Take the string s, and break it into unicode values (integers)
  -- and place these into the table, text, indexed by position.
  -- text.max is the maximum index.
  -- text.pos is the current position to be read from. Initially the
  -- start of the text.
  
  assert((type(s) == "string"),
         "explode was given a " .. type(s) .. " instead of a string.")
  local text = {}
  local i = 0
  
  for v in string.utfvalues(s) do
    i = i + 1
    text[i] = v
  end
  
  text.max = i
  text.pos = 1
  return text
end


local push_reader = function(data)
  -- Create a 'reader'. That is, use explode to create a table
  -- containing the text from data (either a file pointer or the
  -- text itself). Then place this table into the next index of
  -- the 'reader' table, Reader, in the next available index.
  
  local text

  assert((type(data) == "string"), "Bad arg to push_reader.")
  
  if (unicode.utf8.sub(data, 1, 5) == "file:") then
    local f = io.open(unicode.utf8.sub(data, 6, -1))
    assert(f, "File " .. unicode.utf8.sub(data, 6, -1) .. "failed to open.")
    text = f:read("a")
  else
    text = data
  end

  local reader = explode(text)

  n = n + 1
  Reader[n] = reader

end


local pop_reader = function()
  -- Remove the currently active 'reader' from Reader.
  
  assert((n > 0), "No reader to pop!")

  Reader[n] = nil
  n = n - 1
  
end
 

local read_value = function()
  -- Get the char (a Unicode integer) from the currenly active
  -- 'reader'.
  
  local value
  
  assert((n > 0), "No reader to read from!")
  
  local reader = Reader[n]
  local max = reader.max
  local pos = reader.pos
  
  if (pos <= max) then
    value = reader[pos]
  else
    -- We are already at the end.
    return nil
  end
  
  reader.pos = pos + 1
  return value
end


local unread_value = function()
  -- Back the indexed position of the currently active 'reader'
  -- by one.
  
  assert((n > 0), "No reader to unread to!")
  
  local reader = Reader[n]
  local pos = reader.pos
  
  assert((pos > 1), "Already at start of text!")
  
  reader.pos = pos - 1
end


local replace_text = function(text, start, stop)
  -- Insert some text (a string) into the current 'reader' replacing
  -- the text from the indices start to stop, and reset the 'reader'
  -- to the beginning of inserted text
  -- There are three special cases,
  -- 1. prepend some text, before any reading
  -- 2. insert without replacing any text
  -- 3. deleting text, without inserting
  -- These can be handled by using
  -- 1. start = 0, stop = -1
  -- 2. stop = start -1
  -- 3. text = ""
  
  assert((n > 0), "No reader to replace text in!")
  local reader = Reader[n]
  local max = reader.max

  assert((type(text) == "string"), "Text is not a string!")
  assert((start >= 0), "Start must be a non-negative integer")
  assert((stop <= max), "Stop must be less than max")

  local insert = explode(text)
  local difference = insert.max - (stop - start + 1)

  if (difference > 0) then
    -- move up
    for i = max, stop + 1, -1 do
      reader[i + difference] = reader[i]
    end
  elseif (difference < 0) then
    -- move down
    for i = stop + 1, max do
      reader[i + difference] = reader[i]
    end
  end
  
  -- insert
  -- If we are prepending some text (special case 1. above)
  -- we need to reset start from 0 to 1.
  if (start == 0) then start = 1 end
  for i = 1, insert.max do
    reader[start + i - 1] = insert[i]
  end

  reader.max = reader.max + difference
  reader.pos = start
end


local pos = function()
  -- Return the position of the current 'reader'.

  assert((n > 0), "No reader to replace text in!")
  local reader = Reader[n]

  return reader.pos

end


Reader = {push_reader   = push_reader,
          pop_reader    = pop_reader,
          read_value    = read_value,
          unread_value  = unread_value,
          replace_text  = replace_text,
          pos           = pos,}


return Reader
