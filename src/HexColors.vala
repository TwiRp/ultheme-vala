using Gee;

namespace Ultheme {
    public class Color : Object {
        public uint8 red;
        public uint8 green;
        public uint8 blue;
        public uint8 alpha;

        public Color () {
            red = 0;
            green = 0;
            blue = 0;
            alpha = 0;
        }

        /**
         * Taken from Clutter Project (https://www.clutter-project.org/)
         *
         * Authored By: Matthew Allum  <mallum@openedhand.com>
         *              Emmanuele Bassi <ebassi@linux.intel.com>
         *
         * Copyright (C) 2006, 2007, 2008 OpenedHand
         * Copyright (C) 2009 Intel Corp.
         *
         * This library is free software; you can redistribute it and/or
         * modify it under the terms of the GNU Lesser General Public
         * License as published by the Free Software Foundation; either
         * version 2 of the License, or (at your option) any later version.
         *
         * This library is distributed in the hope that it will be useful,
         * but WITHOUT ANY WARRANTY; without even the implied warranty of
         * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
         * Lesser General Public License for more details.
         *
         * You should have received a copy of the GNU Lesser General Public
         * License along with this library. If not, see <http://www.gnu.org/licenses/>.
         */
        public static Color from_string (string str) {
            Color res = new Color ();
            string cs = str.down ();

            /*if (cs.has_prefix ("rgba")) {
                return parse_rgba (cs.substring (4), true);
            } else if (cs.has_prefix ("rgb")) {
                return parse_rgba (cs.substring (3), false);
            } else if (cs.has_prefix ("hsla")) {
                return parse_hsla (cs.substring (4), true);
            } else if (cs.has_prefix ("hsl")) {
                return parse_hsla (cs.substring (3), false);
            } else */
            if (!cs.has_prefix ("#")) {
                cs = "#" + cs;
            }
            uint32 c = (uint32)(ulong.parse (cs.substring(1), 16));

            switch (cs.length) {
                case 9:
                    res = from_pixel (c);
                    break;
                case 7:
                    res.red = (uint8)((c >> 16) & 0xff);
                    res.green = (uint8)((c >> 8) & 0xff);
                    res.blue = (uint8)(c & 0xff);
                    res.alpha = 0xff;
                    break;
                case 5:
                    res.red = (uint8)((c >> 12) & 0xf);
                    res.green = (uint8)((c >> 8) & 0xf);
                    res.blue = (uint8)((c >> 4) & 0xf);
                    res.alpha = (uint8)(c & 0xf);

                    res.red = (res.red << 4) | res.red;
                    res.green = (res.green << 4) | res.green;
                    res.blue = (res.blue << 4) | res.blue;
                    res.alpha = (res.alpha << 4) | res.alpha;
                    break;
                case 4:
                    res.red = (uint8)((c >> 8) & 0xf);
                    res.green = (uint8)((c >> 4) & 0xf);
                    res.blue = (uint8)(c & 0xf);
                    res.alpha = 0xff;

                    res.red = (res.red << 4) | res.red;
                    res.green = (res.green << 4) | res.green;
                    res.blue = (res.blue << 4) | res.blue;
                    break;
                default:
                    Gdk.RGBA gc = Gdk.RGBA ();
                    if (gc.parse (cs)) {
                        res.red = (uint8)(255 * gc.red);
                        res.green = (uint8)(255 * gc.green);
                        res.blue = (uint8)(255 * gc.blue);
                        res.alpha = 0xff;
                    }
                    break;
            }

            return res;
        }

        public static Color from_pixel (uint32 pixel) {
            Color res = new Color ();

            res.red = (uint8)(pixel >> 24);
            res.green = (uint8)((pixel >> 16) & 0xff);
            res.blue = (uint8)((pixel >> 8) & 0xff);
            res.alpha = (uint8)(pixel & 0xff);

            return res;
        }

        public static Color from_hls (double hue, double luminance, double saturation) {
            Color res = new Color ();
            double tmp1, tmp2;
            double[] tmp3 = new double[3];
            double[] clr = new double[3];
            double h, s, l;

            h = hue / 360.0f;
            res.alpha = 255;
            if (saturation == 0) {
                res.red = (uint8)(luminance * 255);
                res.green = (uint8)(luminance * 255);
                res.blue = (uint8)(luminance * 255);

                return res;
            }

            if (luminance <= 0.5f) {
                tmp2 = luminance * (1.0 + saturation);
            } else {
                tmp2 = luminance + saturation - (luminance * saturation);
            }

            tmp1 = 2.0 * luminance - tmp2;

            tmp3[0] = h + (1.0f / 3.0f);
            tmp3[1] = h;
            tmp3[2] = h - (1.0f / 3.0f);

            for (int i = 0; i < 3; i++) {
                if (tmp3[i] < 0) {
                    tmp3[i] += 1.0;
                }

                if (tmp3[i] > 1) {
                    tmp3[i] -= 1.0;
                }

                if (6.0 * tmp3[i] < 1.0) {
                    clr[i] = tmp1 + (tmp2 - tmp1) * tmp3[i] * 6.0;
                } else if (2.0 * tmp3[i] < 1.0) {
                    clr[i] = tmp2;
                } else if (3.0 * tmp3[i] < 2.0) {
                    clr[i] = (tmp1 + (tmp2 - tmp1) * ((2.0 / 3.0) - tmp3[i]) * 6.0);
                } else {
                    clr[i] = tmp1;
                }
            }

            res.red = (uint8)(clr[0] * 255.0 + 0.5);
            res.green = (uint8)(clr[1] * 255.0 + 0.5);
            res.blue = (uint8)(clr[2] * 255.0 + 0.5);

            return res;
        }

        public Color add (Color b) {
            Color res = new Color ();

            res.red = (red + b.red).clamp (0, 255);
            res.green = (green + b.red).clamp (0, 255);
            res.blue = (blue + b.red).clamp (0, 255);
            res.alpha = uint8.max (alpha, b.alpha);

            return res;
        }

        public Color subtract (Color b) {
            Color res = new Color ();

            res.red = (red - b.red).clamp (0, 255);
            res.green = (green - b.red).clamp (0, 255);
            res.blue = (blue - b.red).clamp (0, 255);
            res.alpha = uint8.min (alpha, b.alpha);

            return res;
        }

        public Color lighten () {
            return shade (1.3);
        }

        public Color darken () {
            return shade (0.7);
        }

        public Color shade (double amount) {
            double h, l, s;

            to_hls (out h, out l, out s);
            l *= amount;
            if (l > 1.0) {
                l = 1.0;
            } else if (l < 0) {
                l = 0;
            }

            s *= amount;
            if (s > 1.0) {
                s = 1.0;
            } else if (s < 0) {
                s = 0;
            }

            Color res = Color.from_hls (h, l, s);
            res.alpha = alpha;

            return res;
        }

        public Color interpolate (Color final, double progress) {
            Color res = new Color ();

            res.red = ((uint8)(red + (final.red - red) * progress)).clamp (0, 255);
            res.green = ((uint8)(green + (final.green - green) * progress)).clamp (0, 255);
            res.blue = ((uint8)(blue + (final.blue - blue) * progress)).clamp (0, 255);
            res.alpha = ((uint8)(alpha + (final.alpha - alpha) * progress)).clamp (0, 255);

            return res;
        }

        public uint32 to_pixel () {
            return (alpha |
                    blue << 8 |
                    green << 16 |
                    red << 24);
        }

        public void to_hls (out double hue, out double luminance, out double saturation) {
            double r, g, b, min, max, delta, h, l, s;

            r = red / 255.0f;
            g = green / 255.0f;
            b = blue / 255.0f;

            max = double.max (double.max (r, g), b);
            min = double.min (double.min (r, g), b);

            l = (max + min) / 2;
            s = 0; h = 0;

            if (max != min) {
                if (l <= 0.5) {
                    s = (max - min) / (max + min);
                } else {
                    s = (max - min) / (2 - max - min);
                }

                delta = max - min;

                if (r == max) {
                    h = (g - b) / delta;
                } else if (g == max) {
                    h = 2.0 + ((b - r) / delta);
                } else if (b == max) {
                    h = 4.0 + ((r - g) / delta);
                }

                h *= 60;

                if (h < 0) {
                    h += 360.0;
                }
            }

            hue = h;
            luminance = l;
            saturation = s;
        }

        public string to_string () {
            return "#%02x%02x%02x%02x".printf(red, green, blue, alpha);
        }
    }

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