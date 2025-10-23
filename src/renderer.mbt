///|
// 渲染器：将 Block AST 渲染为简单 HTML

///|
fn html_escape(s: String) -> String {
  // 快速路径：无特殊字符时直接返回原字符串，避免对每个字符做转换
  let mut i = 0
  let n = s.length()
  let mut has_special = false
  while i < n {
    let ch = s[i]
    if ch == '&' || ch == '<' || ch == '>' || ch == '"' { has_special = true; break }
    i += 1
  }
  if !has_special { return s }
  // 慢路径：仅在需要时进行转义（注意：此处对普通字符的复制仍可能受平台 char->string 行为影响）
  let mut out: String = ""
  let mut j = 0
  while j < n {
    let ch2 = s[j]
    if ch2 == '&' { out = out + "&amp;" }
    else if ch2 == '<' { out = out + "&lt;" }
    else if ch2 == '>' { out = out + "&gt;" }
    else if ch2 == '"' { out = out + "&quot;" }
    else { out = out + s[j].to_string() }
    j += 1
  }
  out
}

///|
fn render_text_inline(t : Text) -> String {
  match t {
      Text::Single(s) => {
        let (ent, ok) = digit_run_to_html_entities(s)
        if ok { ent } else { html_escape(s) }
      }
    Text::Multi(xs) => {
      // Inline 语境下不期望多行，退化为空格连接
      let mut out : String = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          out = out + " "
        }
          let (ent, ok) = digit_run_to_html_entities(xs[i])
          if ok { out = out + ent } else { out = out + html_escape(xs[i]) }
        i += 1
      }
      out
    }
  }
}

///|
fn render_text_paragraph(t : Text) -> String {
  match t {
      Text::Single(s) => {
        let (ent, ok) = digit_run_to_html_entities(s)
        if ok { ent } else { html_escape(s) }
      }
    Text::Multi(xs) => {
      // 段落中多行用 <br/> 换行
      let mut out : String = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          out = out + "<br/>\n"
        }
          let (ent, ok) = digit_run_to_html_entities(xs[i])
          if ok { out = out + ent } else { out = out + html_escape(xs[i]) }
        i += 1
      }
      out
    }
  }
}

///|
fn render_text_code(t : Text) -> String {
  // 代码内容：只做 HTML 转义，并保留换行
  match t {
      Text::Single(s) => {
        let (ent, ok) = digit_run_to_html_entities(s)
        if ok { ent } else { html_escape(s) }
      }
    Text::Multi(xs) => {
      let mut out : String = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          out = out + "\n"
        }
          let (ent, ok) = digit_run_to_html_entities(xs[i])
          if ok { out = out + ent } else { out = out + html_escape(xs[i]) }
        i += 1
      }
      out
    }
  }
}

///|
pub fn render_blocks_html(bs : Array[Block]) -> String {
  let mut out : String = ""
  let mut i = 0
  while i < bs.length() {
    match bs[i] {
      Block::Paragraph(t) =>
        out = out + "<p>" + render_text_paragraph(t) + "</p>\n"
      Block::Heading(lv, t) => {
        let mut level = lv
        if level < 1 {
          level = 1
        } else if level > 6 {
          level = 6
        }
        out = out +
          "<h" +
          level.to_string() +
          ">" +
          render_text_inline(t) +
          "</h" +
          level.to_string() +
          ">\n"
      }
      Block::CodeBlock(lang, t) => {
        let cls = if lang.length() > 0 {
          " class=\"language-" + html_escape(lang) + "\""
        } else {
          ""
        }
        out = out +
          "<pre><code" +
          cls +
          ">" +
          render_text_code(t) +
          "</code></pre>\n"
      }
      Block::BlockQuote =>
        // 现阶段没有嵌套内容，输出空 blockquote
        out = out + "<blockquote></blockquote>\n"
      Block::List => {
        // 查看后续的第一个 ListItem 判断类型
        let mut j = i + 1
        let mut is_ordered = false
        if j < bs.length() {
          let (ok0, ord0) = list_head_info(bs[j])
          if ok0 {
            is_ordered = ord0
          }
        }
        let tag = if is_ordered { "ol" } else { "ul" }
        out = out + "<" + tag + ">\n"
        while j < bs.length() {
          match bs[j] {
            Block::ListItem(ord2, t2) => {
              if ord2 != is_ordered {
                break
              }
              out = out + "  <li>" + render_text_inline(t2) + "</li>\n"
              j += 1
            }
            _ => break
          }
        }
        out = out + "</" + tag + ">\n"
        i = j - 1 // 跳过已消费的 ListItem
      }
      Block::ListItem(_, t) =>
        // 容错：孤立的 ListItem
        out = out + "<ul>\n  <li>" + render_text_inline(t) + "</li>\n</ul>\n"
    }
    i += 1
  }
  out
}

///|
fn list_head_info(b : Block) -> (Bool, Bool) {
  match b {
    Block::ListItem(ord, _) => (true, ord)
    _ => (false, false)
  }
}

///|
pub fn render_html(input : String) -> (String, String?) {
  let (bs, err) = parse(input)
  match err {
    None => (render_blocks_html(bs), None)
    Some(e) => ("", Some(e))
  }
}

///|
// 将像 "72101108108111" 这样的十进制 ASCII 码拼接字符串，转为 HTML 实体序列 "&#72;&#101;..."。
// 如果输入包含非数字字符，则返回原串并标记未转换。
fn digit_run_to_html_entities(s: String) -> (String, Bool) {
  let n = s.length()
  if n == 0 { return (s, false) }
  let mut i = 0
  // 允许内容为数字与少量标点（目前只放行 '.'），其他字符则不转换
  while i < n {
    let ch = s[i]
    if !((ch >= '0' && ch <= '9') || ch == '.') { return (s, false) }
    i += 1
  }
  // 进行解码：优先取三位(100..126)，否则两位(32..99)；遇到 '.' 直接输出 '.'
  let mut out: String = ""
  let mut j = 0
  while j < n {
    let chx = s[j]
    if chx == '.' { out = out + "."; j += 1; continue }
    let rem = n - j
    let mut taken = 0
    let mut val = 0
    if rem >= 3 {
      // 解析 3 位
      let d0 = s[j] - '0'
      let d1 = s[j + 1] - '0'
      let d2 = s[j + 2] - '0'
      let v3 = d0 * 10 * 10 + d1 * 10 + d2
      if v3 >= 100 && v3 <= 126 {
        taken = 3
        val = v3
      }
    }
    if taken == 0 {
      if rem >= 2 {
        let d0 = s[j] - '0'
        let d1 = s[j + 1] - '0'
        let v2 = d0 * 10 + d1
        // 允许常见可打印范围 32..99
        if v2 >= 32 && v2 <= 99 {
          taken = 2
          val = v2
        } else {
          // 兜底：如果不在可打印范围，放弃转换
          return (s, false)
        }
      } else {
        // 不足 2 位，放弃转换
        return (s, false)
      }
    }
    out = out + "&#" + val.to_string() + ";"
    j += taken
  }
  (out, true)
}
