using Clutter;
using Gee;

namespace Ultheme {
    private class ThemeColors : Object {
        public bool valid;
        public Color foreground;
        public Color background;
        public Color[] _colors;
        public HashMap<string, Attribute> elements;

        public ThemeColors () {
            valid = false;
            elements = new HashMap<string, Attribute> ();
        }

        public string foreground_color () {
            string fg = foreground.to_string ();
            fg = fg.substring (0, 7);
            return fg;
        }

        public string background_color () {
            string bg = background.to_string ();
            bg = bg.substring (0, 7);
            return bg;
        }

        public string selection_bg_color (bool darken, int how_much = 1) {
            Color selection = background;

            while (how_much != 0) {
                if (darken) {
                    selection = selection.darken ();
                } else {
                    selection = selection.lighten ();
                }
                how_much--;
            }

            string sc = selection.to_string ();
            sc = sc.substring (0, 7);
            return sc;
        }

        public string selection_fg_color (bool darken, int how_much = 1) {
            Color selection = foreground;

            while (how_much != 0) {
                if (darken) {
                    selection = selection.darken ();
                } else {
                    selection = selection.lighten ();
                }
                how_much--;
            }

            string sc = selection.to_string ();
            sc = sc.substring (0, 7);
            return sc;
        }

        public string cursor_color () {
            foreach (var entry in elements) {
                if (entry.key.has_prefix ("heading")) {
                    return entry.value.foreground_color ();
                }
            }

            return foreground_color ();
        }
    }

    private class Attribute : Object {
        public Color foreground;
        public Color background;
        public bool is_bold;
        public bool is_italic;
        public bool is_underline;
        public bool is_strikethrough;

        public Attribute () {
            is_bold = false;
            is_italic = false;
            is_underline = false;
            is_strikethrough = false;
        }

        public string foreground_color () {
            string fg = foreground.to_string ();
            fg = fg.substring (0, 7);
            return fg;
        }

        public string background_color () {
            string bg = background.to_string ();
            bg = bg.substring (0, 7);
            return bg;
        }

        public void add_attributes (ref Xml.Node* elem) {
            if (is_bold) {
                elem->new_prop ("bold", "true");
            }

            if (is_italic) {
                elem->new_prop ("italic", "true");
            }

            if (is_underline) {
                elem->new_prop ("underline", "true");
                elem->new_prop ("underline-color", foreground_color ());
            }

            if (is_strikethrough) {
                elem->new_prop ("strikethrough", "true");
            }

            elem->new_prop ("foreground", foreground_color ());
            if (background.alpha != 0) {
                elem->new_prop ("background", background_color ());
            }
        }
    }

    private class StyleTargets : Object {
        public string[] targets;
        public StyleTargets (string[] classes) {
            targets = classes;
        }
    }

    public class HexColorPair : Object {
        public string foreground { get; set; }
        public string background { get; set; }
    }

    public class HexColorPalette : Object {
        public HexColorPair global { get; set; }
        public HexColorPair global_active { get; set; }
        public HexColorPair headers { get; set; }
        public HexColorPair code_block { get; set; }
        public HexColorPair inline_code { get; set; }
        public HexColorPair escape_char { get; set; }
        public HexColorPair blockquote { get; set; }
        public HexColorPair link { get; set; }
        public HexColorPair divider { get; set; }
        public HexColorPair list_marker { get; set; }
        public HexColorPair image_marker { get; set; }
        public HexColorPair emphasis { get; set; }
        public HexColorPair strong { get; set; }
        public HexColorPair deletion { get; set; }

        public HexColorPalette () {
            global = new HexColorPair ();
            global_active = new HexColorPair ();
            headers = new HexColorPair ();
            code_block = new HexColorPair ();
            inline_code = new HexColorPair ();
            escape_char = new HexColorPair ();
            blockquote = new HexColorPair ();
            link = new HexColorPair ();
            divider = new HexColorPair ();
            list_marker = new HexColorPair ();
            image_marker = new HexColorPair ();
            emphasis = new HexColorPair ();
            strong = new HexColorPair ();
            deletion = new HexColorPair ();
        }
    }
}