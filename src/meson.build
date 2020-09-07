if get_option('shared_lib')
  libtype = 'shared_library'
else
  libtype = 'static_library'
endif

libultheme_sources = [
  'Ultheme.vala',
]

libultheme = build_target('ultheme',
       sources: libultheme_sources,
  dependencies: libultheme_deps,
   target_type: libtype,
   vala_header: 'ultheme.h',
     vala_vapi: 'ultheme.vapi',
   install_dir: [true, true, true],
       install: true,
)

libultheme_dep = declare_dependency(
  include_directories: include_directories('.'),
            link_with: libultheme,
)

pkg = import('pkgconfig')
pkg.generate(
    libraries: libultheme,
      version: meson.project_version(),
         name: 'ultheme',
  description: 'Convert Ulysses Themes to GtkSourceView Markdown Styles',
)
