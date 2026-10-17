///|
test "state fields choose the official reactive branch" {
  inspect(
    state_field("{\"assign\":true,\"store\":true,\"context\":true}"),
    content="{\"op\":\"reactive\"}",
  )
  inspect(
    state_field("{\"assign\":true,\"store\":true,\"context\":false}"),
    content="{\"op\":\"plain\"}",
  )
  inspect(
    state_field("{\"assign\":true,\"store\":false,\"context\":true}"),
    content="{\"op\":\"plain\"}",
  )
  inspect(
    state_field("{\"assign\":false,\"store\":true,\"context\":true}"),
    content="{\"op\":\"plain\"}",
  )
  inspect(state_field("{\"assign\":1}"), content="{\"op\":\"plain\"}")
  inspect(state_field("{}"), content="{\"op\":\"plain\"}")
  inspect(state_field("[]"), content="{\"op\":\"plain\"}")
  inspect(state_field("{"), content="{\"op\":\"plain\"}")
  inspect(strip_assign("{\"assign\":true}"), content="{\"op\":\"state\"}")
  inspect(strip_assign("{\"assign\":false}"), content="{\"op\":\"keep\"}")
  inspect(strip_assign("{\"assign\":1}"), content="{\"op\":\"keep\"}")
  inspect(strip_assign("[]"), content="{\"op\":\"keep\"}")
  inspect(strip_assign("{"), content="{\"op\":\"keep\"}")
}
