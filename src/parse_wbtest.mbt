///|
test "tokens cover calls, literals, and operators" {
  let src = "root = Stack([title], -1, item.name)\n"
  inspect(
    tokens_json(src),
    content=(
      #|[{"t":"Ident","line":1,"column":1,"v":"root"},{"t":"Equals","line":1,"column":6},{"t":"Type","line":1,"column":8,"v":"Stack"},{"t":"LParen","line":1,"column":13},{"t":"LBrack","line":1,"column":14},{"t":"Ident","line":1,"column":15,"v":"title"},{"t":"RBrack","line":1,"column":20},{"t":"Comma","line":1,"column":21},{"t":"Num","line":1,"column":23,"v":"-1"},{"t":"Comma","line":1,"column":25},{"t":"Ident","line":1,"column":27,"v":"item"},{"t":"Dot","line":1,"column":31},{"t":"Ident","line":1,"column":32,"v":"name"},{"t":"RParen","line":1,"column":36},{"t":"Newline","line":1,"column":37},{"t":"EOF","line":2,"column":1}]
    ),
  )
}

///|
test "signup sample parses to eight statements" {
  let src =
    #|root = Stack([title, form])
    #|title = TextContent("Sign up", "large-heavy")
    #|form = Form("signup", actions, [nameField, emailField])
    #|nameField = FormControl("Name", Input("name", "Your name", "text", {required: true}))
    #|emailField = FormControl("Email", Input("email", "you@example.com", "email", {required: true, email: true}))
    #|actions = Buttons([submitBtn, cancelBtn], "row")
    #|submitBtn = Button("Submit", @ToAssistant("Sign me up"), "primary")
    #|cancelBtn = Button("Cancel", @ToAssistant("Cancel sign up"), "secondary")
    #|
  inspect(
    summarize(src),
    content=(
      #|statements: 8
      #|errors: 0
      #|1 root = Comp(Stack, [Arr([Ref(title), Ref(form)])])
      #|2 title = Comp(TextContent, [Str("Sign up"), Str("large-heavy")])
      #|3 form = Comp(Form, [Str("signup"), Ref(actions), Arr([Ref(nameField), Ref(emailField)])])
      #|4 nameField = Comp(FormControl, [Str("Name"), Comp(Input, [Str("name"), Str("Your name"), Str("text"), Obj({"required": Bool(true)})])])
      #|5 emailField = Comp(FormControl, [Str("Email"), Comp(Input, [Str("email"), Str("you@example.com"), Str("email"), Obj({"required": Bool(true), "email": Bool(true)})])])
      #|6 actions = Comp(Buttons, [Arr([Ref(submitBtn), Ref(cancelBtn)]), Str("row")])
      #|7 submitBtn = Comp(Button, [Str("Submit"), Comp(ToAssistant, [Str("Sign me up")]), Str("primary")])
      #|8 cancelBtn = Comp(Button, [Str("Cancel"), Comp(ToAssistant, [Str("Cancel sign up")]), Str("secondary")])
    ),
  )
}

///|
test "operators, state, index, and at-calls" {
  let src =
    #|$compact = false
    #|root = $compact ? compactView : fullView
    #|total = "Total: " + @Percent(done, total)
    #|saveBtn = Button("Save", Action([@Run(save), @Reset($note)]))
    #|row = items[0].name
    #|diff = 1 - -2
    #|plain = Count(items)
    #|
  inspect(
    summarize(src),
    content=(
      #|statements: 7
      #|errors: 1
      #|1 $compact = Bool(false)
      #|2 root = Ternary(StateRef($compact), Ref(compactView), Ref(fullView))
      #|3 total = Bin(+, Str("Total: "), Fn(Percent, [Ref(done), Ref(total)]))
      #|4 saveBtn = Comp(Button, [Str("Save"), Comp(Action, [Arr([Comp(Run, [Ref(save)]), Comp(Reset, [StateRef($note)])])])])
      #|5 row = Member(Index(Ref(items), Num(0)), name)
      #|6 diff = Bin(-, Num(1), Num(-2))
      #|7 plain = Ref(Count)
      #|error 7:14 trailing tokens
    ),
  )
}

///|
test "a bad line does not drop the next statement" {
  let src =
    #|root = Stack([ok])
    #|this is not a statement
    #|title = TextContent("Hi")
    #|
  inspect(
    summarize(src),
    content=(
      #|statements: 2
      #|errors: 1
      #|1 root = Comp(Stack, [Arr([Ref(ok)])])
      #|3 title = Comp(TextContent, [Str("Hi")])
      #|error 2:6 expected '='
    ),
  )
}

///|
test "string escapes and single quotes" {
  inspect(
    summarize("title = TextContent(\"a\\nb\", 'it\\'s')\n"),
    content=(
      #|statements: 1
      #|errors: 0
      #|1 title = Comp(TextContent, [Str("a\nb"), Str("it's")])
    ),
  )
}
