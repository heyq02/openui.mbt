///|
test "openui eager action steps match String conversion" {
  inspect(
    eager_step("OpenUrl", "{}"),
    content="{\"op\":\"open_url\",\"url\":\"\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"null\"}}"),
    content="{\"op\":\"open_url\",\"url\":\"\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"u\"}}"),
    content="{\"op\":\"open_url\",\"url\":\"\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"s\",\"v\":\"https://e.com\"}}"),
    content="{\"op\":\"open_url\",\"url\":\"https://e.com\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"s\",\"v\":\"a\\\"b\\n\"}}"),
    content="{\"op\":\"open_url\",\"url\":\"a\\\"b\\n\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"n\",\"v\":1}}"),
    content="{\"op\":\"open_url\",\"url\":\"1\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"nan\"}}"),
    content="{\"op\":\"open_url\",\"url\":\"NaN\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"pinf\"}}"),
    content="{\"op\":\"open_url\",\"url\":\"Infinity\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"ninf\"}}"),
    content="{\"op\":\"open_url\",\"url\":\"-Infinity\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"n0\"}}"),
    content="{\"op\":\"open_url\",\"url\":\"0\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"n\",\"j\":\"1e+21\",\"v\":1}}"),
    content="{\"op\":\"open_url\",\"url\":\"1e+21\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"b\",\"v\":true}}"),
    content="{\"op\":\"open_url\",\"url\":\"true\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"b\"}}"),
    content="{\"op\":\"open_url\",\"url\":\"false\"}",
  )
  inspect(
    eager_step(
      "OpenUrl", "{\"url\":{\"t\":\"a\",\"v\":[{\"t\":\"n\",\"v\":1},{\"t\":\"null\"},{\"t\":\"u\"},{\"t\":\"hole\"},{\"t\":\"o\"},{\"t\":\"a\",\"v\":[{\"t\":\"s\",\"v\":\"a\"},{\"t\":\"s\",\"v\":\"b\"}]}]}}",
    ),
    content="{\"op\":\"open_url\",\"url\":\"1,,,,[object Object],a,b\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"o\",\"j\":\"DATE\"}}"),
    content="{\"op\":\"open_url\",\"url\":\"DATE\"}",
  )
  inspect(
    eager_step(
      "OpenUrl", "{\"url\":{\"t\":\"x\",\"j\":\"Symbol(s)\",\"sym\":true}}",
    ),
    content="{\"op\":\"open_url\",\"url\":\"Symbol(s)\"}",
  )
  inspect(
    eager_step(
      "OpenUrl", "{\"url\":{\"t\":\"a\",\"v\":[{\"t\":\"x\",\"j\":\"Symbol(s)\",\"sym\":true}]}}",
    ),
    content="{\"op\":\"throw\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"o\",\"throw\":true}}"),
    content="{\"op\":\"throw\"}",
  )
  inspect(eager_step("OpenUrl", "{"), content="{\"op\":\"none\"}")
  inspect(
    eager_step("ToAssistant", "{\"message\":{\"t\":\"s\",\"v\":\"Ask\"}}"),
    content="{\"op\":\"continue\",\"message\":\"Ask\"}",
  )
  inspect(
    eager_step("ToAssistant", "{}"),
    content="{\"op\":\"continue\",\"message\":\"\"}",
  )
  inspect(eager_step("Action", "{}"), content="{\"op\":\"none\"}")
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"n\",\"j\":1,\"v\":4}}"),
    content="{\"op\":\"open_url\",\"url\":\"4\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"n\",\"v\":\"4\"}}"),
    content="{\"op\":\"open_url\",\"url\":\"4\"}",
  )
  inspect(
    eager_step("OpenUrl", "{\"url\":{\"t\":\"n\",\"v\":true}}"),
    content="{\"op\":\"open_url\",\"url\":\"0\"}",
  )
  inspect(
    eager_step("ToAssistant", "{\"message\":{\"t\":\"o\",\"throw\":true}}"),
    content="{\"op\":\"throw\"}",
  )
}
