wezterm = require 'wezterm'

smart_splits = wezterm.plugin.require 'https://github.com/mrjones2014/smart-splits.nvim'

wezterm.on 'update-status', (window, pane) ->
    meta = pane\get_metadata() or {}
    process = pane\get_foreground_process_info()
    overrides = window\get_config_overrides() or {}

    if meta.password_input
        overrides.cursor_blink_ease_in  = "EaseIn"
        overrides.cursor_blink_ease_out = "EaseOut"
		overrides.cursor_blink_rate     = 1000
    else
        overrides.cursor_blink_ease_in  = nil
        overrides.cursor_blink_ease_out = nil
		overrides.cursor_blink_rate     = nil

    if string.find(string.lower(process.name), "craftos") or string.find(string.lower(process.executable), "craftos")
        for arg in *process.argv
            if arg == '-c' or arg == '--cli'
                overrides.colors = {
                    background: '#0d0d0d'
                }
                overrides.font = wezterm.font_with_fallback{
                    'Monocraft'
                }
                overrides.enable_scroll_bar = false
                break
    else
        overrides.colors = nil
        overrides.font = nil
        overrides.enable_scroll_bar = nil

	if string.find(string.lower(process.name), "nvim") or string.find(string.lower(process.executable), "nvim")
		overrides.use_resize_increments = true
		overrides.enable_scroll_bar = false
		overrides.window_background_opacity = 1.0
		overrides.window_padding = {
			left: 0
			right: 0
			top: 0
			bottom: 0
		}
	else
		overrides.use_resize_increments = nil
		overrides.enable_scroll_bar = nil
		overrides.window_background_opacity = nil
		overrides.window_padding = nil


    window\set_config_overrides(overrides)

colour_schemes_dir = '/colour_schemes'

config = if wezterm.config_builder
	wezterm.config_builder()
else
	{}

with config
	.color_schemes = {}

	for file in *wezterm.read_dir(wezterm.config_dir .. colour_schemes_dir)
		name = file\sub(#wezterm.config_dir+#colour_schemes_dir+2, -5)
		.color_schemes[name] = require(file\sub(#wezterm.config_dir+2, -5))

for k, v in pairs require 'config'
	config[k] = v

smart_splits.apply_to_config config, {
	direction_keys: {"LeftArrow", "DownArrow", "UpArrow", "RightArrow"}
	modifiers: {
		move: "SHIFT"
		resize: "ALT"
	}
}

return config
