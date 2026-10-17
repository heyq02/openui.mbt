///|
test "openui mergeStatements keeps reachable statement text" {
  inspect(
    merge_statements(
      "root = Card([title])\ntitle = Text(\"a\")", "title = Text(\"b\")", "root",
    ),
    content="root = Card([title])\ntitle = Text(\"b\")",
  )
  inspect(
    merge_statements(
      "root = Card([title])\ntitle = Text(\"a\")", "title = null", "root",
    ),
    content="root = Card([title])",
  )
  inspect(
    merge_statements("root = Card([title])\ntitle = Text(\"a\")", "", "root"),
    content="root = Card([title])\ntitle = Text(\"a\")",
  )
  inspect(
    merge_statements("", "root = Card([])", "root"),
    content="root = Card([])",
  )
  inspect(merge_statements("   ", "root = A()", "root"), content="root = A()")
  inspect(
    merge_statements("root = A()\n", "nope", "root"),
    content="root = A()\n",
  )
  inspect(
    merge_statements(
      "root = Card([title])\ntitle = Text(\"a\")\nold = Text(\"z\")", "```openui\ntitle = Text(\"b\")\n```",
      "root",
    ),
    content="root = Card([title])\ntitle = Text(\"b\")",
  )
  inspect(
    merge_statements(
      "root = Card([\n  title\n])\ntitle = Text(\"a\")", "title = Text(\"b\")", "root",
    ),
    content="root = Card([\n  title\n])\ntitle = Text(\"b\")",
  )
  inspect(
    merge_statements(
      "$s = 1\nroot = Card([])\norphan = Text(\"z\")", "root = Card([])", "root",
    ),
    content="$s = 1\nroot = Card([])",
  )
  inspect(
    merge_statements(
      "root = Card([title])\ntitle = Text([sub])\nsub = Text(\"a\")\ngone = Text(\"z\")",
      "title = null", "root",
    ),
    content="root = Card([title])",
  )
  inspect(
    merge_statements(
      "root = A([b])\nb = B([c])\nc = C()\nd = D()", "b = null", "root",
    ),
    content="root = A([b])",
  )
  inspect(
    merge_statements("only = A()", "patch = B()", "root"),
    content="only = A()\npatch = B()",
  )
  inspect(
    merge_statements(
      "root = A()\n// comment\ntitle = B()", "title = C() // x", "root",
    ),
    content="root = A()",
  )
  inspect(
    merge_statements("root = A(\"line\\nbreak\")", "root = B()", "root"),
    content="root = B()",
  )
  inspect(
    merge_statements(
      "root = Card([title])\ntitle = Text(\"a\")", "title = Text(\"b\")\nextra = Text(\"c\")",
      "missing",
    ),
    content="root = Card([title])\ntitle = Text(\"b\")\nextra = Text(\"c\")",
  )
  inspect(
    merge_statements("root = A([b])\nb = B()", "\"```\"\nroot = C()", "root"),
    content="root = C()",
  )
  inspect(merge_statements("root = A()", "```", "root"), content="root = A()")
  inspect(
    merge_statements(
      "root = Card({label: title})\ntitle = Text(\"a\")\norphan = Text(\"z\")", "title = Text(\"b\")",
      "root",
    ),
    content="root = Card({label: title})\ntitle = Text(\"b\")",
  )
  inspect(
    merge_statements(
      "root = Card([title, title])\ntitle = Text(\"a\")", "title = Text(\"b\")",
      "root",
    ),
    content="root = Card([title, title])\ntitle = Text(\"b\")",
  )
  inspect(
    merge_statements(
      "root = A()", "\"a\\\\\" ```openui\nroot = B()\n```", "root",
    ),
    content="root = B()",
  )
  inspect(
    merge_statements(
      "root = A()\norp = B()",
      "root = A()",
      "root",
      has_root=false,
    ),
    content="root = A()\norp = B()",
  )
  inspect(
    merge_statements(
      "root = A([b])", "```openui\nroot = Card([title])\ntitle = Text(\"b\")", "root",
    ),
    content="root = Card([title])\ntitle = Text(\"b\")",
  )
  inspect(
    merge_statements(
      "root = A()", "root = B(x + y, !z, cond ? a : b, obj.f, arr[i], $s = 1)", "root",
    ),
    content="root = B(x + y, !z, cond ? a : b, obj.f, arr[i], $s = 1)",
  )
}
