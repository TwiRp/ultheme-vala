project('libultheme', ['vala', 'c'],
  default_options: [
    'buildtype=release',
    'default_library=shared',
  ],
  version: '0.0.1'
)

glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
archive_dep = dependency('libarchive')
gxml_dep = dependency('gxml-0.18', fallback : [ 'gxml', 'libgxml_dep' ])
gio_dep = dependency('gio-2.0')
clutter_dep = dependency('clutter-1.0')
gee_dep = dependency('gee-0.8')

ultheme_deps = [
  gobject_dep,
  archive_dep,
  gio_dep,
  gxml_dep,
  clutter_dep,
  gee_dep
]

subdir('src')
subdir('examples')