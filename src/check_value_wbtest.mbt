///|
test "field checks choose empty values, messages, and rule stops" {
  inspect(
    check_value("{\"phase\":\"blank\",\"nil\":true}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    check_value("{\"phase\":\"blank\",\"empty\":true}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    check_value("{\"phase\":\"blank\",\"nil\":true,\"empty\":true}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    check_value("{\"phase\":\"blank\",\"nil\":false,\"empty\":false}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    check_value("{\"phase\":\"blank\",\"nil\":1}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(
    check_value("{\"phase\":\"wrap\",\"has\":true}"),
    content="{\"op\":\"dive\"}",
  )
  inspect(
    check_value("{\"phase\":\"wrap\",\"has\":false}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(check_value("{\"phase\":\"wrap\"}"), content="{\"op\":\"keep\"}")
  inspect(
    check_value("{\"phase\":\"keys\",\"n\":0}"),
    content="{\"op\":\"empty\"}",
  )
  inspect(
    check_value("{\"phase\":\"keys\",\"n\":2}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(check_value("{\"phase\":\"keys\"}"), content="{\"op\":\"keep\"}")
  inspect(
    check_value("{\"phase\":\"keys\",\"n\":\"0\"}"),
    content="{\"op\":\"keep\"}",
  )
  inspect(check_value("{\"phase\":\"done\"}"), content="{\"op\":\"keep\"}")
  inspect(
    check_value("{\"phase\":\"msg\",\"code\":\"required\"}"),
    content="{\"op\":\"fail\",\"text\":\"This field is required\"}",
  )
  inspect(
    check_value("{\"phase\":\"msg\",\"code\":\"options\"}"),
    content="{\"op\":\"fail\",\"text\":\"At least one option is required\"}",
  )
  inspect(
    check_value("{\"phase\":\"msg\",\"code\":\"email\"}"),
    content="{\"op\":\"fail\",\"text\":\"Please enter a valid email\"}",
  )
  inspect(
    check_value("{\"phase\":\"msg\",\"code\":\"url\"}"),
    content="{\"op\":\"fail\",\"text\":\"Please enter a valid URL\"}",
  )
  inspect(
    check_value("{\"phase\":\"msg\",\"code\":\"numeric\"}"),
    content="{\"op\":\"fail\",\"text\":\"Must be a number\"}",
  )
  inspect(
    check_value("{\"phase\":\"msg\",\"code\":\"format\"}"),
    content="{\"op\":\"fail\",\"text\":\"Invalid format\"}",
  )
  inspect(
    check_value("{\"phase\":\"msg\",\"code\":\"other\"}"),
    content="{\"op\":\"skip\"}",
  )
  inspect(
    check_value("{\"phase\":\"msg\",\"code\":1}"),
    content="{\"op\":\"skip\"}",
  )
  inspect(
    check_value("{\"phase\":\"bound\",\"kind\":\"min\",\"ok\":true}"),
    content="{\"op\":\"skip\"}",
  )
  inspect(
    check_value("{\"phase\":\"bound\",\"kind\":\"min\",\"ok\":false}"),
    content="{\"op\":\"fail\",\"code\":\"min\"}",
  )
  inspect(
    check_value("{\"phase\":\"bound\",\"kind\":\"max\",\"ok\":false}"),
    content="{\"op\":\"fail\",\"code\":\"max\"}",
  )
  inspect(
    check_value("{\"phase\":\"bound\",\"kind\":\"minLength\",\"ok\":false}"),
    content="{\"op\":\"fail\",\"code\":\"minLength\"}",
  )
  inspect(
    check_value("{\"phase\":\"bound\",\"kind\":\"maxLength\",\"ok\":false}"),
    content="{\"op\":\"fail\",\"code\":\"maxLength\"}",
  )
  inspect(
    check_value("{\"phase\":\"bound\",\"kind\":\"other\",\"ok\":false}"),
    content="{\"op\":\"skip\"}",
  )
  inspect(
    check_value("{\"phase\":\"bound\",\"kind\":\"min\",\"ok\":1}"),
    content="{\"op\":\"fail\",\"code\":\"min\"}",
  )
  inspect(
    check_value("{\"phase\":\"rule\",\"known\":false,\"hit\":true}"),
    content="{\"op\":\"warn\"}",
  )
  inspect(
    check_value("{\"phase\":\"rule\",\"known\":true,\"hit\":true}"),
    content="{\"op\":\"stop\"}",
  )
  inspect(
    check_value("{\"phase\":\"rule\",\"known\":true,\"hit\":false}"),
    content="{\"op\":\"next\"}",
  )
  inspect(
    check_value("{\"phase\":\"rule\",\"known\":\"yes\"}"),
    content="{\"op\":\"warn\"}",
  )
  inspect(check_value("{\"phase\":\"other\"}"), content="{\"op\":\"keep\"}")
  inspect(check_value("[]"), content="{\"op\":\"keep\"}")
  inspect(check_value("{"), content="{\"op\":\"keep\"}")
}
