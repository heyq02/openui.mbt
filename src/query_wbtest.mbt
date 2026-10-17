///|
test "query slots and errors choose the official snapshot fields" {
  inspect(
    query_slot("{\"phase\":\"value\",\"data\":true}"),
    content="{\"op\":\"data\"}",
  )
  inspect(
    query_slot(
      "{\"phase\":\"value\",\"data\":true,\"prev\":true,\"prevData\":true}",
    ),
    content="{\"op\":\"data\"}",
  )
  inspect(
    query_slot(
      "{\"phase\":\"value\",\"data\":false,\"prev\":true,\"prevData\":true}",
    ),
    content="{\"op\":\"prev\"}",
  )
  inspect(
    query_slot(
      "{\"phase\":\"value\",\"data\":false,\"prev\":true,\"prevData\":false}",
    ),
    content="{\"op\":\"defaults\"}",
  )
  inspect(
    query_slot("{\"phase\":\"value\",\"prev\":false}"),
    content="{\"op\":\"defaults\"}",
  )
  inspect(
    query_slot(
      "{\"phase\":\"flags\",\"loading\":true,\"ever\":true,\"error\":true}",
    ),
    content="{\"load\":true,\"refetch\":true,\"error\":true}",
  )
  inspect(
    query_slot(
      "{\"phase\":\"flags\",\"loading\":true,\"ever\":false,\"error\":false}",
    ),
    content="{\"load\":true,\"refetch\":false,\"error\":false}",
  )
  inspect(
    query_slot(
      "{\"phase\":\"flags\",\"loading\":false,\"ever\":true,\"error\":true}",
    ),
    content="{\"load\":false,\"refetch\":false,\"error\":true}",
  )
  inspect(
    query_slot("{\"phase\":\"flags\"}"),
    content="{\"load\":false,\"refetch\":false,\"error\":false}",
  )
  inspect(query_slot("{\"phase\":\"later\"}"), content="{\"op\":\"defaults\"}")
  inspect(query_slot("{\"phase\":1}"), content="{\"op\":\"defaults\"}")
  inspect(query_slot("{"), content="{\"op\":\"defaults\"}")
  inspect(query_slot("[]"), content="{\"op\":\"defaults\"}")
  inspect(
    query_error(
      "{\"source\":\"query\",\"kind\":\"missing\",\"tool\":\"weather\",\"detail\":\"\"}",
    ),
    content="{\"source\":\"query\",\"code\":\"tool-not-found\",\"message\":\"Query tool \\\"weather\\\" not found\",\"statementId\":null,\"component\":\"Query\",\"toolName\":\"weather\",\"hint\":null}",
  )
  inspect(
    query_error(
      "{\"source\":\"query\",\"kind\":\"mcp\",\"tool\":\"weather\",\"detail\":\"nope\"}",
    ),
    content="{\"source\":\"query\",\"code\":\"mcp-error\",\"message\":\"Query \\\"weather\\\" returned an error: nope\",\"statementId\":null,\"component\":\"Query\",\"toolName\":\"weather\"}",
  )
  inspect(
    query_error(
      "{\"source\":\"query\",\"kind\":\"other\",\"tool\":\"weather\",\"detail\":\"down\"}",
    ),
    content="{\"source\":\"query\",\"code\":\"tool-error\",\"message\":\"Query \\\"weather\\\" failed: down\",\"statementId\":null,\"component\":\"Query\",\"toolName\":\"weather\"}",
  )
  inspect(
    query_error(
      "{\"source\":\"mutation\",\"kind\":\"missing\",\"tool\":\"save\",\"detail\":\"\"}",
    ),
    content="{\"source\":\"mutation\",\"code\":\"tool-not-found\",\"message\":\"Mutation tool \\\"save\\\" not found\",\"statementId\":null,\"component\":\"Mutation\",\"toolName\":\"save\",\"hint\":null}",
  )
  inspect(
    query_error(
      "{\"source\":\"mutation\",\"kind\":\"mcp\",\"tool\":\"save\",\"detail\":\"bad\"}",
    ),
    content="{\"source\":\"mutation\",\"code\":\"mcp-error\",\"message\":\"Mutation \\\"save\\\" returned an error: bad\",\"statementId\":null,\"component\":\"Mutation\",\"toolName\":\"save\"}",
  )
  inspect(
    query_error(
      "{\"source\":\"mutation\",\"kind\":\"other\",\"tool\":\"save\",\"detail\":\"down\"}",
    ),
    content="{\"source\":\"mutation\",\"code\":\"tool-error\",\"message\":\"Mutation \\\"save\\\" failed: down\",\"statementId\":null,\"component\":\"Mutation\",\"toolName\":\"save\"}",
  )
  inspect(
    query_error(
      "{\"source\":\"other\",\"kind\":\"later\",\"tool\":\"\",\"detail\":\"\"}",
    ),
    content="{\"source\":\"query\",\"code\":\"tool-error\",\"message\":\"Query \\\"\\\" failed: \",\"statementId\":null,\"component\":\"Query\",\"toolName\":\"\"}",
  )
  inspect(
    query_error("{"),
    content="{\"source\":\"query\",\"code\":\"tool-error\",\"message\":\"Query \\\"\\\" failed: \",\"statementId\":null,\"component\":\"Query\",\"toolName\":\"\"}",
  )
}
