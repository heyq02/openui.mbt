///|
fn is_done(step : String) -> Bool {
  step.length() >= 8 && step.unsafe_substring(start=0, end=8) == "{\"done\":"
}

///|
fn drive(ast : String, answers : Array[String]) -> String {
  let mut step = eval_start(ast)
  let mut index = 0
  while !is_done(step) {
    let answer = if index < answers.length() {
      answers[index]
    } else {
      "{\"id\":0}"
    }
    index = index + 1
    step = eval_answer(answer)
    if index > 20 {
      break
    }
  }
  step
}

///|
test "openui evaluate walks expressions in official order" {
  let bool_ast =
    #|["Bool",1,false]
  inspect(drive(bool_ast, ["{\"id\":0}"]), content="{\"done\":true,\"id\":0}")
  let and_ast =
    #|["BinOp",0,"&&",["Bool",1,false],["Str",2,"no"]]
  inspect(
    drive(and_ast, ["{\"id\":4}", "{\"bit\":false}"]),
    content="{\"done\":true,\"id\":4}",
  )
  let or_ast =
    #|["BinOp",0,"||",["Bool",1,true],["Str",2,"no"]]
  inspect(
    drive(or_ast, ["{\"id\":3}", "{\"bit\":true}"]),
    content="{\"done\":true,\"id\":3}",
  )
  let or_false =
    #|["BinOp",0,"||",["Bool",1,false],["Str",2,"yes"]]
  inspect(
    drive(or_false, ["{\"id\":1}", "{\"bit\":false}", "{\"id\":2}"]),
    content="{\"done\":true,\"id\":2}",
  )
  let and_true =
    #|["BinOp",0,"&&",["Bool",1,true],["Str",2,"yes"]]
  inspect(
    drive(and_true, ["{\"id\":1}", "{\"bit\":true}", "{\"id\":2}"]),
    content="{\"done\":true,\"id\":2}",
  )
  let add_ast =
    #|["BinOp",0,"+",["Num",1,["n",1]],["Num",2,["n",2]]]
  inspect(
    drive(add_ast, ["{\"id\":0}", "{\"id\":1}", "{\"id\":2}"]),
    content="{\"done\":true,\"id\":2}",
  )
  let mul_ast =
    #|["BinOp",0,"*",["BinOp",1,"+",["Num",2,["n",1]],["Num",3,["n",2]]],["Num",4,["n",3]]]
  inspect(
    drive(mul_ast, [
      "{\"id\":0}", "{\"id\":1}", "{\"id\":2}", "{\"id\":3}", "{\"id\":4}",
    ]),
    content="{\"done\":true,\"id\":4}",
  )
  let not_ast =
    #|["UnaryOp",0,"!",["Bool",1,true]]
  inspect(
    drive(not_ast, ["{\"id\":1}", "{\"id\":2}"]),
    content="{\"done\":true,\"id\":2}",
  )
  let neg_ast =
    #|["UnaryOp",0,"-",["Num",1,["n",4]]]
  inspect(
    drive(neg_ast, ["{\"id\":1}", "{\"id\":2}"]),
    content="{\"done\":true,\"id\":2}",
  )
  let bad_unary =
    #|["UnaryOp",0,"+",["Num",1,["n",4]]]
  inspect(drive(bad_unary, []), content="{\"done\":true,\"id\":0}")
  let ternary =
    #|["Ternary",0,["Bool",1,false],["Str",2,"yes"],["Str",3,"no"]]
  inspect(
    drive(ternary, ["{\"id\":1}", "{\"bit\":false}", "{\"id\":3}"]),
    content="{\"done\":true,\"id\":3}",
  )
  let arr =
    #|["Arr",0,[["Num",1,["n",1]],["Str",2,"a"]]]
  inspect(
    drive(arr, ["{\"id\":1}", "{\"id\":2}", "{\"id\":3}"]),
    content="{\"done\":true,\"id\":3}",
  )
  let obj =
    #|["Obj",0,[["k",["Num",1,["n",1]]],["m",["Bool",2,true]]]]
  inspect(
    drive(obj, ["{\"id\":1}", "{\"id\":2}", "{\"id\":3}"]),
    content="{\"done\":true,\"id\":3}",
  )
  let field =
    #|["Member",0,["StateRef",1,"$row"],"length"]
  inspect(
    drive(field, ["{\"id\":7}", "{\"id\":8}"]),
    content="{\"done\":true,\"id\":8}",
  )
  let index =
    #|["Index",0,["Ref",1,"items"],["Num",2,["n",0]]]
  inspect(
    drive(index, ["{\"id\":5}", "{\"id\":6}", "{\"id\":7}"]),
    content="{\"done\":true,\"id\":7}",
  )
  let assign =
    #|["Assign",4,"$s"]
  inspect(drive(assign, ["{\"id\":9}"]), content="{\"done\":true,\"id\":9}")
  let comp =
    #|["Comp",6]
  inspect(drive(comp, ["{\"id\":10}"]), content="{\"done\":true,\"id\":10}")
  let null_ast =
    #|["Null",0]
  inspect(drive(null_ast, ["{\"id\":0}"]), content="{\"done\":true,\"id\":0}")
  let ph =
    #|["Ph",0]
  inspect(drive(ph, ["{\"id\":1}"]), content="{\"done\":true,\"id\":1}")
  let other =
    #|["Other",0]
  inspect(drive(other, ["{\"id\":2}"]), content="{\"done\":true,\"id\":2}")
  let literal =
    #|["Lit",8]
  inspect(drive(literal, ["{\"id\":8}"]), content="{\"done\":true,\"id\":8}")
  let text =
    #|["Str",0,"hi"]
  inspect(drive(text, ["{\"id\":3}"]), content="{\"done\":true,\"id\":3}")
  let inf =
    #|["Num",0,["inf"]]
  inspect(drive(inf, ["{\"id\":4}"]), content="{\"done\":true,\"id\":4}")
  let eq =
    #|["BinOp",0,"==",["Num",1,["n",1]],["Num",2,["n",1]]]
  inspect(
    drive(eq, ["{\"id\":1}", "{\"id\":2}", "{\"id\":3}"]),
    content="{\"done\":true,\"id\":3}",
  )
  let unknown =
    #|["BinOp",0,"??",["Num",1,["n",1]],["Num",2,["n",1]]]
  inspect(
    drive(unknown, ["{\"id\":1}", "{\"id\":2}", "{\"id\":0}"]),
    content="{\"done\":true,\"id\":0}",
  )
  let comp_ast =
    #|["Comp",1]
  let paused = eval_start(comp_ast)
  let nested_ast =
    #|["Str",0,"x"]
  inspect(drive(nested_ast, ["{\"id\":1}"]), content="{\"done\":true,\"id\":1}")
  inspect(eval_answer("{\"id\":2}"), content="{\"done\":true,\"id\":2}")
  ignore(paused)
  inspect(eval_start("{"), content="{\"done\":true,\"id\":-1}")
  inspect(eval_answer("nope"), content="{\"done\":true,\"id\":-1}")
  let hang_ast =
    #|["Str",0,"x"]
  let hanging = eval_start(hang_ast)
  inspect(eval_cancel(), content="")
  ignore(hanging)
  inspect(eval_cancel(), content="")
}
