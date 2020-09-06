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
xml_dep = dependency('libxml-2.0')
gio_dep = dependency('gio-2.0')

ultheme_deps = [
  gobject_dep,
  archive_dep,
  gio_dep,
  xml_dep
]

subdir('src')
subdir('examples')