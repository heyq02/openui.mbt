///|
test "split ranges follow the official statement scan" {
  inspect(
    split_ranges("[16,9,15,13]"),
    content="[{\"idAt\":0,\"t\":16,\"ix\":[2]}]",
  )
  inspect(split_ranges("[]"), content="[]")
  inspect(split_ranges("[0,0,13]"), content="[]")
  inspect(split_ranges("[13,16,9,15]"), content="[]")
  inspect(
    split_ranges("[15,9,15,0,16,9,15]"),
    content="[{\"idAt\":4,\"t\":16,\"ix\":[6]}]",
  )
  inspect(
    split_ranges("[16,15,0,17,9,16,1,2,13]"),
    content="[{\"idAt\":3,\"t\":17,\"ix\":[5,6,7]}]",
  )
  inspect(
    split_ranges("[18,9,15,13]"),
    content="[{\"idAt\":0,\"t\":18,\"ix\":[2]}]",
  )
  inspect(split_ranges("[16,9,0,13]"), content="[]")
  inspect(split_ranges("[16]"), content="[]")
  inspect(
    split_ranges("[16,9,15,0,34,15,8,15,13]"),
    content="[{\"idAt\":0,\"t\":16,\"ix\":[2,4,5,6,7]}]",
  )
  inspect(
    split_ranges("[16,9,15,0,8,15,13]"),
    content="[{\"idAt\":0,\"t\":16,\"ix\":[2]}]",
  )
  inspect(
    split_ranges("[16,9,15,0]"),
    content="[{\"idAt\":0,\"t\":16,\"ix\":[2]}]",
  )
  inspect(
    split_ranges("[16,9,16,1,0,15,2,13]"),
    content="[{\"idAt\":0,\"t\":16,\"ix\":[2,3,5,6]}]",
  )
  inspect(
    split_ranges("[16,9,1,3,5,0,6,4,2,13]"),
    content="[{\"idAt\":0,\"t\":16,\"ix\":[2,3,4,6,7,8]}]",
  )
  inspect(
    split_ranges("[16,9,16,1,34,2,0,34,15,8,15,13]"),
    content="[{\"idAt\":0,\"t\":16,\"ix\":[2,3,4,5,7,8,9,10]}]",
  )
  inspect(
    split_ranges("[16,9,2,4,6,15,13]"),
    content="[{\"idAt\":0,\"t\":16,\"ix\":[2,3,4,5]}]",
  )
  inspect(
    split_ranges("[16,9,15,0,0,34,15,13]"),
    content="[{\"idAt\":0,\"t\":16,\"ix\":[2,5,6]}]",
  )
  inspect(
    split_ranges("[16,9,15,0,16,9,16,13]"),
    content="[{\"idAt\":0,\"t\":16,\"ix\":[2]},{\"idAt\":4,\"t\":16,\"ix\":[6]}]",
  )
  inspect(split_ranges("[16.5,9,15,13]"), content="[]")
  inspect(split_ranges("[36,9,15,13]"), content="[]")
  inspect(split_ranges("[-1,13]"), content="[]")
  inspect(split_ranges("[null,13]"), content="[]")
  inspect(split_ranges("[true]"), content="[]")
  inspect(split_ranges("[\"16\",9,15]"), content="[]")
  inspect(split_ranges("[1e21,9,15,13]"), content="[]")
  inspect(split_ranges("{\"t\":16}"), content="[]")
  inspect(split_ranges("}"), content="[]")
  inspect(split_continues(34, 0), content="true")
  inspect(split_continues(8, 1), content="true")
  inspect(split_continues(8, 0), content="false")
  inspect(split_continues(13, 0), content="false")
}
