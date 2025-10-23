///|
// 语法分析：将原文解析为 Block 列表（仅处理 Heading / Paragraph / fenced CodeBlock 基础形态）
// 说明：
// - 行切分基于 Token::Newline
// - 标题：行首 Hash(1..6) + 可选空格 + 文本
// - 代码块：行首 Backtick(>=3) 开始，直到下一条 Backtick(>=3) 结束；首行可带 language 标识
// - 段落：其他非空文本行合并为段落；多行合并为 Text::Multi

///|
// 本文件位于与 Token/Block/Text 同一包内，可直接引用类型与函数

///|
fn repeat_char(c : Char, n : Int) -> String {
  let mut s : String = ""
  let mut i = 0
  while i < n {
    s = s + c.to_string()
    i += 1
  }
  s
}

///|
fn is_newline_token(t : Token) -> Bool {
  match t {
    Token::Newline => true
    _ => false
  }
}

///|
fn is_heading_start(ts : Array[Token], idx : Int) -> Bool {
  if idx >= ts.length() {
    return false
  }
  match ts[idx] {
    Token::Hash(lv) => lv >= 1 && lv <= 6
    _ => false
  }
}

///|
fn heading_level_at(ts : Array[Token], idx : Int) -> Int {
  if idx >= ts.length() {
    return 1
  }
  match ts[idx] {
    Token::Hash(lv) => lv
    _ => 1
  }
}

///|
fn substring_from(s : String, k : Int) -> String {
  let mut out : String = ""
  let mut j = k
  let n = s.length()
  while j < n {
    out = out + s[j].to_string()
    j += 1
  }
  out
}

///|
fn ltrim_spaces(s : String) -> String {
  let mut i = 0
  let n = s.length()
  while i < n {
    let ch = s[i]
    if ch == ' ' || ch == '\t' {
      i += 1
    } else {
      break
    }
  }
  if i == 0 {
    s
  } else {
    substring_from(s, i)
  }
}

///|
// 将一行的 token 片段转为可见字符串（不做 inline 语义）
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
fn token_visible_text(t : Token) -> String {
  match t {
    Token::Text(s) => s
    Token::Digit(n) => n.to_string()
    Token::Dot => "."
    Token::Dash => "-"
    Token::GreaterThan => ">"
    Token::Bang => "!"
    Token::OpenBracket => "["
    Token::CloseBracket => "]"
    Token::OpenParen => "("
    Token::CloseParen => ")"
    Token::Hash(n) => repeat_char('#', n)
    Token::Star(n) => repeat_char('*', n)
    Token::Backtick(n) => repeat_char('`', n)
    _ => ""
  }
}

///|
// 读取一整行（直到 Newline 或输入结束），返回该行开始/结束下标与是否读到换行
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
// 尝试解析 fenced code block 起始行：Backtick(>=3) [lang?]
fn try_parse_fence_start(
  ts : Array[Token],
  lstart : Int,
  lend : Int,
) -> (Bool, Int, String) {
  if lstart >= lend {
    return (false, 0, "")
  }
  match ts[lstart] {
    Token::Backtick(n) =>
      if n >= 3 {
        // 语言标识：余下 token 的可见文本，去除前后空白
        let raw = line_tokens_to_string(ts, lstart + 1, lend)
        let lang = ltrim_spaces(raw)
        (true, n, lang)
      } else {
        (false, 0, "")
      }
    _ => (false, 0, "")
  }
}

///|
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
fn ordered_bullet_content_start(
  ts : Array[Token],
  ls : Int,
  le : Int,
) -> (Bool, Int) {
  if ls + 1 >= le {
    return (false, ls)
  }
  match ts[ls] {
    Token::Digit(_) =>
      match ts[ls + 1] {
        Token::Dot => (true, ls + 2)
        _ => (false, ls)
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
    // 读一行
    let (ls, le, next_pos, _) = read_line(ts, pos)
    pos = next_pos

    // 空行：跳过
    if ls == le {
      continue
    }

    // 代码块起始？
    let (is_fence, _fcount, lang) = try_parse_fence_start(ts, ls, le)
    if is_fence {
      // 收集直至匹配的结束围栏
      let lines : Array[String] = []
      while pos < n {
        let (ls2, le2, next2, _) = read_line(ts, pos)
        let (is_end, _, _) = try_parse_fence_start(ts, ls2, le2)
        if is_end {
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

    // 标题？行首 Hash(1..6)
    let is_heading = is_heading_start(ts, ls)
    if is_heading {
      // 行余下文本
      let raw = line_tokens_to_string(ts, ls + 1, le)
      let content = ltrim_spaces(raw)
      // 读取等级
      let level = heading_level_at(ts, ls)
      blocks.push(Block::Heading(level, Text::Single(content)))
      continue
    }

    // 引用块：以 '>' 开头的连续行，当前仅产生一个 BlockQuote 占位并消费这些行
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

    // 列表：无序或有序，按同类分组
    let (is_unorder, ustart) = unordered_bullet_content_start(ts, ls, le)
    let (is_order, ostart) = if is_unorder {
      (false, ls)
    } else {
      ordered_bullet_content_start(ts, ls, le)
    }
    if is_unorder || is_order {
      let ordered = if is_order { true } else { false }
      blocks.push(Block::List)
      // 消费连续的同类列表项
      // 我们已经取了当前行的 ls/le，下一行在 pos
      // 使用当前行先加入，再在 while 中读取后续行
      let first_cs = if is_unorder { ustart } else { ostart }
      let first_raw = line_tokens_to_string(ts, first_cs, le)
      let first_label = ltrim_spaces(first_raw)
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
        let raw = line_tokens_to_string(ts, cs, le4)
        let label = ltrim_spaces(raw)
        blocks.push(Block::ListItem(ordered, Text::Single(label)))
        pos = next4
      }
      continue
    }

    // 段落：收集连续非空行，合并成单个 Paragraph
    let lines : Array[String] = []
    lines.push(line_tokens_to_string(ts, ls, le))
    // 向后看：如果下一行不是空且不是围栏开始也不是标题，则并入段落
    while pos < n {
      let (ls3, le3, next3, _) = read_line(ts, pos)
      if ls3 == le3 {
        break
      } // 空行终止段落
      let (f2, _, _) = try_parse_fence_start(ts, ls3, le3)
      let h2 = is_heading_start(ts, ls3)
      if f2 || h2 {
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
