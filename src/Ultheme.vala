using Clutter;
using Gee;

errordomain IOError {
    FILE_NOT_FOUND,
    FILE_NOT_VALID_ARCHIVE,
    FILE_NOT_VALID_THEME
}

namespace Ultheme {
    public class HexColorPair {
        public string foreground { get; set; }
        public string background { get; set; }
    }

    public class HexColorPalette {
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
        }
    }

    public class Parser {
        private string _author;
        private string _name;
        private string _version;
        private ThemeColors _dark_theme;
        private ThemeColors _light_theme;
        private File _file;
        private string _xml_buffer;
        private HashMap<string, StyleTargets> _style_map;

        public Parser (File file) throws Error {
            _file = file;
            _xml_buffer = "";
            _author = "Unknown";
            _name = "Unknown";
            _version = "1.0";
            read_archive ();

            if (_xml_buffer == "") {
                throw new IOError.FILE_NOT_VALID_ARCHIVE (
                    "Could not fine Theme.xml in ultheme");
            }

            if (!_xml_buffer.down ().has_prefix ("<?xml")) {
                _xml_buffer = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + _xml_buffer;
            }

            // stdout.// printf("Parsing Document:\n===\n%s\n===\n", _xml_buffer);

            _dark_theme = new ThemeColors ();
            _light_theme = new ThemeColors ();

            // Map from Ultheme item definitions to style names
            _style_map = new HashMap<string, StyleTargets> ();
            _style_map.set ("heading1", new StyleTargets({ "markdown:header", "def:type", "def:heading" }));
            _style_map.set ("codeblock", new StyleTargets({ "markdown:code-block" }));
            _style_map.set ("code", new StyleTargets({ "markdown:code", "def:identifier", "markdown:code-span", "xml:attribute-name" }));
            _style_map.set ("comment", new StyleTargets({ "markdown:backslash-escape", "def:special-char", "def:comment", "xml:attribute-value", }));
            _style_map.set ("blockquote", new StyleTargets({ "markdown:blockquote-marker", "def:shebang", "markdown:blockquote" }));
            _style_map.set ("link", new StyleTargets({ "markdown:link-text", "markdown:url", "markdown:label", "markdown:attribute-value", "def:underlined", "def:preprocessor", "def:constant", "def:net-address", "def:link-destination", "def:type" }));
            _style_map.set ("divider", new StyleTargets({ "markdown:horizontal-rule", "def:note", "markdown:line-break" }));
            _style_map.set ("orderedList", new StyleTargets({ "markdown:list-marker", "def:statement" }));
            _style_map.set ("image", new StyleTargets({ "markdown:image-marker", }));
            _style_map.set ("emph", new StyleTargets({ "markdown:emphasis", "def:doc-comment-element" }));
            _style_map.set ("strong", new StyleTargets({ "markdown:strong-emphasis", "def:statement" }));
            _style_map.set ("delete", new StyleTargets({ "def:deletion" }));

            read_theme ();
        }

        private void read_theme () throws Error {
            GXml.Document doc = new GXml.Document.from_string (_xml_buffer);
            GXml.DomElement theme_root = doc.document_element;
            string? frontmatter = theme_root.get_attribute ("author");
            if (frontmatter != null) {
                _author = frontmatter;
            }

            frontmatter = theme_root.get_attribute ("displayName");
            if (frontmatter != null) {
                _name = frontmatter;
            }

            // https://developer.gnome.org/gtksourceview/stable/style-reference.html
            // Version must be 1.0
            //  frontmatter = theme_root.get_attribute ("version");
            //  if (frontmatter != null) {
            //      _version = frontmatter;
            //  }

            // Read in color palettes
            GXml.DomHTMLCollection palettes = theme_root.get_elements_by_tag_name ("palette");
            if ((palettes.length == 0) || (palettes.length > 2)) {
                throw new IOError.FILE_NOT_VALID_THEME (
                    "Theme has invalid number of palettes");
            }

            GXml.DomHTMLCollection item_definitions = theme_root.get_elements_by_tag_name ("item");
            if ((item_definitions.length == 0) || (item_definitions.length < 8)) {
                throw new IOError.FILE_NOT_VALID_THEME (
                    "Theme is missing markdown style definitions");
            }

            for (int p = 0; p < palettes.length; p += 1) {
                GXml.DomElement palette = palettes.get_element (p);
                string? mode = palette.get_attribute ("mode");
                GXml.DomHTMLCollection colors = palette.get_elements_by_tag_name ("color");

                if ((colors.length == 0) || (colors.length < 4)) {
                    throw new IOError.FILE_NOT_VALID_THEME (
                        "Theme is missing color definitions");
                }

                if ((mode == null) || (mode == "light")) {
                    read_palette (colors, item_definitions, ref _light_theme, "colorsLight");
                } else {
                    read_palette (colors, item_definitions, ref _dark_theme, "colorsDark");
                }
            }
        }

        private void read_palette (
            GXml.DomHTMLCollection colors,
            GXml.DomHTMLCollection item_definitions,
            ref ThemeColors color_theme,
            string color_attr) throws Error 
        {
            // Read the color palette
            for (int c = 0; c < colors.length; c += 1) {
                GXml.DomElement color = colors.get_element (c);
                string? color_value = color.get_attribute ("value");
                if (color_value == null) {
                    throw new IOError.FILE_NOT_VALID_THEME (
                        "Theme is missing value for color");
                }

                // Clutter.Color requires # prefix
                if (!color_value.has_prefix ("#")) {
                    color_value = "#" + color_value;
                }

                Color read_color = Color.from_string (color_value);

                // Default foreground and background are not part of
                // the colors used in the item definitions
                if (color.has_attribute ("identifier")) {
                    string? identifier = color.get_attribute ("identifier");
                    if (identifier.down () == "foreground") {
                        color_theme.foreground = read_color;
                    } else {
                        color_theme.background = read_color;
                    }
                } else {
                    color_theme._colors += read_color;
                }
            }

            // print ("Theme fg: %s, gb: %s\n", color_theme.foreground_color (), color_theme.background_color ());

            // Read the style definitions
            for (int s = 0; s < item_definitions.length; s += 1) {
                GXml.DomElement item = item_definitions.get_element (s);
                string? definition = item.get_attribute ("definition");
                string? color_def = item.get_attribute (color_attr);
                string? traits = item.get_attribute ("traits");
                Attribute attr = new Attribute ();

                if (definition == null) {
                    continue;
                }

                // Set styling
                if (traits.contains ("bold")) {
                    attr.is_bold = true;
                }
                if (traits.contains ("italic")) {
                    attr.is_italic = true;
                }
                if (traits.contains ("strikethrough")) {
                    attr.is_strikethrough = true;
                }
                if (traits.contains ("underline")) {
                    attr.is_underline = true;
                }

                // Color math
                string[] color_opt = color_def.split (";");
                int fg_color = 0;
                int fg_shade = 0;
                int bg_color = -1;
                int bg_shade = -1;

                //
                // Color pairs seem to be text-color;markup-color;text-background
                // Where colors are index,lighten/darken
                // Omission of a pair implies to use the default fg or bg
                //

                bool using2 = false;
                // Check for font color
                if (!read_color (out fg_color, out fg_shade, color_opt[0])
                    || (fg_color < 0 || fg_color >= color_theme._colors.length))
                {
                    // No font color, use symbol color
                    if (!read_color (out fg_color, out fg_shade, color_opt[1]) ||
                        (fg_color < 0 || fg_color >= color_theme._colors.length))
                    {
                        fg_color = -1;
                        fg_shade = 0;
                    } else {
                        using2 = true;
                    }
                }

                // Attempt to set background color
                if ((color_opt.length >= 3 &&
                    !read_color (out bg_color, out bg_shade, color_opt[2]) ||
                    (bg_color < 0 || bg_color >= color_theme._colors.length)))
                {
                    bg_color = -1;
                    bg_shade = 0;
                }

                // Prevent colors that are too close
                if (!using2 || (fg_color == bg_color && fg_shade == bg_shade)) {
                    if (color_opt.length >= 2 &&
                        !read_color (out bg_color, out bg_shade, color_opt[1]) ||
                        (fg_color == bg_color && fg_shade == bg_shade))
                    {
                        bg_color = -1;
                        bg_shade = 0;
                    }
                    else
                    {
                        if (bg_shade > 0)
                        {
                            bg_shade *= -1;
                        }
                    }
                }

                if (color_opt[2] == "") {
                    bg_color = -1;
                }

                Color foreground = color_theme.foreground;
                Color background = color_theme.background;
                // Check for using default
                if (fg_color >= 0 && fg_color < color_theme._colors.length) {
                    foreground = make_color (color_theme._colors[fg_color], fg_shade, color_theme.background, color_attr.down ().contains ("dark"), false);
                }
                if (bg_color >= 0 && bg_color < color_theme._colors.length) {
                    background = make_color (color_theme._colors[bg_color], bg_shade, color_theme.background, color_attr.down ().contains ("dark"), true);
                }

                attr.foreground = foreground;
                attr.background = background;

                color_theme.elements.set (definition, attr);
            }
        }

        private Color make_color (Color original, int shade, Color theme_bg, bool lighten, bool is_bg) {
            Color res = original;

            if (shade >= 0) {
                while (shade > 0) {
                    if (lighten) {
                        res = res.lighten ();
                    } else {
                        res = res.darken ();
                    }
                    shade -= 2;
                }
            } else {
                // shade = 5 - shade;
                double progress = ((double) (shade.abs ())) / 6.0;
                res = res.interpolate (theme_bg, progress);
            }

            return res;
        }

        private bool read_color (out int color, out int shade, string option) {
            bool res = true;
            color = -1;
            shade = 0;
            if (option == null || option == "" || !option.contains (",")) {
                return false;
            }

            string[] color_prop = option.split (",");
            if (color_prop.length < 2) {
                return false;
            }

            res = res && int.try_parse (color_prop[0], out color);
            res = res && int.try_parse (color_prop[1], out shade);

            return res;
        }

        private void read_archive () throws Error {
            if (!_file.query_exists ()) {
                throw new IOError.FILE_NOT_FOUND (
                    "Could not find %s for reading",
                    _file.get_path ());
            }

            // Open ultheme for reading.
            var archive = new Archive.Read ();
            throw_on_failure (archive.support_filter_all ());
            throw_on_failure (archive.support_format_all ());
            throw_on_failure (archive.open_filename (_file.get_path (), 10240));

            // Browse files in archive.
            unowned Archive.Entry entry;
            while (archive.next_header (out entry) == Archive.Result.OK) {
                // Extract theme into memory
                if (entry.pathname ().has_suffix ("Theme.xml")){
                    uint8[] buffer = null;
                    Posix.off_t offset;
                    string xml_buffer = "";
                    while (archive.read_data_block (out buffer, out offset) == Archive.Result.OK) {
                        if (buffer == null) {
                            break;
                        }
                        if (buffer[buffer.length - 1] != 0) {
                            buffer += 0;
                        }
                        xml_buffer += (string)buffer;
                    }

                    _xml_buffer = xml_buffer;
                    break;
                } else {
                    archive.read_data_skip ();
                }
            }

            archive.close ();
        }

        public string get_theme_name () {
            return _name;
        }

        public string get_dark_theme () throws Error {
            return build_style ("Dark", _dark_theme, false);
        }

        public string get_dark_theme_id () {
            return "ulv-" + _name.down () + "-dark";
        }

        public void get_dark_theme_palette (out HexColorPalette palette) {
            build_color_palette (out palette, _dark_theme, false);
        }

        public string get_light_theme () throws Error {
            return build_style ("Light", _light_theme, true);
        }

        public string get_light_theme_id () {
            return "ulv-" + _name.down () + "-light";
        }

        public void get_light_theme_palette (out HexColorPalette palette) {
            build_color_palette (out palette, _light_theme, true);
        }

        private void build_color_palette (out HexColorPalette palette, ThemeColors colors, bool darken) {
            palette = new HexColorPalette ();
            palette.global.foreground = colors.foreground_color ();
            palette.global.background = colors.background_color ();
            palette.global_active.foreground = colors.selection_fg_color (darken, 1);
            palette.global_active.background = colors.selection_bg_color (darken, 1);
            if (colors.elements.has_key ("heading1")) {
                Attribute attr = colors.elements.get ("heading1");
                palette.headers.foreground = attr.foreground_color ();
                palette.headers.background = attr.background_color ();
            }

            if (colors.elements.has_key ("codeblock")) {
                Attribute attr = colors.elements.get ("codeblock");
                palette.code_block.foreground = attr.foreground_color ();
                palette.code_block.background = attr.background_color ();
            }

            if (colors.elements.has_key ("code")) {
                Attribute attr = colors.elements.get ("code");
                palette.inline_code.foreground = attr.foreground_color ();
                palette.inline_code.background = attr.background_color ();
            }

            if (colors.elements.has_key ("comment")) {
                Attribute attr = colors.elements.get ("comment");
                palette.escape_char.foreground = attr.foreground_color ();
                palette.escape_char.background = attr.background_color ();
            }

            if (colors.elements.has_key ("blockquote")) {
                Attribute attr = colors.elements.get ("blockquote");
                palette.blockquote.foreground = attr.foreground_color ();
                palette.blockquote.background = attr.background_color ();
            }

            if (colors.elements.has_key ("link")) {
                Attribute attr = colors.elements.get ("link");
                palette.link.foreground = attr.foreground_color ();
                palette.link.background = attr.background_color ();
            }

            if (colors.elements.has_key ("divider")) {
                Attribute attr = colors.elements.get ("divider");
                palette.divider.foreground = attr.foreground_color ();
                palette.divider.background = attr.background_color ();
            }

            if (colors.elements.has_key ("orderedList")) {
                Attribute attr = colors.elements.get ("orderedList");
                palette.list_marker.foreground = attr.foreground_color ();
                palette.list_marker.background = attr.background_color ();
            }

            if (colors.elements.has_key ("image")) {
                Attribute attr = colors.elements.get ("image");
                palette.image_marker.foreground = attr.foreground_color ();
                palette.image_marker.background = attr.background_color ();
            }

            if (colors.elements.has_key ("strong")) {
                Attribute attr = colors.elements.get ("strong");
                palette.strong.foreground = attr.foreground_color ();
                palette.strong.background = attr.background_color ();
            }

            if (colors.elements.has_key ("emph")) {
                Attribute attr = colors.elements.get ("emph");
                palette.emphasis.foreground = attr.foreground_color ();
                palette.emphasis.background = attr.background_color ();
            }
        }

        private string build_style (
            string name_suffix,
            ThemeColors colors,
            bool darken_selection) throws Error {
            // print ("Generating theme\n");
            GXml.DomDocument res = new GXml.Document ();

            // Create scheme
            // print ("Creating root\n");
            GXml.DomElement root = res.create_element ("style-scheme");
            root.set_attribute ("id", "ulv-" + _name.down () + "-" + name_suffix.down ());
            root.set_attribute ("name", _name + "-" + name_suffix + "-ulv");
            root.set_attribute ("version", _version);
            res.append_child (root);

            // Add frontmatter
            // print ("Adding frontmatter\n");
            GXml.DomElement author = res.create_element ("author");
            GXml.DomText author_text = res.create_text_node (_author);
            author.append_child (author_text);
            root.append_child (author);

            GXml.DomElement description = res.create_element ("description");
            GXml.DomText description_text = res.create_text_node (
                "Style Scheme converted from Ulysses Theme " + _name
            );
            description.append_child (description_text);
            root.append_child (description);

            // Set default colors
            GXml.DomElement text = res.create_element ("style");
            text.set_attribute ("name", "text");
            text.set_attribute ("foreground", colors.foreground_color ());
            text.set_attribute ("background", colors.background_color ());
            root.append_child (text);

            // Come up with additional stylings not in file
            GXml.DomElement selection = res.create_element ("style");
            selection.set_attribute ("name", "selection");
            selection.set_attribute ("foreground", colors.selection_fg_color (darken_selection, 1));
            selection.set_attribute ("background", colors.selection_bg_color (darken_selection, 1));
            root.append_child (selection);

            GXml.DomElement current_line = res.create_element ("style");
            current_line.set_attribute ("name", "current-line");
            current_line.set_attribute ("background", colors.selection_bg_color (darken_selection, 1));
            root.append_child (current_line);

            GXml.DomElement cursor = res.create_element ("style");
            cursor.set_attribute ("name", "cursor");
            cursor.set_attribute ("foreground", colors.cursor_color ());
            root.append_child (cursor);

            // Add markdown stylings
            // print ("Converting style definitions\n");
            foreach (var entry in colors.elements) {
                // print ("Checking %s\n", entry.key);
                if (_style_map.has_key (entry.key))
                {
                    // print ("Creating comment for %s\n", entry.key);
                    GXml.DomComment comment = res.create_comment ("Using " + entry.key + " for style");
                    Attribute apply_attribute = entry.value;
                    root.append_child (comment);
                    foreach (var apply in _style_map.get (entry.key).targets) {
                        // print ("Converting %s\n", entry.key);
                        GXml.DomElement style = res.create_element ("style");
                        style.set_attribute ("name", apply);
                        apply_attribute.add_attributes (ref style);

                        if (entry.key.contains ("head")) {
                            style.set_attribute ("scale", "large");
                        }

                        root.append_child (style);
                    }
                }
            }

            // print ("Writing theme output\n");

            return ((GXml.Document) res).write_string ();
        }

        private void throw_on_failure (Archive.Result res) throws Error {
            if ((res == Archive.Result.OK) ||
                (res == Archive.Result.WARN)) {
                return;
            }

            throw new IOError.FILE_NOT_VALID_ARCHIVE(
                "Could not read ultheme");
        }

        private class Attribute {
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

            public void add_attributes (ref GXml.DomElement elem) {
                try {
                    if (is_bold) {
                        elem.set_attribute ("bold", "true");
                    }

                    if (is_italic) {
                        elem.set_attribute ("italic", "true");
                    }

                    if (is_underline) {
                        elem.set_attribute ("underline", "true");
                        elem.set_attribute ("underline-color", foreground_color ());
                    }

                    if (is_strikethrough) {
                        elem.set_attribute ("strikethrough", "true");
                    }

                    elem.set_attribute ("background", background_color ());
                    elem.set_attribute ("foreground", foreground_color ());
                } catch (Error e) {
                    warning ("Could not set attributes: %s", e.message);
                }
            }
        }

        private class ThemeColors {
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

            public string heading_color () {
                foreach (var entry in elements) {
                    if (entry.key.has_prefix ("heading")) {
                        return entry.value.foreground_color ();
                    }
                }

                return foreground_color ();
            }
        }

        private class StyleTargets {
            public string[] targets;
            public StyleTargets (string[] classes) {
                targets = classes;
            }
        }
    }
}
