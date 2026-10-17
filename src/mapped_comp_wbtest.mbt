///|
test "mapped props choose state refs, reactive assignment, and child elements" {
  inspect(
    mapped_comp("{\"phase\":\"open\",\"mapped\":true}"),
    content="{\"op\":\"props\"}",
  )
  inspect(
    mapped_comp("{\"phase\":\"open\",\"mapped\":false}"),
    content="{\"op\":\"warn\"}",
  )
  inspect(
    mapped_comp("{\"phase\":\"open\",\"mapped\":1}"),
    content="{\"op\":\"warn\"}",
  )
  inspect(mapped_comp("{\"phase\":\"open\"}"), content="{\"op\":\"warn\"}")
  inspect(
    mapped_comp("{\"phase\":\"prop\",\"state\":true,\"reactive\":true}"),
    content="{\"op\":\"assign\"}",
  )
  inspect(
    mapped_comp("{\"phase\":\"prop\",\"state\":true,\"reactive\":false}"),
    content="{\"op\":\"state\"}",
  )
  inspect(
    mapped_comp("{\"phase\":\"prop\",\"state\":false,\"reactive\":true}"),
    content="{\"op\":\"eval\"}",
  )
  inspect(
    mapped_comp("{\"phase\":\"prop\",\"state\":false,\"reactive\":false}"),
    content="{\"op\":\"eval\"}",
  )
  inspect(
    mapped_comp("{\"phase\":\"prop\",\"state\":1,\"reactive\":true}"),
    content="{\"op\":\"eval\"}",
  )
  inspect(mapped_comp("{\"phase\":\"prop\"}"), content="{\"op\":\"eval\"}")
  inspect(
    mapped_comp("{\"phase\":\"finish\",\"schema\":true}"),
    content="{\"op\":\"walk\"}",
  )
  inspect(
    mapped_comp("{\"phase\":\"finish\",\"schema\":false}"),
    content="{\"op\":\"done\"}",
  )
  inspect(
    mapped_comp("{\"phase\":\"finish\",\"schema\":1}"),
    content="{\"op\":\"done\"}",
  )
  inspect(
    mapped_comp("{\"phase\":\"child\",\"element\":true,\"array\":true}"),
    content="{\"op\":\"inline\"}",
  )
  inspect(
    mapped_comp("{\"phase\":\"child\",\"element\":false,\"array\":true}"),
    content="{\"op\":\"list\"}",
  )
  inspect(
    mapped_comp("{\"phase\":\"child\",\"element\":false,\"array\":false}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(mapped_comp("{\"phase\":\"other\"}"), content="{\"op\":\"keep\"}")
  inspect(mapped_comp("{\"phase\":1}"), content="{\"op\":\"keep\"}")
  inspect(mapped_comp("[]"), content="{\"op\":\"keep\"}")
  inspect(mapped_comp("{"), content="{\"op\":\"keep\"}")
}
