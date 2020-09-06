if get_option('shared_lib')
  libtype = 'shared_library'
else
  libtype = 'static_library'
endif

ultheme_sources = [
  'Ultheme.vala',
]

ultheme = build_target('ultheme',
       sources: ultheme_sources,
  dependencies: ultheme_deps,
   target_type: libtype,
   vala_header: 'ultheme.h',
     vala_vapi: 'ultheme.vapi',
   install_dir: [true, true, true],
       install: true,
)

ultheme_dep = declare_dependency(
  include_directories: include_directories('.'),
            link_with: ultheme,
)

pkg = import('pkgconfig')
pkg.generate(
    libraries: ultheme,
      version: meson.project_version(),
         name: 'ultheme',
  description: 'Convert Ulysses Themes to GtkSourceView Markdown Styles',
)