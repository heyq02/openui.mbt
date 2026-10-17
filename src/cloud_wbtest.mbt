///|
fn cloud_err(message : String) -> String {
  "{\"t\":\"err\",\"m\":" + json_string(message) + "}"
}

///|
fn cloud_spec(
  library : String,
  examples : Bool,
  preamble : Bool,
  rules : Bool,
) -> String {
  let examples_text = if examples { "true" } else { "false" }
  let preamble_text = if preamble { "true" } else { "false" }
  let rules_text = if rules { "true" } else { "false" }
  "{\"hasLibrary\":true,\"hasPromptOptions\":true,\"examples\":" +
  examples_text +
  ",\"preamble\":" +
  preamble_text +
  ",\"rules\":" +
  rules_text +
  ",\"library\":" +
  library +
  "}"
}

///|
fn cloud_lib(entries : String) -> String {
  "{\"t\":\"o\",\"v\":[" + entries + "]}"
}

///|
let card_defs = "{\"t\":\"o\",\"v\":[[\"$defs\",{\"t\":\"o\",\"v\":[[\"Card\",{\"t\":\"o\",\"v\":[]}]]}]]}"

///|
fn cloud_card(tail : String) -> String {
  cloud_lib("[\"schema\"," + card_defs + "]" + tail)
}

///|
test "openui cloud config decides library issues" {
  let invalid = "[generateSystemPrompt] Invalid library: "
  let root_shape = "chatLibrary.root, when present, must be a non-empty string."
  let schema_shape = "chatLibrary.schema must be an object with a $defs map of component schemas."
  let defs_shape = "chatLibrary.schema.$defs must be a non-empty object keyed by component name."
  let group_shape = "Each componentGroups entry must be {name: string, components: string[], notes?: string[]}."
  inspect(cloud_config("{}"), content="{\"t\":\"version\"}")
  inspect(
    cloud_config(
      "{\"hasLibrary\":false,\"hasPromptOptions\":false,\"examples\":true,\"preamble\":false,\"rules\":false}",
    ),
    content="{\"t\":\"version\"}",
  )
  inspect(
    cloud_config(
      "{\"hasLibrary\":false,\"hasPromptOptions\":true,\"examples\":false,\"preamble\":false,\"rules\":false}",
    ),
    content="{\"t\":\"version\"}",
  )
  inspect(
    cloud_config("{\"hasPromptOptions\":true,\"examples\":true}"),
    content=cloud_err(
      "[generateSystemPrompt] promptOptions requires a library — the built-in library ignores it.",
    ),
  )
  inspect(cloud_config("{"), content="{\"t\":\"err\",\"m\":\"\"}")
  inspect(
    cloud_config("{\"hasLibrary\":true}"),
    content=cloud_err(invalid + "chatLibrary must be an object."),
  )
  inspect(
    cloud_config(cloud_spec("{\"t\":\"a\",\"v\":[]}", false, false, false)),
    content=cloud_err(invalid + "chatLibrary must be an object."),
  )
  inspect(
    cloud_config(cloud_spec("{\"v\":[]}", false, false, false)),
    content=cloud_err(invalid + "chatLibrary must be an object."),
  )
  inspect(
    cloud_config(cloud_spec(cloud_lib(""), false, false, false)),
    content=cloud_err(invalid + schema_shape),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_lib("[\"schema\",{\"t\":\"o\",\"v\":\"nope\"}]"),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(invalid + defs_shape),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_lib(
          "\"nope\",[\"only\"],[1,{\"t\":\"s\",\"v\":\"z\"}],[\"root\",{\"t\":\"s\",\"v\":\"\"}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(invalid + root_shape + " " + schema_shape),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_lib(
          "[\"root\",{\"t\":\"s\",\"v\":1}],[\"schema\",{\"t\":\"a\",\"v\":[]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(invalid + root_shape + " " + schema_shape),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_lib(
          "[\"root\",{\"t\":\"u\"}],[\"schema\",{\"t\":\"o\",\"v\":[[\"$defs\",{\"t\":\"a\",\"v\":[]}]]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(invalid + defs_shape),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_lib(
          "[\"schema\",{\"t\":\"o\",\"v\":[[\"$defs\",{\"t\":\"o\",\"v\":[]}]]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(invalid + defs_shape),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_lib(
          "[\"root\",{\"t\":\"s\",\"v\":\"Nope\"}],[\"schema\",{\"t\":\"o\",\"v\":[[\"$defs\",{\"t\":\"o\",\"v\":[[\"Card\",{\"t\":\"o\",\"v\":[]}],[\"Row\",{\"t\":\"z\"}]]}]]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(
      invalid +
      "Root component \"Nope\" was not found in schema.$defs. Available components: Card, Row. $defs/Row must be an object component schema.",
    ),
  )
  let props = "{\"t\":\"o\",\"v\":[[\"properties\",{\"t\":\"z\"}],[\"required\",{\"t\":\"a\",\"v\":[{\"t\":\"h\"},{\"t\":\"s\",\"v\":\"missing\"},{\"t\":\"s\",\"v\":\"title\"},{\"t\":\"s\"}]}]]}"
  let refs = "{\"t\":\"o\",\"v\":[[\"properties\",{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"s\",\"v\":\"#/$defs/Nope\"}],[\"title\",{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"s\",\"v\":\"#/$defs/Card\"}]]}],[\"body\",{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"s\",\"v\":\"#/$defs/Foo\\n\"}]]}],[\"cr\",{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"s\",\"v\":\"#/$defs/Foo\\r\"}]]}],[\"ls\",{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"s\",\"v\":\"#/$defs/Foo\\u2028\"}]]}],[\"ps\",{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"s\",\"v\":\"#/$defs/Foo\\u2029\"}]]}],[\"short\",{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"s\",\"v\":\"#/$defs/\"}]]}],[\"bad\",{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"s\",\"v\":\"#/defs/Card\"}]]}],[\"list\",{\"t\":\"a\",\"v\":[{\"t\":\"h\"},{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"s\",\"v\":\"#/$defs/Missing\"}]]}]}],[\"skip\",{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"s\",\"v\":\"#/$defs/Nope\"}]]}]]}],[\"num\",{\"t\":\"n\",\"v\":1}],[\"ok\",{\"t\":\"s\",\"v\":\"plain\"}],[1,{\"t\":\"o\",\"v\":[]}],\"junk\"]}],[\"required\",{\"t\":\"a\",\"v\":[{\"t\":\"s\",\"v\":\"title\"}]}]]}"
  let arr = "{\"t\":\"o\",\"v\":[[\"properties\",{\"t\":\"a\",\"v\":[{\"t\":\"h\"},{\"t\":\"o\",\"v\":[[\"$ref\",{\"t\":\"s\",\"v\":\"#/$defs/Nope\"}]]}]}],[\"required\",{\"t\":\"n\",\"v\":1}]]}"
  let good = "{\"t\":\"o\",\"v\":[[\"properties\",{\"t\":\"o\",\"v\":[[\"title\",{\"t\":\"o\",\"v\":[]}]]}],[\"required\",{\"t\":\"a\",\"v\":[{\"t\":\"s\",\"v\":\"title\"}]}]]}"
  let undef = "{\"t\":\"o\",\"v\":[[\"properties\",{\"t\":\"u\"}],[\"required\",{\"t\":\"u\"}]]}"
  inspect(
    cloud_config(
      cloud_spec(
        cloud_lib(
          "[\"schema\",{\"t\":\"o\",\"v\":[[\"$defs\",{\"t\":\"o\",\"v\":[[\"Card\",{\"t\":\"o\",\"v\":[]}],\"bad\",[\"short\"],[1,{\"t\":\"o\",\"v\":[]}],[\"Bad\",{\"t\":\"n\",\"v\":1}],[\"Props\"," +
          props +
          "],[\"Refs\"," +
          refs +
          "],[\"Arr\"," +
          arr +
          "],[\"Good\"," +
          good +
          "],[\"Undef\"," +
          undef +
          "]]}]]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(
      invalid +
      "$defs/Bad must be an object component schema. " +
      "$defs/Props/properties must be an object. " +
      "$defs/Props lists required property \"undefined\" that is not in properties. " +
      "$defs/Props lists required property \"missing\" that is not in properties. " +
      "$defs/Props lists required property \"title\" that is not in properties. " +
      "$defs/Props lists required property \"\" that is not in properties. " +
      "Unresolvable $ref \"#/$defs/Nope\" at $defs/Refs/properties — refs must be \"#/$defs/<name>\" pointing at a component in $defs. " +
      "Unresolvable $ref \"#/$defs/Foo\n\" at $defs/Refs/properties/body — refs must be \"#/$defs/<name>\" pointing at a component in $defs. " +
      "Unresolvable $ref \"#/$defs/Foo\r\" at $defs/Refs/properties/cr — refs must be \"#/$defs/<name>\" pointing at a component in $defs. " +
      "Unresolvable $ref \"#/$defs/Foo\u{2028}\" at $defs/Refs/properties/ls — refs must be \"#/$defs/<name>\" pointing at a component in $defs. " +
      "Unresolvable $ref \"#/$defs/Foo\u{2029}\" at $defs/Refs/properties/ps — refs must be \"#/$defs/<name>\" pointing at a component in $defs. " +
      "Unresolvable $ref \"#/$defs/\" at $defs/Refs/properties/short — refs must be \"#/$defs/<name>\" pointing at a component in $defs. " +
      "Unresolvable $ref \"#/defs/Card\" at $defs/Refs/properties/bad — refs must be \"#/$defs/<name>\" pointing at a component in $defs. " +
      "Unresolvable $ref \"#/$defs/Missing\" at $defs/Refs/properties/list/1 — refs must be \"#/$defs/<name>\" pointing at a component in $defs. " +
      "$defs/Arr/properties must be an object. " +
      "$defs/Arr/required must be an array of property names. " +
      "Unresolvable $ref \"#/$defs/Nope\" at $defs/Arr/properties/1 — refs must be \"#/$defs/<name>\" pointing at a component in $defs.",
    ),
  )
  let plain = cloud_card("")
  inspect(
    cloud_config(cloud_spec(plain, false, false, false)),
    content="{\"t\":\"lib\",\"options\":[]}",
  )
  inspect(
    cloud_config(cloud_spec(plain, true, false, false)),
    content="{\"t\":\"lib\",\"options\":[\"examples\"]}",
  )
  inspect(
    cloud_config(cloud_spec(plain, false, true, false)),
    content="{\"t\":\"lib\",\"options\":[\"preamble\"]}",
  )
  inspect(
    cloud_config(cloud_spec(plain, false, false, true)),
    content="{\"t\":\"lib\",\"options\":[\"additionalRules\"]}",
  )
  inspect(
    cloud_config(cloud_spec(plain, true, true, false)),
    content="{\"t\":\"lib\",\"options\":[\"examples\",\"preamble\"]}",
  )
  inspect(
    cloud_config(cloud_spec(plain, true, false, true)),
    content="{\"t\":\"lib\",\"options\":[\"examples\",\"additionalRules\"]}",
  )
  inspect(
    cloud_config(cloud_spec(plain, false, true, true)),
    content="{\"t\":\"lib\",\"options\":[\"preamble\",\"additionalRules\"]}",
  )
  inspect(
    cloud_config(cloud_spec(plain, true, true, true)),
    content="{\"t\":\"lib\",\"options\":[\"examples\",\"preamble\",\"additionalRules\"]}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(",[\"componentGroups\",{\"t\":\"z\"}]"),
        false,
        false,
        false,
      ),
    ),
    content="{\"t\":\"lib\",\"options\":[]}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(",[\"componentGroups\",{\"t\":\"u\"}]"),
        false,
        false,
        false,
      ),
    ),
    content="{\"t\":\"lib\",\"options\":[]}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(",[\"componentGroups\",{\"t\":\"s\",\"v\":\"\"}]"),
        false,
        false,
        false,
      ),
    ),
    content="{\"t\":\"lib\",\"options\":[]}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(",[\"componentGroups\",{\"t\":\"s\"}]"),
        false,
        false,
        false,
      ),
    ),
    content="{\"t\":\"lib\",\"options\":[]}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(",[\"componentGroups\",{\"t\":\"n\",\"v\":1}]"),
        false,
        false,
        false,
      ),
    ),
    content="{\"t\":\"throw\"}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_lib(
          "[\"schema\",{\"t\":\"n\",\"v\":1}],[\"componentGroups\",{\"t\":\"n\",\"v\":1}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(invalid + schema_shape),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(",[\"componentGroups\",{\"t\":\"o\",\"v\":[]}]"),
        false,
        false,
        false,
      ),
    ),
    content="{\"t\":\"throw\"}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(",[\"componentGroups\",{\"t\":\"b\",\"v\":true}]"),
        false,
        false,
        false,
      ),
    ),
    content="{\"t\":\"throw\"}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(",[\"componentGroups\",{\"t\":\"s\",\"v\":\"ab\"}]"),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(invalid + group_shape + " " + group_shape),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(",[\"componentGroups\",{\"t\":\"s\",\"v\":\"😀\"}]"),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(invalid + group_shape),
  )
  let named = "{\"t\":\"o\",\"v\":[[\"name\",{\"t\":\"s\",\"v\":\"Main\"}],[\"components\",{\"t\":\"a\",\"v\":[{\"t\":\"s\",\"v\":\"Card\"},{\"t\":\"s\",\"v\":\"Missing\"},{\"t\":\"n\",\"v\":\"nan\"},{\"t\":\"n\",\"v\":\"inf\"},{\"t\":\"n\",\"v\":\"-inf\"},{\"t\":\"n\",\"v\":\"-0\"},{\"t\":\"n\",\"v\":1},{\"t\":\"n\"},{\"t\":\"n\",\"j\":\"1e+21\",\"v\":\"0\"},{\"t\":\"b\",\"v\":true},{\"t\":\"b\",\"v\":false},{\"t\":\"b\"},{\"t\":\"z\"},{\"t\":\"u\"},{\"t\":\"h\"},{\"t\":\"a\",\"v\":[{\"t\":\"z\"},{\"t\":\"u\"},{\"t\":\"h\"},{\"t\":\"n\",\"v\":2},{\"t\":\"o\",\"v\":[]}]},{\"t\":\"o\",\"j\":\"DATE\",\"v\":[]},{\"t\":\"o\",\"v\":[]},{\"t\":\"x\"},{\"t\":\"s\",\"v\":1},{\"t\":\"n\",\"j\":1,\"v\":4},{\"t\":\"a\",\"v\":[{\"t\":\"a\",\"v\":[{\"t\":\"n\",\"v\":1},{\"t\":\"n\",\"v\":2}]},{\"t\":\"s\",\"v\":\"a,b\"}]}]}]]}"
  let shapes = "[{\"t\":\"h\"},{\"t\":\"n\",\"v\":1},{\"t\":\"o\",\"v\":[]},{\"t\":\"o\",\"v\":[[\"components\",{\"t\":\"a\",\"v\":[]}]]},{\"t\":\"o\",\"v\":[[\"name\",{\"t\":\"n\",\"v\":1}]]},{\"t\":\"o\",\"v\":[[\"name\",{\"t\":\"s\",\"v\":\"Main\"}]]},{\"t\":\"o\",\"v\":[[\"name\",{\"t\":\"s\",\"v\":\"Main\"}],[\"components\",{\"t\":\"n\",\"v\":1}]]}," +
    named +
    "]"
  fn unknown(text : String) -> String {
    "Component group \"Main\" references unknown component \"" + text + "\"."
  }
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(",[\"componentGroups\",{\"t\":\"a\",\"v\":" + shapes + "}]"),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(
      invalid +
      group_shape +
      " " +
      group_shape +
      " " +
      group_shape +
      " " +
      group_shape +
      " " +
      group_shape +
      " " +
      group_shape +
      " " +
      group_shape +
      " " +
      unknown("Missing") +
      " " +
      unknown("NaN") +
      " " +
      unknown("Infinity") +
      " " +
      unknown("-Infinity") +
      " " +
      unknown("0") +
      " " +
      unknown("1") +
      " " +
      unknown("0") +
      " " +
      unknown("1e+21") +
      " " +
      unknown("true") +
      " " +
      unknown("false") +
      " " +
      unknown("false") +
      " " +
      unknown("null") +
      " " +
      unknown("undefined") +
      " " +
      unknown("undefined") +
      " " +
      unknown(",,,2,[object Object]") +
      " " +
      unknown("DATE") +
      " " +
      unknown("[object Object]") +
      " " +
      unknown("[object Object]") +
      " " +
      unknown("") +
      " " +
      unknown("4") +
      " " +
      unknown("1,2,a,b"),
    ),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(
          ",[\"componentGroups\",{\"t\":\"a\",\"v\":[{\"t\":\"o\",\"v\":[[\"name\",{\"t\":\"s\",\"v\":\"Main\"}],[\"components\",{\"t\":\"a\",\"v\":\"nope\"}]]}]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content="{\"t\":\"lib\",\"options\":[]}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(
          ",[\"componentGroups\",{\"t\":\"a\",\"v\":[{\"t\":\"o\",\"v\":[[\"name\",{\"t\":\"s\",\"v\":\"Main\"}],[\"components\",{\"t\":\"a\",\"v\":[{\"t\":\"x\",\"throw\":true}]}]]}]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content="{\"t\":\"string\"}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(
          ",[\"componentGroups\",{\"t\":\"a\",\"v\":[{\"t\":\"o\",\"v\":[[\"name\",{\"t\":\"s\",\"v\":\"Main\"}],[\"components\",{\"t\":\"a\",\"v\":[{\"t\":\"x\",\"j\":\"Symbol(s)\",\"sym\":true}]}]]}]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(invalid + unknown("Symbol(s)")),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(
          ",[\"componentGroups\",{\"t\":\"a\",\"v\":[{\"t\":\"o\",\"v\":[[\"name\",{\"t\":\"s\",\"v\":\"Main\"}],[\"components\",{\"t\":\"a\",\"v\":[{\"t\":\"a\",\"v\":[{\"t\":\"x\",\"j\":\"Symbol(s)\",\"sym\":true}]}]}]]}]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content="{\"t\":\"string\"}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_card(
          ",[\"componentGroups\",{\"t\":\"a\",\"v\":[{\"t\":\"o\",\"v\":[[\"name\",{\"t\":\"s\",\"v\":\"Main\"}],[\"components\",{\"t\":\"a\",\"v\":[{\"t\":\"a\",\"v\":[{\"t\":\"x\",\"throw\":true},{\"t\":\"n\",\"v\":1}]}]}]]}]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content="{\"t\":\"string\"}",
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_lib(
          "[\"root\",{\"t\":\"s\",\"v\":\"X\"}],[\"schema\",{\"t\":\"o\",\"v\":[[\"$defs\",{\"t\":\"o\",\"v\":[[1,{\"t\":\"o\",\"v\":[]}]]}]]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(
      invalid +
      "Root component \"X\" was not found in schema.$defs. Available components: .",
    ),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_lib(
          "[\"schema\",{\"t\":\"o\",\"v\":[[\"$defs\",{\"t\":\"o\",\"v\":[[\"Req\",{\"t\":\"o\",\"v\":[[\"required\",{\"t\":\"a\",\"v\":[{\"t\":\"n\",\"v\":1}]}]]}],[\"Need\",{\"t\":\"o\",\"v\":[[\"required\",{\"t\":\"a\",\"v\":[{\"t\":\"s\",\"v\":\"title\"}]}]]}]]}]]}]",
        ),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(
      invalid +
      "$defs/Req/required must be an array of property names. " +
      "$defs/Need lists required property \"title\" that is not in properties.",
    ),
  )
  inspect(
    cloud_config(
      cloud_spec(
        cloud_lib(
          "[\"root\",{\"t\":\"n\",\"v\":1}],[\"schema\"," + card_defs + "]",
        ),
        false,
        false,
        false,
      ),
    ),
    content=cloud_err(invalid + root_shape),
  )
}
