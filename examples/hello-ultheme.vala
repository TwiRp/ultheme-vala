using Gtk;
using Gdk;

public class HelloUltheme : Gtk.Application {
    public enum Target {
        STRING,
        URI
    }

    public const TargetEntry[] target_list = {
        { "STRING" , 0, Target.STRING },
        { "text/uri-list", 0, Target.URI }
    };

    public static Gtk.SourceStyleSchemeManager preview_manager;
    public static string temp_dir;
    public static Gtk.FlowBox preview_items;

    private static void save_file (File save_file, uint8[] buffer) throws Error {
        var output = new DataOutputStream (save_file.create(FileCreateFlags.REPLACE_DESTINATION));
        long written = 0;
        while (written < buffer.length)
            written += output.write (buffer[written:buffer.length]);
    }

    protected override void activate () {
        var window = new Gtk.ApplicationWindow (this);
        window.set_title ("Ultheme Example");
        window.set_default_size (800, 640);

        temp_dir = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_tmp_dir (), "ultheme-styles");
        File temp_location = File.new_for_path (temp_dir);

        if (!temp_location.query_exists ()) {
            if (temp_location.make_directory_with_parents ()) {
                print ("Created temporary location: %s\n", temp_dir);
            }
        }

        preview_manager = new Gtk.SourceStyleSchemeManager ();
        preview_manager.append_search_path (temp_dir);

        var app_box = new Gtk.Paned (Gtk.Orientation.VERTICAL);

        var preview_box = new Gtk.ScrolledWindow (null, null);
        preview_items = new Gtk.FlowBox ();
        //preview_items = new Gtk.Grid ();
        preview_items.margin = 6;
        //preview_items.orientation = Gtk.Orientation.HORIZONTAL;
        preview_box.add (preview_items);

        /*PreviewWidget twidge = new PreviewWidget ();
        preview_items.add (twidge);*/

        PreviewDrop drop_box = new PreviewDrop ();
        drop_box.show_all ();

        app_box.add1 (drop_box);
        app_box.add2 (preview_box);
        app_box.hexpand = true;

        window.add (app_box);

        shutdown.connect (on_delete_event);

        window.show_all ();
        app_box.set_position (drop_box.get_allocated_height ());
    }

    public void on_delete_event () {
        File temp_location = File.new_for_path (temp_dir);

        try {
            if (temp_location.query_exists ()) {
                Dir dir = Dir.open (temp_dir, 0);
                string? file_name = null;
                while ((file_name = dir.read_name()) != null) {
                    print ("Checking %s...\n", file_name);
                    if (!file_name.has_prefix(".")) {
                        string path = Path.build_filename (temp_dir, file_name);
                        if (FileUtils.test (path, FileTest.IS_REGULAR) && !FileUtils.test (path, FileTest.IS_SYMLINK)) {
                            File rm_file = File.new_for_path (path);
                            print ("Cleaning %s...\n", path);
                            rm_file.delete ();
                        }
                    }
                }
                temp_location.delete ();
                print ("Cleaning %s...\n", temp_dir);
            }
        } catch (Error e) {
            print ("Could not clean up: %s\n", e.message);
            return;
        }

        print ("Deleted temporary files\n");
    }

    public static int main (string[] args) {
        return new HelloUltheme ().run (args);
    }

    private class PreviewDrop : Gtk.Label {
        construct {
            label = "  Drop Style.ultheme here to generate preview\n\n\n\n\n";

            // Drag and Drop Support
            Gtk.drag_dest_set (
                this,                        // widget will be drag-able
                DestDefaults.ALL,              // modifier that will start a drag
                target_list,                   // lists of target to support
                Gdk.DragAction.COPY            // what to do with data after dropped
            );
            this.drag_motion.connect(this.on_drag_motion);
            this.drag_leave.connect(this.on_drag_leave);
            this.drag_drop.connect(this.on_drag_drop);
            this.drag_data_received.connect(this.on_drag_data_received);
            show_all ();
        }

        private bool on_drag_motion (
            Widget widget,
            DragContext context,
            int x,
            int y,
            uint time)
        {
            // set_shadow_type (Gtk.ShadowType.ETCHED_OUT);
            return false;
        }

        private void on_drag_leave (Widget widget, DragContext context, uint time) {
            // set_shadow_type (Gtk.ShadowType.ETCHED_IN);
        }

        private bool on_drag_drop (
            Widget widget,
            DragContext context,
            int x,
            int y,
            uint time)
        {
            var target_type = (Atom) context.list_targets().nth_data (Target.STRING);

            if (!target_type.name ().ascii_up ().contains ("STRING"))
            {
                target_type = (Atom) context.list_targets().nth_data (Target.URI);
            }

            // Request the data from the source.
            Gtk.drag_get_data (
                widget,         // will receive 'drag_data_received' signal
                context,        // represents the current state of the DnD
                target_type,    // the target type we want
                time            // time stamp
                );

            bool is_valid_drop_site = target_type.name ().ascii_up ().contains ("STRING") || target_type.name ().ascii_up ().contains ("URI");

            return is_valid_drop_site;
        }

        private void on_drag_data_received (
            Widget widget,
            DragContext context,
            int x,
            int y,
            SelectionData selection_data,
            uint target_type,
            uint time)
        {
            string file_to_parse = "";
            File file;

            // Check that we got the format we can use
            switch (target_type)
            {
                case Target.URI:
                    file_to_parse = (string) selection_data.get_data();
                break;
                case Target.STRING:
                    file_to_parse = (string) selection_data.get_data();
                break;
                default:
                    print ("Invalid data type\n");
                break;
            }

            file_to_parse = file_to_parse.chomp ();
            print ("Parsing %s\n", file_to_parse);

            if (file_to_parse != "")
            {
                if (file_to_parse.has_prefix ("file"))
                {
                    print ("Removing file prefix for %s\n", file_to_parse.chomp ());
                    file = File.new_for_uri (file_to_parse.chomp ());
                    string? check_path = file.get_path ();
                    if ((check_path == null) || (check_path.chomp () == ""))
                    {
                        print ("Not a local file\n");
                        Gtk.drag_finish (context, false, false, time);
                        return;
                    }
                    else
                    {
                        file_to_parse = check_path.chomp ();
                        print ("Result path: %s\n", file_to_parse);
                    }
                }
            }

            file = File.new_for_path (file_to_parse);

            if (!file.query_exists ()) {
                print ("Target file (%s) does not exist\n", file.get_path ());
                Gtk.drag_finish (context, false, false, time);
                return;
            }

            print ("Decoding %s\n", file.get_path ());
            try {
                var new_styles = new Ultheme.Parser (file);

                // Handle dark
                string dark_path = Path.build_filename (temp_dir, new_styles.get_dark_theme_id () + ".xml");
                var dark_file = File.new_for_path (dark_path);
                string dark_theme_text = new_styles.get_dark_theme ();
                string dark_theme_id = new_styles.get_dark_theme_id ();
                string preview_text = preview_text (new_styles.get_theme_name ());

                if (!dark_file.query_exists ()) {
                    save_file (dark_file, dark_theme_text.data);

                    PreviewWidget dark_widget = new PreviewWidget ();
                    dark_widget.set_scheme (dark_theme_id);
                    dark_widget.set_color_palette (new_styles.get_dark_theme_palette ());
                    dark_widget.set_text (preview_text);
                    preview_items.add (dark_widget);
                    print ("Added %s\n", dark_theme_id);
                }

                // Handle light
                string light_path = Path.build_filename (temp_dir, new_styles.get_light_theme_id () + ".xml");
                var light_file = File.new_for_path (light_path);
                string light_theme_text = new_styles.get_light_theme ();
                string light_theme_id = new_styles.get_light_theme_id ();

                if (!light_file.query_exists ()) {
                    save_file (light_file, light_theme_text.data);

                    PreviewWidget light_widget = new PreviewWidget ();
                    light_widget.set_scheme (light_theme_id);
                    light_widget.set_color_palette (new_styles.get_light_theme_palette ());
                    light_widget.set_text (preview_text);
                    preview_items.add (light_widget);
                    print ("Added %s\n", light_theme_id);
                }

                preview_items.show_all ();

            } catch (Error e) {
                print ("Failing generating preview: %s\n", e.message);
            }

            print ("Done\n");

            Gtk.drag_finish (context, true, false, time);
        }

        private string preview_text (string name) {
            return """# %s
Converted `theme`.
*Emphasis*, **Strong**
[link](http://github.com/twirp)
> Blockquote
""".printf (name);
        }
    }

    private class PreviewWidget : Gtk.Button {
        private Gtk.SourceView view;
        private Gtk.SourceBuffer buffer;
        private string scheme_id;
        private Ultheme.HexColorPalette palette;
        private const string SAMPLE_TEXT = """# Heading
Body text.

> Blockquote""";

        public PreviewWidget () {
            var manager = Gtk.SourceLanguageManager.get_default ();
            var language = manager.guess_language (null, "text/markdown");
            margin = 0;
            view = new Gtk.SourceView ();
            view.margin = 0;
            buffer = new Gtk.SourceBuffer.with_language (language);
            buffer.highlight_syntax = true;
            view.editable = false;
            view.set_buffer (buffer);
            view.set_wrap_mode (Gtk.WrapMode.NONE);
            buffer.text = SAMPLE_TEXT;
            add (view);

            show_all ();
        }

        public void set_text (string text) {
            buffer.text = text;
        }

        public void set_scheme (string scheme) {
            HelloUltheme.preview_manager.force_rescan ();
            var style = HelloUltheme.preview_manager.get_scheme (scheme);
            buffer.set_style_scheme (style);
            scheme_id = scheme;
        }

        public void set_color_palette (Ultheme.HexColorPalette colors) {
            palette = colors;
        }

        public string get_scheme () {
            return scheme_id;
        }
    }
}