///|
test "field paths and toNumber match the official conversions" {
  inspect(resolve_field("\"\""), content="[\"\"]")
  inspect(resolve_field("\"name\""), content="[\"name\"]")
  inspect(resolve_field("\"state.name\""), content="[\"state\",\"name\"]")
  inspect(resolve_field("\"a.\""), content="[\"a\",\"\"]")
  inspect(resolve_field("\".a\""), content="[\"\",\"a\"]")
  inspect(resolve_field("\"a..b\""), content="[\"a\",\"\",\"b\"]")
  inspect(resolve_field("\"a.b.c\""), content="[\"a\",\"b\",\"c\"]")
  inspect(resolve_field("1"), content="[]")
  inspect(resolve_field("{"), content="[]")
  inspect(to_number("{\"t\":\"n\",\"v\":2}"), content="{\"t\":\"n\",\"v\":2}")
  inspect(to_number("{\"t\":\"nan\"}"), content="{\"t\":\"nan\"}")
  inspect(to_number("{\"t\":\"pinf\"}"), content="{\"t\":\"pinf\"}")
  inspect(to_number("{\"t\":\"ninf\"}"), content="{\"t\":\"ninf\"}")
  inspect(to_number("{\"t\":\"n0\"}"), content="{\"t\":\"n0\"}")
  inspect(
    to_number("{\"t\":\"b\",\"v\":true}"),
    content="{\"t\":\"n\",\"v\":1}",
  )
  inspect(
    to_number("{\"t\":\"b\",\"v\":false}"),
    content="{\"t\":\"n\",\"v\":0}",
  )
  inspect(to_number("{\"t\":\"b\"}"), content="{\"t\":\"n\",\"v\":0}")
  inspect(
    to_number("{\"t\":\"s\",\"v\":\"\"}"),
    content="{\"t\":\"n\",\"v\":0}",
  )
  inspect(
    to_number("{\"t\":\"s\",\"v\":\"  1.5 \"}"),
    content="{\"t\":\"n\",\"v\":1.5}",
  )
  inspect(
    to_number("{\"t\":\"s\",\"v\":\"0x10\"}"),
    content="{\"t\":\"n\",\"v\":16}",
  )
  inspect(
    to_number("{\"t\":\"s\",\"v\":\"0b10\"}"),
    content="{\"t\":\"n\",\"v\":2}",
  )
  inspect(
    to_number("{\"t\":\"s\",\"v\":\"0o10\"}"),
    content="{\"t\":\"n\",\"v\":8}",
  )
  inspect(
    to_number("{\"t\":\"s\",\"v\":\"Infinity\"}"),
    content="{\"t\":\"pinf\"}",
  )
  inspect(
    to_number("{\"t\":\"s\",\"v\":\"-Infinity\"}"),
    content="{\"t\":\"ninf\"}",
  )
  inspect(to_number("{\"t\":\"s\",\"v\":\"-0\"}"), content="{\"t\":\"n0\"}")
  inspect(
    to_number("{\"t\":\"s\",\"v\":\"NaN\"}"),
    content="{\"t\":\"n\",\"v\":0}",
  )
  inspect(
    to_number("{\"t\":\"s\",\"v\":\"nope\"}"),
    content="{\"t\":\"n\",\"v\":0}",
  )
  inspect(to_number("{\"t\":\"x\"}"), content="{\"t\":\"n\",\"v\":0}")
  inspect(to_number("{"), content="{\"t\":\"n\",\"v\":0}")
}
