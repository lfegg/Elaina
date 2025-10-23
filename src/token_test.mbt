///|
// tokenizer blackbox tests

test "tokenize basic runs and aggregates" {
  let (toks, err) = tokenize("# Hi\r\n1. item\n\\*escaped* `code`")
  inspect(
    debug_tokens(toks),
    content=(
      #|["Hash(1)", "Text(\"3272105\")", "Newline", "Digit(1)", "Dot", "Text(\"32105116101109\")", "Newline", "Text(\"42\")", "Text(\"1011159997112101100\")", "Star(1)", "Text(\"32\")", "Backtick(1)", "Text(\"99111100101\")", "Backtick(1)"]
    ),
  )
  inspect(err, content="None")
}

///|
test "tokenize digits and punctuation" {
  let (toks, err) = tokenize("123. 456\n- list\n> quote")
  inspect(
    debug_tokens(toks),
    content=(
      #|["Digit(123)", "Dot", "Text(\"32\")", "Digit(456)", "Newline", "Dash", "Text(\"32108105115116\")", "Newline", "GreaterThan", "Text(\"32113117111116101\")"]
    ),
  )
  inspect(err, content="None")
}
