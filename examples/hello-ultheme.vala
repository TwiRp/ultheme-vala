
public static int main (string[] args) {
    if (args.length != 2) {
        print ("Usage:\n");
        print ("\thello-ultheme <Theme.ultheme>");
        return 0;
    }

    var ultheme = new Ultheme.Parser (File.new_for_path (args[1]));

    return 0;
}
