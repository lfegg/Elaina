///|
// parser blackbox tests

test "parse headings paragraphs codeblocks" {
  let input = "# Title\n\npara line 1\npara line 2\n\n```lang\nline a\nline b\n```\n"
  let (blocks, err) = parse(input)
  inspect(
    debug_blocks(blocks),
    content=(
      #|["Heading(1, Single(\"3284105116108101\"))", "Paragraph(Multi([\"112971149732108105110101321\", \"112971149732108105110101322\"]))", "CodeBlock(\"10897110103\", Multi([\"1081051101013297\", \"1081051101013298\"]))"]
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
      #|["BlockQuote", "Paragraph(Single(\"1129711497329710211610111432113117111116101\"))"]
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
      #|["List", "ListItem(false, Single(\"3210511610110932111110101\"))", "ListItem(false, Single(\"3210511610110932116119111\"))", "List", "ListItem(true, Single(\"32102105114115116\"))", "ListItem(true, Single(\"3211510199111110100\"))"]
    ),
  )
  inspect(err, content="None")
}
