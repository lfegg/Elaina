///|
// 语法分析：使用 tokenizer.mbt 产生的 Token 流来解析为 Block 列表
// - 标题：行首 Hash(1..6) + 可选空格 + 文本（Text/符号拼接）
// - 围栏代码块：行首 Backtick(>=3)，直到下一个 Backtick(>=3)，首行余下作为语言标识
// - 引用：以 GreaterThan 开头的连续行（当前作为占位 BlockQuote）
// - 列表：无序（Dash 或 Star(1)）与有序（digits + Dot）识别并分组
// - 段落：其余非空行按段连续合并为 Paragraph(Text::Single/Multi)

///|
// 本文件与 tokenizer/ast 同包，可直接使用 Token/Block/Text

///|
// 空白判定：仅用于跳过 Token::Text 中的前缀空格/制表符
fn is_spaces_only(s : String) -> Bool {
  let mut i = 0
  let n = s.length()
  while i < n {
    let ch = s[i]
    if ch == ' ' || ch == '\t' {
      i += 1
    } else {
      return false
    }
  }
  true
}

///|
fn skip_leading_space_tokens(ts : Array[Token], i0 : Int, end : Int) -> Int {
  let mut i = i0
  while i < end {
    match ts[i] {
      Token::Text(s) => if is_spaces_only(s) { i += 1 } else { break }
      _ => break
    }
  }
  i
}

///|
// 读取一整行在源字符串中的边界（支持 CRLF / CR / LF）
// Token 工具
fn is_newline_token(t : Token) -> Bool {
  match t {
    Token::Newline => true
    _ => false
  }
}

///|
fn read_line(ts : Array[Token], pos : Int) -> (Int, Int, Int, Bool) {
  let mut i = pos
  let n = ts.length()
  let start = i
  while i < n && !is_newline_token(ts[i]) {
    i += 1
  }
  let end = i
  let has_nl = i < n && is_newline_token(ts[i])
  if has_nl {
    i += 1
  }
  (start, end, i, has_nl)
}

///|
fn repeat_str(piece : String, n : Int) -> String {
  let mut out : String = ""
  let mut i = 0
  while i < n {
    out = out + piece
    i += 1
  }
  out
}

///|
fn token_visible_text(t : Token) -> String {
  match t {
    Token::Text(s) => s
    Token::Dot => "."
    Token::Dash => "-"
    Token::GreaterThan => ">"
    Token::Bang => "!"
    Token::OpenBracket => "["
    Token::CloseBracket => "]"
    Token::OpenParen => "("
    Token::CloseParen => ")"
    Token::Star(n) => repeat_str("*", n)
    Token::Backtick(n) => repeat_str("`", n)
    Token::Hash(n) => repeat_str("#", n)
    _ => ""
  }
}

///|
fn line_tokens_to_string(ts : Array[Token], start : Int, end : Int) -> String {
  let mut out : String = ""
  let mut i = start
  while i < end {
    out = out + token_visible_text(ts[i])
    i += 1
  }
  out
}

///|
//

///|
fn is_heading_start(ts : Array[Token], ls : Int) -> (Bool, Int) {
  match ts[ls] {
    Token::Hash(lv) => if lv >= 1 && lv <= 6 { (true, lv) } else { (false, 0) }
    _ => (false, 0)
  }
}

///|
// fence 相关
fn try_parse_fence_start(
  ts : Array[Token],
  ls : Int,
  le : Int,
) -> (Bool, Int, String) {
  if ls >= le {
    return (false, 0, "")
  }
  match ts[ls] {
    Token::Backtick(n) =>
      if n >= 3 {
        let idx = skip_leading_space_tokens(ts, ls + 1, le)
        let lang = line_tokens_to_string(ts, idx, le)
        (true, n, lang)
      } else {
        (false, 0, "")
      }
    _ => (false, 0, "")
  }
}

///|
// 尝试解析 fenced code block 起始行：Backtick(>=3) [lang?]
fn is_blockquote_line(ts : Array[Token], ls : Int, le : Int) -> Bool {
  if ls >= le {
    return false
  }
  match ts[ls] {
    Token::GreaterThan => true
    _ => false
  }
}

///|
// 列表项：无序（- 或 *）
fn unordered_bullet_content_start(
  ts : Array[Token],
  ls : Int,
  le : Int,
) -> (Bool, Int) {
  if ls >= le {
    return (false, ls)
  }
  match ts[ls] {
    Token::Dash => (true, ls + 1)
    Token::Star(n) => if n == 1 { (true, ls + 1) } else { (false, ls) }
    _ => (false, ls)
  }
}

///|
// 列表项：有序（digits + Dot）
fn is_digits_only(s : String) -> Bool {
  let n = s.length()
  if n == 0 {
    return false
  }
  let mut i = 0
  while i < n {
    let ch = s[i]
    if ch >= '0' && ch <= '9' {
      i += 1
    } else {
      return false
    }
  }
  true
}

///|
fn ordered_bullet_content_start(
  ts : Array[Token],
  ls : Int,
  le : Int,
) -> (Bool, Int) {
  if ls + 1 >= le {
    return (false, ls)
  }
  match ts[ls] {
    Token::Text(s) =>
      if is_digits_only(s) {
        match ts[ls + 1] {
          Token::Dot => (true, ls + 2)
          _ => (false, ls)
        }
      } else {
        (false, ls)
      }
    _ => (false, ls)
  }
}

///|
pub fn parse(input : String) -> (Array[Block], String?) {
  let (ts, _) = tokenize(input)
  let blocks : Array[Block] = []
  let mut pos : Int = 0
  let n = ts.length()
  while pos < n {
    let (ls, le, next_pos, _) = read_line(ts, pos)
    pos = next_pos
    if ls == le {
      continue
    }

    // fenced code block
    let (is_fence, _cnt, lang) = try_parse_fence_start(ts, ls, le)
    if is_fence {
      let lines : Array[String] = []
      while pos < n {
        let (ls2, le2, next2, _) = read_line(ts, pos)
        let (endf, _, _) = try_parse_fence_start(ts, ls2, le2)
        if endf {
          pos = next2
          break
        }
        lines.push(line_tokens_to_string(ts, ls2, le2))
        pos = next2
      }
      let text = if lines.length() <= 1 {
        if lines.length() == 0 {
          Text::Single("")
        } else {
          Text::Single(lines[0])
        }
      } else {
        Text::Multi(lines)
      }
      blocks.push(Block::CodeBlock(lang, text))
      continue
    }

    // heading
    let (h_ok, level) = is_heading_start(ts, ls)
    if h_ok {
      let idx = skip_leading_space_tokens(ts, ls + 1, le)
      let content = line_tokens_to_string(ts, idx, le)
      blocks.push(Block::Heading(level, Text::Single(content)))
      continue
    }

    // blockquote (placeholder)
    if is_blockquote_line(ts, ls, le) {
      while pos < n {
        let (lsq, leq, nextq, _) = read_line(ts, pos)
        if lsq == leq {
          break
        }
        if !is_blockquote_line(ts, lsq, leq) {
          break
        }
        pos = nextq
      }
      blocks.push(Block::BlockQuote)
      continue
    }

    // lists
    let (u_ok, ustart) = unordered_bullet_content_start(ts, ls, le)
    let (o_ok, ostart) = if u_ok {
      (false, ls)
    } else {
      ordered_bullet_content_start(ts, ls, le)
    }
    if u_ok || o_ok {
      let ordered = if o_ok { true } else { false }
      blocks.push(Block::List)
      let cs0 = if ordered { ostart } else { ustart }
      let idx0 = skip_leading_space_tokens(ts, cs0, le)
      let first_label = line_tokens_to_string(ts, idx0, le)
      blocks.push(Block::ListItem(ordered, Text::Single(first_label)))
      while pos < n {
        let (ls4, le4, next4, _) = read_line(ts, pos)
        if ls4 == le4 {
          break
        }
        let (u2, cs_u) = unordered_bullet_content_start(ts, ls4, le4)
        let (o2, cs_o) = if u2 {
          (false, ls4)
        } else {
          ordered_bullet_content_start(ts, ls4, le4)
        }
        let match_same = if ordered { o2 } else { u2 }
        if !match_same {
          break
        }
        let cs = if ordered { cs_o } else { cs_u }
        let idx = skip_leading_space_tokens(ts, cs, le4)
        let label = line_tokens_to_string(ts, idx, le4)
        blocks.push(Block::ListItem(ordered, Text::Single(label)))
        pos = next4
      }
      continue
    }

    // paragraph: accumulate non-empty lines until next block
    let lines : Array[String] = []
    lines.push(line_tokens_to_string(ts, ls, le))
    while pos < n {
      let (ls3, le3, next3, _) = read_line(ts, pos)
      if ls3 == le3 {
        break
      }
      let (f2, _, _) = try_parse_fence_start(ts, ls3, le3)
      let (h2, _) = is_heading_start(ts, ls3)
      if f2 || h2 || is_blockquote_line(ts, ls3, le3) {
        break
      }
      let (uu, _) = unordered_bullet_content_start(ts, ls3, le3)
      let (oo, _) = if uu {
        (false, ls3)
      } else {
        ordered_bullet_content_start(ts, ls3, le3)
      }
      if uu || oo {
        break
      }
      lines.push(line_tokens_to_string(ts, ls3, le3))
      pos = next3
    }
    let text = if lines.length() <= 1 {
      Text::Single(lines[0])
    } else {
      Text::Multi(lines)
    }
    blocks.push(Block::Paragraph(text))
  }
  (blocks, None)
}

///|
// 调试：将 Block 列表转为字符串数组，便于 snapshot
pub fn debug_blocks(bs : Array[Block]) -> Array[String] {
  let out : Array[String] = []
  let mut i = 0
  while i < bs.length() {
    let s = match bs[i] {
      Block::Paragraph(t) => "Paragraph(" + debug_text(t) + ")"
      Block::Heading(lv, t) =>
        "Heading(" + lv.to_string() + ", " + debug_text(t) + ")"
      Block::CodeBlock(lang, t) =>
        "CodeBlock(\"" + lang + "\", " + debug_text(t) + ")"
      Block::BlockQuote => "BlockQuote"
      Block::List => "List"
      Block::ListItem(ord, t) =>
        "ListItem(" + bool_str(ord) + ", " + debug_text(t) + ")"
    }
    out.push(s)
    i += 1
  }
  out
}

///|
fn debug_text(t : Text) -> String {
  match t {
    Text::Single(s) => "Single(\"" + s + "\")"
    Text::Multi(xs) => {
      let mut s : String = "Multi(["
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          s = s + ", "
        }
        s = s + "\"" + xs[i] + "\""
        i += 1
      }
      s = s + "])"
      s
    }
  }
}

///|
fn bool_str(b : Bool) -> String {
  if b {
    "true"
  } else {
    "false"
  }
}
