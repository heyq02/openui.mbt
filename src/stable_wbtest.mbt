///|
test "stable json matches javascript key order and specials" {
  inspect(stable_stringify("{\"t\":\"z\"}"), content="Snull")
  inspect(stable_stringify("{\"t\":\"b\",\"v\":true}"), content="Strue")
  inspect(stable_stringify("{\"t\":\"b\",\"v\":false}"), content="Sfalse")
  inspect(stable_stringify("{\"t\":\"b\"}"), content="Sfalse")
  inspect(stable_stringify("{\"t\":\"u\"}"), content="S\"__undefined__\"")
  inspect(stable_stringify("{\"t\":\"nan\"}"), content="S\"__NaN__\"")
  inspect(stable_stringify("{\"t\":\"pinf\"}"), content="S\"__Inf__\"")
  inspect(stable_stringify("{\"t\":\"ninf\"}"), content="S\"__-Inf__\"")
  inspect(
    stable_stringify("{\"t\":\"s\",\"v\":\"a\\\"b\"}"),
    content="S\"a\\\"b\"",
  )
  inspect(stable_stringify("{\"t\":\"s\"}"), content="S\"\"")
  inspect(stable_stringify("{\"t\":\"n\",\"v\":1e+21}"), content="S1e+21")
  inspect(stable_stringify("{\"t\":\"n\",\"v\":1e-7}"), content="S1e-7")
  inspect(stable_stringify("{\"t\":\"n\"}"), content="S0")
  inspect(stable_stringify("{\"t\":\"f\"}"), content="U")
  inspect(stable_stringify("{\"t\":\"y\"}"), content="U")
  inspect(stable_stringify("{\"t\":\"big\"}"), content="Ebigint")
  inspect(stable_stringify("1"), content="U")
  inspect(stable_stringify("{\"t\":1}"), content="U")
  inspect(stable_stringify("{\"t\":\"o\",\"v\":[1,[\"only\"]]}"), content="S{}")
  inspect(stable_stringify("{"), content="Eparse")
  inspect(
    stable_stringify(
      "{\"t\":\"a\",\"v\":[{\"t\":\"n\",\"v\":1},{\"t\":\"u\"},{\"t\":\"f\"},{\"t\":\"z\"},{\"t\":\"nan\"}]}",
    ),
    content="S[1,\"__undefined__\",null,null,\"__NaN__\"]",
  )
  inspect(
    stable_stringify("{\"t\":\"a\",\"v\":[{\"t\":\"big\"}]}"),
    content="Ebigint",
  )
  inspect(stable_stringify("{\"t\":\"a\",\"v\":[]}"), content="S[]")
  inspect(
    stable_stringify(
      "{\"t\":\"o\",\"v\":[[\"10\",{\"t\":\"s\",\"v\":\"b\"}],[\"2\",{\"t\":\"s\",\"v\":\"a\"}],[\"b\",{\"t\":\"n\",\"v\":1}],[\"a\",{\"t\":\"u\"}],[\"f\",{\"t\":\"f\"}],[true,{\"t\":\"z\"}],[\"😀\",{\"t\":\"n\",\"v\":3}],[\"\\uE000\",{\"t\":\"n\",\"v\":4}]]}",
    ),
    content="S{\"2\":\"a\",\"10\":\"b\",\"a\":\"__undefined__\",\"b\":1,\"😀\":3,\"\uE000\":4}",
  )
  inspect(
    stable_stringify(
      "{\"t\":\"o\",\"v\":[[\"z\",{\"t\":\"o\",\"v\":[[\"b\",{\"t\":\"n\",\"v\":1}],[\"a\",{\"t\":\"a\",\"v\":[{\"t\":\"n\",\"v\":2},{\"t\":\"o\",\"v\":[[\"d\",{\"t\":\"n\",\"v\":1}],[\"c\",{\"t\":\"n\",\"v\":2}]]}]}]]}],[\"a\",{\"t\":\"n\",\"v\":0}],[\"bad\",1]]}",
    ),
    content="S{\"a\":0,\"z\":{\"a\":[2,{\"c\":2,\"d\":1}],\"b\":1}}",
  )
  inspect(stable_stringify("{\"t\":\"o\",\"v\":[]}"), content="S{}")
  inspect(
    stable_stringify("{\"t\":\"o\",\"v\":[[\"a\",{\"t\":\"big\"}]]}"),
    content="Ebigint",
  )
  inspect(
    stable_stringify(
      "{\"t\":\"o\",\"v\":[[\"10\",{\"t\":\"n\",\"v\":1}],[\"2\",{\"t\":\"n\",\"v\":2}],[\"0\",{\"t\":\"n\",\"v\":0}],[\"00\",{\"t\":\"n\",\"v\":3}],[\"9\",{\"t\":\"n\",\"v\":4}],[\"4294967294\",{\"t\":\"n\",\"v\":5}],[\"4294967295\",{\"t\":\"n\",\"v\":6}],[\"\",{\"t\":\"n\",\"v\":7}],[\"a1\",{\"t\":\"n\",\"v\":8}]]}",
    ),
    content="S{\"0\":0,\"2\":2,\"9\":4,\"10\":1,\"4294967294\":5,\"\":7,\"00\":3,\"4294967295\":6,\"a1\":8}",
  )
  inspect(is_array_index(""), content="false")
  inspect(is_array_index("0"), content="true")
  inspect(is_array_index("00"), content="false")
  inspect(is_array_index("10"), content="true")
  inspect(is_array_index("4294967294"), content="true")
  inspect(is_array_index("4294967295"), content="false")
  inspect(is_array_index("4294967296"), content="false")
  inspect(is_array_index("10000000000"), content="false")
  inspect(is_array_index("a"), content="false")
  inspect(is_array_index("1a"), content="false")
  inspect(utf16_before("B", "a"), content="true")
  inspect(utf16_before("a", "B"), content="false")
  inspect(utf16_before("a", "a"), content="false")
  inspect(utf16_before("a", "ab"), content="true")
  inspect(utf16_before("ab", "a"), content="false")
  inspect(utf16_before("😀", "\uE000"), content="true")
  inspect(utf16_before("\uE000", "😀"), content="false")
  inspect(pairs_of(@json.parse("{\"t\":\"o\"}")).length(), content="0")
  inspect(pairs_of(@json.parse("[]")).length(), content="0")
}
