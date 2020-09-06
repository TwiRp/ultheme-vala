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

            _dark_theme = new ThemeColors ();
            _light_theme = new ThemeColors ();

            // Map from Ultheme item definitions to style names
            _style_map = new HashMap<string, StyleTargets> ();
            _style_map.set ("heading1", new StyleTargets({ "markdown:header", "def:type", "def:heading" }));
            _style_map.set ("codeblock", new StyleTargets({ "markdown:code-block", }));
            _style_map.set ("code", new StyleTargets({ "markdown:code", "def:identifier", "markdown:code-span" }));
            _style_map.set ("comment", new StyleTargets({ "markdown:backslash-escape", "def:special-char" }));
            _style_map.set ("blockquote", new StyleTargets({ "markdown:blockquote-marker", "def:shebang" }));
            _style_map.set ("link", new StyleTargets({ "markdown:link-text", "markdown:url", "markdown:label", "markdown:attribute-value", "def:underlined", "def:comment", "def:preprocessor", "def:constant" }));
            _style_map.set ("divider", new StyleTargets({ "markdown:horizontal-rule", "def:note", "markdown:line-break" }));
            _style_map.set ("orderedList", new StyleTargets({ "markdown:list-marker", "def:statement" }));
            _style_map.set ("image", new StyleTargets({ "markdown:image-marker", }));
            _style_map.set ("emph", new StyleTargets({ "markdown:emphasis", "def:doc-comment-element" }));
            _style_map.set ("strong", new StyleTargets({ "markdown:strong-emphasis", "def:statement" }));

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
                    read_palette (colors, item_definitions, _light_theme, "colorsLight");
                } else {
                    read_palette (colors, item_definitions, _light_theme, "colorsDark");
                }
            }
        }

        private void read_palette (
            GXml.DomHTMLCollection colors,
            GXml.DomHTMLCollection item_definitions,
            ThemeColors color_theme,
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
                    string? identifier = color.get_attribute ("value");
                    if (identifier == "foreground") {
                        color_theme.foreground = read_color;
                    } else {
                        color_theme.background = read_color;
                    }
                } else {
                    color_theme._colors += read_color;
                }
            }

            // Read the style definitions
            for (int s = 0; s < item_definitions.length; s += 1) {
                GXml.DomElement item = item_definitions.get_element (s);
                string? color_def = item.get_attribute(color_attr);
                string? traits = item.get_attribute("traits");
                Attribute attr = new Attribute ();

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
            }
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

        public string get_dark_theme () {
            return "";
        }

        public string get_light_theme () {
            return "";
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
        }

        private class StyleTargets {
            public string[] targets;
            public StyleTargets (string[] classes) {
                targets = classes;
            }
        }
    }
}