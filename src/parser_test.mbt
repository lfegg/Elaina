///|
// parser blackbox tests

test "parse headings paragraphs codeblocks" {
  let input = "# Title\n\npara line 1\npara line 2\n\n```lang\nline a\nline b\n```\n"
  let (blocks, err) = parse(input)
  inspect(
    debug_blocks(blocks),
    content=(
      #|["Heading(1, Single(\"Title\"))", "Paragraph(Multi([\"para line 1\", \"para line 2\"]))", "CodeBlock(\"lang\", Multi([\"line a\", \"line b\"]))"]
    ),
  )
  inspect(err, content="None")
}

///|
// parser tests for blockquotes

test "parse blockquote and paragraph" {
  let input = "> quoted line 1\n> quoted line 2\n\npara after quote\n"
  let (blocks, err) = parse(input)
  inspect(
    debug_blocks(blocks),
    content=(
      #|["BlockQuote", "Paragraph(Single(\"para after quote\"))"]
    ),
  )
  inspect(err, content="None")
}

///|
// parser tests for lists

test "parse unordered and ordered lists" {
  let input = "- item one\n- item two\n\n1. first\n2. second\n"
  let (blocks, err) = parse(input)
  inspect(
    debug_blocks(blocks),
    content=(
      #|["List", "ListItem(false, Single(\"item one\"))", "ListItem(false, Single(\"item two\"))", "List", "ListItem(true, Single(\"first\"))", "ListItem(true, Single(\"second\"))"]
    ),
  )
  inspect(err, content="None")
}
