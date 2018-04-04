# Tue 20:48 Jun 21

all: lily

.PHONY: all lily

lily: inspect.lua stringx.lua lfb.lua app.bfbs
	./lily.lua

app.bfbs: app.fbs
	flatc -o . --binary --schema app.fbs

#@flatc -o json_out --json --strict-json --raw-binary reflection.fbs  -- app.bfbs

# --defaults-json

inspect.lua:
	wget https://raw.githubusercontent.com/kikito/inspect.lua/master/inspect.lua

lfb.lua:
	wget https://github.com/DavidFeng/lua-flatbuffers/raw/master/lfb.lua

stringx.lua:
	wget https://github.com/DavidFeng/lua-flatbuffers/raw/master/stringx.lua

