///|
test "openui message markers follow the official split" {
  inspect(
    parse_message("Hi\r\n```openui-lang\nroot = A()\n```\n", false),
    content=(
      #|{"content":"Hi\r\n```openui-lang\nroot = A()\n```\n","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message(
      "]]>openui:content\nold\n]]>openui:context\n{}\n]]>openui:content?v=2\nnew\r\n]]>openui:context\n{\"a\":",
      false,
    ),
    content=(
      #|{"content":"new","context":"{\"a\":","attributes":{"v":"2"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content\nroot = A()\n]]>open", true),
    content=(
      #|{"content":"root = A()","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content\nroot = A()\n]]>open", false),
    content=(
      #|{"content":"root = A()\n]]>open","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message(
      "]]>openui:content?v=2\nroot = A(\"Broken]]>openui:content?v=2\nroot = B()\n]]>openui:end",
      false,
    ),
    content=(
      #|{"content":"root = B()","context":null,"attributes":{"v":"2"},"end":true}
    ),
  )
  inspect(
    parse_message("]]>openui:content\nroot = A(\"Broken]]>", true),
    content=(
      #|{"content":"root = A(\"Broken","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content\nroot = A(\"Broken]]>openui:cont", true),
    content=(
      #|{"content":"root = A(\"Broken","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message(
      "]]>openui:content\nroot = A(\"Broken]]>openui:content?v=2", true,
    ),
    content=(
      #|{"content":"root = A(\"Broken","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message(
      "]]>openui:content\nroot = A(\"Broken]]>openui:content?v=2\nroot = B()", true,
    ),
    content=(
      #|{"content":"root = B()","context":null,"attributes":{"v":"2"},"end":false}
    ),
  )
  inspect(
    parse_message(
      "]]>openui:context\n{\"$x\":1}\n]]>openui:end\n]]>openui:content\nroot = A()",
      false,
    ),
    content=(
      #|{"content":"root = A()","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content\nroot = A()\n]]>openui:end\n", false),
    content=(
      #|{"content":"root = A()","context":null,"attributes":{},"end":true}
    ),
  )
  inspect(
    parse_message(
      "]]>openui:content?library=%40acme%2Fsupport%401.2.0&note=a+b%21\nroot\n]]>openui:end",
      false,
    ),
    content=(
      #|{"content":"root","context":null,"attributes":{"library":"@acme/support@1.2.0","note":"a b!"},"end":true}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%E4%B8%AD\nbody", false),
    content=(
      #|{"content":"body","context":null,"attributes":{"q":"中"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%C2%A9\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"©"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%F0%9F%98%80\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"😀"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%41\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"A"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%ZZ\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"%ZZ"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%C0%80\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"%C0%80"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%ED%A0%80\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"%ED%A0%80"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%80\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"%80"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%E4%20%80\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"%E4%20%80"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?flag\nbody", false),
    content=(
      #|{"content":"body","context":null,"attributes":{"flag":""},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?&=x&v=1&\nbody", false),
    content=(
      #|{"content":"body","context":null,"attributes":{"v":"1"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content extra\nbody", false),
    content=(
      #|{"content":"]]>openui:content extra\nbody","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message(
      "]]>openui:content\nbody\n]]>openui:context\n{\"note\":\"rush\"}\n", false,
    ),
    content=(
      #|{"content":"body","context":{"note":"rush"}
      #|,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message(
      "]]>openui:content\nbody\n]]>openui:context\n[{\"note\":\"rush\"}]\n", false,
    ),
    content=(
      #|{"content":"body","context":[{"note":"rush"}]
      #|,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("root = A()\nx]]>nope", true),
    content=(
      #|{"content":"root = A()\nx]]>nope","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content\nroot = A()\n]]>", true),
    content=(
      #|{"content":"root = A()","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content\nbody\n]]>openui:context\ntrue\n", false),
    content=(
      #|{"content":"body","context":true
      #|,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("ab", true),
    content=(
      #|{"content":"ab","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("]]>a", true),
    content=(
      #|{"content":"]]>a","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("x]]>openui:content", false),
    content=(
      #|{"content":"","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("x]]>openui:content\nbody", false),
    content=(
      #|{"content":"body","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("x]]>openui:content\r\nbody", false),
    content=(
      #|{"content":"body","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("x]]>openui:content\r", false),
    content=(
      #|{"content":"x]]>openui:content\r","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:\nbody", false),
    content=(
      #|{"content":"]]>openui:\nbody","context":null,"attributes":{},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%E4%B8\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"%E4%B8"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"%"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%E4\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"%E4"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content?q=%C0%80x\nx", false),
    content=(
      #|{"content":"x","context":null,"attributes":{"q":"%C0%80x"},"end":false}
    ),
  )
  inspect(
    parse_message("]]>openui:content\nHi\r\nthere\r\n]]>openui:end", false),
    content=(
      #|{"content":"Hi\r\nthere","context":null,"attributes":{},"end":true}
    ),
  )
}

///|
test "openui buildMessage writes the official marker text" {
  inspect(
    build_message(
      "root = Card([title])\ntitle = TextContent(\"a ]]>openui:end\")", "[{\"note\":\"rush\"}]",
      true, "[[\"library\",\"@acme/support@1.2.0\"],[\"note\",\"a b!\"]]", true,
    ),
    content=(
      #|]]>openui:content?library=%40acme%2Fsupport%401.2.0&note=a+b%21
      #|root = Card([title])
      #|title = TextContent("a ]]>openui:end")
      #|]]>openui:context
      #|[{"note":"rush"}]
      #|]]>openui:end
    ),
  )
  inspect(
    build_message("root", "", false, "[]", false),
    content=(
      #|]]>openui:content
      #|root
    ),
  )
  inspect(
    build_message("root", "raw", true, "[]", false),
    content=(
      #|]]>openui:content
      #|root
      #|]]>openui:context
      #|raw
    ),
  )
  inspect(
    build_message("hi", "", false, "[[\"q\",\"中\"]]", false),
    content=(
      #|]]>openui:content?q=%E4%B8%AD
      #|hi
    ),
  )
  inspect(
    build_message("hi", "", false, "[[\"q\",\"😀\"]]", true),
    content=(
      #|]]>openui:content?q=%F0%9F%98%80
      #|hi
      #|]]>openui:end
    ),
  )
  inspect(
    build_message(
      "hi", "", false, "[[\"a b\",\"x y\"],[\"note\",\"!'()~*\"]]", false,
    ),
    content=(
      #|]]>openui:content?a+b=x+y&note=%21%27%28%29%7E*
      #|hi
    ),
  )
  inspect(
    build_message("hi", "", false, "not-json", false),
    content=(
      #|]]>openui:content
      #|hi
    ),
  )
  inspect(
    build_message("hi", "", false, "[[\"q\",\"©\"]]", false),
    content=(
      #|]]>openui:content?q=%C2%A9
      #|hi
    ),
  )
  inspect(
    build_message("hi", "", false, "{}", false),
    content=(
      #|]]>openui:content
      #|hi
    ),
  )
  inspect(
    build_message("hi", "", false, "[\"x\",[1,\"a\"],[\"only\"]]", false),
    content=(
      #|]]>openui:content
      #|hi
    ),
  )
}
