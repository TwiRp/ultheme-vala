using Clutter;
using Gee;

errordomain IOError {
    FILE_NOT_FOUND,
    FILE_NOT_VALID_ARCHIVE,
    FILE_NOT_VALID_THEME
}

namespace Ultheme {
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

        public string base_file_name () {
            return _file.get_basename ();
        }

        private void read_theme () throws Error {
            Xml.Doc* doc = Xml.Parser.parse_memory (_xml_buffer, _xml_buffer.length);
            Xml.Node* theme_root = doc->get_root_element ();
            string? frontmatter = theme_root->get_prop ("author");
            if (frontmatter != null) {
                _author = frontmatter;
            }

            frontmatter = theme_root->get_prop ("displayName");
            if (frontmatter != null) {
                _name = frontmatter;
            }

            // https://developer.gnome.org/gtksourceview/stable/style-reference.html
            // Version must be 1.0
            //  frontmatter = theme_root->get_prop ("version");
            //  if (frontmatter != null) {
            //      _version = frontmatter;
            //  }

            int read_in = 0;
            for (Xml.Node* iter = theme_root->children; iter != null; iter = iter->next) {
                if (iter->type == Xml.ElementType.ELEMENT_NODE) {
                    if (iter->name == "palette") {
                        string? mode = iter->get_prop ("mode");
                        read_in++;
                        if ((mode == null) || (mode == "light")) {
                            read_palette (iter->children, theme_root, ref _light_theme, "colorsLight");
                        } else {
                            read_palette (iter->children, theme_root, ref _dark_theme, "colorsDark");
                        }
                    }
                }
            }

            delete doc;
        }

        private void read_palette (
            Xml.Node* colors,
            Xml.Node* root,
            ref ThemeColors color_theme,
            string color_attr) throws Error 
        {
            // Read the color palette
            for (Xml.Node* color = colors; color != null; color = color->next) {
                if (color->type == Xml.ElementType.ELEMENT_NODE) {
                    if (color->name == "color") {
                        string? color_value = color->get_prop ("value");
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
                        string? identifier = color->get_prop ("identifier");
                        if (identifier != null) {
                            if (identifier.down () == "foreground") {
                                color_theme.foreground = read_color;
                            } else {
                                color_theme.background = read_color;
                            }
                        } else {
                            color_theme._colors += read_color;
                        }
                    }
                }
            }

            // print ("Theme fg: %s, gb: %s\n", color_theme.foreground_color (), color_theme.background_color ());

            // Read the style definitions
            for (Xml.Node* item = root->children; item != null; item = item->next) {
                if (item->type == Xml.ElementType.ELEMENT_NODE) {
                    if (item->name == "item") {
                        string? definition = item->get_prop ("definition");
                        string? color_def = item->get_prop (color_attr);
                        string? traits = item->get_prop ("traits");
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
                        if (fg_color == bg_color && fg_shade == bg_shade) {
                            bg_color = -1;
                            bg_shade = 0;
                        }

                        if (definition == "link" || definition == "blockquote") {
                            if (bg_shade < 0 && bg_shade > -2) {
                                bg_shade = (bg_shade + 6) * -1;
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
            Xml.Doc* res = new Xml.Doc ("1.0");
            Xml.Ns* ns = new Xml.Ns (null, "", null);

            // Create scheme
            // print ("Creating root\n");
            Xml.Node* root = new Xml.Node (ns, "style-scheme");
            root->new_prop ("id", "ulv-" + _name.down () + "-" + name_suffix.down ());
            root->new_prop ("name", _name + "-" + name_suffix + "-ulv");
            root->new_prop ("version", _version);
            res->set_root_element (root);

            // Add frontmatter
            // print ("Adding frontmatter\n");
            root->new_text_child (ns, "author", _author);
            root->new_text_child (ns, "description", "Style Scheme converted from Ulysses Theme " + _name);

            // Set default colors
            Xml.Node* text = new Xml.Node (ns, "style");
            text->new_prop ("name", "text");
            text->new_prop ("foreground", colors.foreground_color ());
            text->new_prop ("background", colors.background_color ());
            root->add_child (text);

            // Come up with additional stylings not in file
            Xml.Node* search = new Xml.Node (ns, "style");
            search->new_prop ("name", "search-match");
            search->new_prop ("foreground", colors.selection_fg_color (darken_selection, 1));
            search->new_prop ("background", colors.selection_bg_color (darken_selection, 1));
            root->add_child (search);

            Xml.Node* selection = new Xml.Node (ns, "style");
            selection->new_prop ("name", "selection");
            selection->new_prop ("foreground", colors.selection_fg_color (darken_selection, 1));
            selection->new_prop ("background", colors.selection_bg_color (darken_selection, 1));
            root->add_child (selection);

            Xml.Node* current_line = new Xml.Node (ns, "style");
            current_line->new_prop ("name", "current-line");
            current_line->new_prop ("background", colors.selection_bg_color (darken_selection, 1));
            root->add_child (current_line);

            Xml.Node* cursor = new Xml.Node (ns, "style");
            cursor->new_prop ("name", "cursor");
            cursor->new_prop ("foreground", colors.cursor_color ());
            root->add_child (cursor);

            // Add markdown stylings
            // print ("Converting style definitions\n");
            foreach (var entry in colors.elements) {
                // print ("Checking %s\n", entry.key);
                if (_style_map.has_key (entry.key))
                {
                    // print ("Creating comment for %s\n", entry.key);
                    res->new_comment ("Using " + entry.key + " for style");
                    Attribute apply_attribute = entry.value;
                    foreach (var apply in _style_map.get (entry.key).targets) {
                        // print ("Converting %s\n", entry.key);
                        Xml.Node* style = new Xml.Node (ns, "style");
                        style->new_prop ("name", apply);
                        apply_attribute.add_attributes (ref style);

                        if (entry.key.contains ("head")) {
                            style->new_prop ("scale", "large");
                        }

                        root->add_child (style);
                    }
                }
            }

            // print ("Writing theme output\n");
            string output_xml;
            res->dump_memory_enc_format (out output_xml);
            delete res;

            return output_xml;
        }

        private void throw_on_failure (Archive.Result res) throws Error {
            if ((res == Archive.Result.OK) ||
                (res == Archive.Result.WARN)) {
                return;
            }

            throw new IOError.FILE_NOT_VALID_ARCHIVE(
                "Could not read ultheme");
        }
    }
}
