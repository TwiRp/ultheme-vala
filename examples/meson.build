if get_option('enable_examples')

  example_deps = libultheme_deps + [ libultheme_dep ] + [ dependency('gtk+-3.0'), dependency('gtksourceview-3.0'), ]

  executable('hello-ultheme', 'hello-ultheme.vala',
    dependencies: example_deps,
         install: false
  )

endif
