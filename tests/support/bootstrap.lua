local realDofile = dofile

_G.dofile = function(path)
  if path:sub(1, 1) == "/" then
    path = "." .. path
  end
  return realDofile(path)
end
