if get_option('enable_examples')

  example_deps = libultheme_deps + [ libultheme_dep ] + [ dependency('gtk4'), dependency('gtksourceview-5'), ]

  executable('hello-ultheme', 'hello-ultheme.vala',
    dependencies: example_deps,
         install: false
  )

endif
