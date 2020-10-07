project('ultheme', ['vala', 'c'],
  default_options: [
    'default_library=shared',
  ],
  version: '0.0.1'
)

glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
archive_dep = dependency('libarchive')
gio_dep = dependency('gio-2.0')
clutter_dep = dependency('clutter-1.0')
gee_dep = dependency('gee-0.8')
xml_dep = dependency('libxml-2.0')

libultheme_deps = [
  gobject_dep,
  archive_dep,
  gio_dep,
  clutter_dep,
  gee_dep,
  xml_dep
]

subdir('src')
subdir('examples')
