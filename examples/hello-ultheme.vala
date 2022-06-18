using Gtk;
using Gdk;

public class HelloUltheme : Gtk.Application {
    public static GtkSource.StyleSchemeManager preview_manager;
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

        preview_manager = new GtkSource.StyleSchemeManager ();
        preview_manager.append_search_path (temp_dir);

        var app_box = new Gtk.Paned (Gtk.Orientation.VERTICAL);

        var preview_box = new Gtk.ScrolledWindow ();
        preview_items = new Gtk.FlowBox ();
        preview_items.column_spacing = 6;
        preview_items.row_spacing = 6;
        preview_box.set_child (preview_items);

        PreviewDrop drop_box = new PreviewDrop ();
        drop_box.show ();

        app_box.set_start_child (drop_box);
        app_box.set_end_child (preview_box);
        app_box.hexpand = true;

        window.set_child (app_box);

        shutdown.connect (on_delete_event);

        window.show ();
        app_box.set_position (drop_box.get_allocated_height () > 200 ? drop_box.get_allocated_height () : 200);
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

    private class PreviewDrop : Gtk.Box {
        private Gtk.Label label;
        construct {
            var layout = new Gtk.BoxLayout (Gtk.Orientation.VERTICAL);
            layout.spacing = 30;
            layout.homogeneous = false;
            this.set_layout_manager (layout);

            label = new Gtk.Label("  Drop Style.ultheme here to generate preview\n\n\n\n\n");

            append(label);

            // Drag and Drop Support
            Gtk.DropTarget target = new Gtk.DropTarget (Type.INVALID, Gdk.DragAction.COPY);
            target.set_gtypes ({ typeof (File), typeof (string) });
            target.on_drop.connect (on_drag_data_received);
            label.add_controller (target);
            show ();
        }

        public int get_allocated_height () {
            return base.get_allocated_height () + label.get_allocated_height ();
        }

        private bool on_drag_data_received (
            Value value,
            double x,
            double y)
        {
            string file_to_parse = "";
            File file = null;

            if (value.type () == typeof (File)) {
                file = (File)value;
            } else if (value.type () == typeof (string)) {
                file_to_parse = (string) value;
                file_to_parse = file_to_parse.chomp ();

                if (file_to_parse.has_prefix ("file"))
                {
                    print ("Removing file prefix for %s\n", file_to_parse.chomp ());
                    file = File.new_for_uri (file_to_parse.chomp ());
                    string? check_path = file.get_path ();
                    if ((check_path == null) || (check_path.chomp () == ""))
                    {
                        print ("Not a local file\n");
                        return false;
                    }
                    else
                    {
                        file_to_parse = check_path.chomp ();
                        print ("Result path: %s\n", file_to_parse);
                    }
                }
                file = File.new_for_path (file_to_parse);
            } else {
                return false;
            }

            if (!file.query_exists ()) {
                print ("Target file (%s) does not exist\n", file.get_path ());
                return false;
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
                    new_styles.get_dark_theme_palette (out dark_widget.palette);
                    dark_widget.set_text (preview_text);
                    preview_items.append (dark_widget);
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
                    new_styles.get_light_theme_palette (out light_widget.palette);
                    light_widget.set_text (preview_text);
                    preview_items.append (light_widget);
                    print ("Added %s\n", light_theme_id);
                }

                preview_items.show ();

            } catch (Error e) {
                print ("Failing generating preview: %s\n", e.message);
            }

            print ("Done\n");

            return true;
        }

        private string preview_text (string name) {
            return """# %s
Converted `theme`.
*Emphasis*, **Strong**, ~~Deleted~~
[link](http://github.com/twirp)
> Blockquote
<span id="html-sample">HTML Text</span>
```python
print ("hello world")
```
""".printf (name);
        }
    }

    private class PreviewWidget : Gtk.Button {
        private GtkSource.View view;
        private GtkSource.Buffer buffer;
        private string scheme_id;
        public Ultheme.HexColorPalette palette;
        private const string SAMPLE_TEXT = """# Heading
Body text.

> Blockquote""";

        public PreviewWidget () {
            var manager = GtkSource.LanguageManager.get_default ();
            var language = manager.guess_language (null, "text/markdown");
            view = new GtkSource.View ();
            buffer = new GtkSource.Buffer.with_language (language);
            buffer.highlight_syntax = true;
            view.editable = false;
            view.set_buffer (buffer);
            view.set_wrap_mode (Gtk.WrapMode.NONE);
            buffer.text = SAMPLE_TEXT;
            set_child (view);

            show ();
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