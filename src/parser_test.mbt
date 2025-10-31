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
      #|["BlockQuote([Paragraph(Multi([\"quoted line 1\", \"quoted line 2\"]))])", "Paragraph(Single(\"para after quote\"))"]
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
      #|["List", "ListItem(false, Single(\"item one\"), [])", "ListItem(false, Single(\"item two\"), [])", "List", "ListItem(true, Single(\"first\"), [])", "ListItem(true, Single(\"second\"), [])"]
    ),
  )
  inspect(err, content="None")
}

///|
// allow blank line between ordered list items with fenced code child

test "ordered list continues after child code with blank line" {
  let input = "1. first\n    ```js\n    code under first\n    ```\n\n2. second\n"
  let (blocks, err) = parse(input)
  inspect(
    debug_blocks(blocks),
    content=(
      #|["List", "ListItem(true, Single(\"first\"), [CodeBlock(\"js\", Single(\"    code under first\"))])", "ListItem(true, Single(\"second\"), [])"]
    ),
  )
  inspect(err, content="None")
}

///|
// nested list under ordered list item (unordered sublist)

test "nested unordered list under ordered item" {
  let input = "1. first\n    - sub a\n    - sub b\n2. second\n"
  let (blocks, err) = parse(input)
  inspect(
    debug_blocks(blocks),
    content=(
      #|["List", "ListItem(true, Single(\"first\"), [List, ListItem(false, Single(\"sub a\"), [...]), ListItem(false, Single(\"sub b\"), [...])])", "ListItem(true, Single(\"second\"), [])"]
    ),
  )
  inspect(err, content="None")
}

///|
// fence length matching tests

test "fence length matching outer 4 inner 3" {
  let input = "````lang\nline a\n```\nline b\n````\n"
  let (blocks, err) = parse(input)
  inspect(
    debug_blocks(blocks),
    content=(
      #|["CodeBlock(\"lang\", Multi([\"line a\", \"```\", \"line b\"]))"]
    ),
  )
  inspect(err, content="None")
}
