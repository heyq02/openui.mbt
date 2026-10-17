///|
test "inline elements keep props only when dynamics are frozen" {
  inspect(inline_step("{\"frozen\":true}"), content="{\"op\":\"keep\"}")
  inspect(inline_step("{\"frozen\":false}"), content="{\"op\":\"eval\"}")
  inspect(inline_step("{\"frozen\":1}"), content="{\"op\":\"eval\"}")
  inspect(inline_step("{}"), content="{\"op\":\"eval\"}")
  inspect(inline_step("[]"), content="{\"op\":\"eval\"}")
  inspect(inline_step("{"), content="{\"op\":\"eval\"}")
}
