(entry, item) ->
	kind = require('lspkind').cmp_format({ mode: "symbol_text" })(entry, item)
	strings = vim.split kind.kind, "%s", { trimempty: true }

	--icon = require('lspkind').symbolic(item.kind)
	
	item.kind = " " .. (strings[1] or "") .. " "
	item.menu = "    " .. (strings[2] or "")
	--item.menu_hl_group = "LineNr"

	return item
