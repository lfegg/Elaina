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
fn is_heading_start(ts : Array[Token], ls : Int, le : Int) -> (Bool, Int) {
  // 仅当行首为 Hash(1..6) 且其后紧跟至少一个空白（空格或制表符）时，才认作标题
  match ts[ls] {
    Token::Hash(lv) => {
      if lv < 1 || lv > 6 {
        return (false, 0)
      }
      if ls + 1 >= le {
        return (false, 0)
      }
      match ts[ls + 1] {
        Token::Text(s) =>
          if is_spaces_only(s) {
            (true, lv)
          } else {
            (false, 0)
          }
        _ => (false, 0)
      }
    }
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
  // 允许行首有若干空白后再出现反引号围栏
  let start = skip_leading_space_tokens(ts, ls, le)
  if start >= le {
    return (false, 0, "")
  }
  match ts[start] {
    Token::Backtick(n) =>
      if n >= 3 {
        let idx = skip_leading_space_tokens(ts, start + 1, le)
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
  // 允许行首空白
  let i0 = skip_leading_space_tokens(ts, ls, le)
  if i0 >= le {
    return (false, ls)
  }
  match ts[i0] {
    Token::Dash => (true, i0 + 1)
    Token::Star(n) => if n == 1 { (true, i0 + 1) } else { (false, ls) }
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
  let i0 = skip_leading_space_tokens(ts, ls, le)
  if i0 + 1 >= le {
    return (false, ls)
  }
  match ts[i0] {
    Token::Text(s) =>
      if is_digits_only(s) {
        match ts[i0 + 1] {
          Token::Dot => (true, i0 + 2)
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
    let (is_fence, open_cnt, lang) = try_parse_fence_start(ts, ls, le)
    if is_fence {
      let lines : Array[String] = []
      while pos < n {
        let (ls2, le2, next2, _) = read_line(ts, pos)
        let (endf, close_cnt, _) = try_parse_fence_start(ts, ls2, le2)
        if endf && close_cnt >= open_cnt {
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
    let (h_ok, level) = is_heading_start(ts, ls, le)
    if h_ok {
      let idx = skip_leading_space_tokens(ts, ls + 1, le)
      let content = line_tokens_to_string(ts, idx, le)
      blocks.push(Block::Heading(level, Text::Single(content)))
      continue
    }

    // blockquote：将以 '>' 开头的连续行合并为一个引用块，去掉前导 '>' 与紧随空白，递归解析其子块
    if is_blockquote_line(ts, ls, le) {
      let lines : Array[String] = []
      // 处理第一行
      let idx0 = skip_leading_space_tokens(ts, ls + 1, le)
      lines.push(line_tokens_to_string(ts, idx0, le))
      // 处理后续连续的引用行
      while pos < n {
        let (lsq, leq, nextq, _) = read_line(ts, pos)
        if lsq == leq {
          break
        }
        if !is_blockquote_line(ts, lsq, leq) {
          break
        }
        let idxq = skip_leading_space_tokens(ts, lsq + 1, leq)
        lines.push(line_tokens_to_string(ts, idxq, leq))
        pos = nextq
      }
      // 将行重新拼接为独立输入，递归调用 parse 获取子块
      let mut inner : String = ""
      let mut k = 0
      while k < lines.length() {
        if k > 0 {
          inner = inner + "\n"
        }
        inner = inner + lines[k]
        k += 1
      }
      inner = inner + "\n" // 追加行尾换行，便于段落聚合
      let (children, _) = parse(inner)
      blocks.push(Block::BlockQuote(children))
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
      // 尝试收集第一项的嵌套子块（缩进的 fenced / 嵌套列表 / 引用 / 段落）
      let children0 : Array[Block] = []
      let mut local_pos = pos
      // 吸收多个空行
      while local_pos < n {
        let (lss, lee, nexts, _) = read_line(ts, local_pos)
        if lss == lee {
          local_pos = nexts
        } else {
          break
        }
      }
      while local_pos < n {
        let (lsx, lex, nextx, _) = read_line(ts, local_pos)
        if lsx == lex {
          local_pos = nextx
          continue
        }
        let startx = skip_leading_space_tokens(ts, lsx, lex)
        let has_indent = startx > lsx
        // 缩进的 fenced
        let (f_ok, open_cntx, langx) = try_parse_fence_start(ts, lsx, lex)
        if has_indent && f_ok {
          let lines_c : Array[String] = []
          local_pos = nextx
          while local_pos < n {
            let (lsy, ley, nexty, _) = read_line(ts, local_pos)
            let (endf2, close_cnt2, _) = try_parse_fence_start(ts, lsy, ley)
            if endf2 && close_cnt2 >= open_cntx {
              local_pos = nexty
              break
            }
            lines_c.push(line_tokens_to_string(ts, lsy, ley))
            local_pos = nexty
          }
          let text_c = if lines_c.length() <= 1 {
            if lines_c.length() == 0 {
              Text::Single("")
            } else {
              Text::Single(lines_c[0])
            }
          } else {
            Text::Multi(lines_c)
          }
          children0.push(Block::CodeBlock(langx, text_c))
          continue
        }
        // 缩进的嵌套列表
        let (nu0, ustart_n0) = unordered_bullet_content_start(ts, lsx, lex)
        let (no0, ostart_n0) = if nu0 {
          (false, lsx)
        } else {
          ordered_bullet_content_start(ts, lsx, lex)
        }
        if has_indent && (nu0 || no0) {
          let nested_ordered0 = if no0 { true } else { false }
          children0.push(Block::List)
          let csn0 = if nested_ordered0 { ostart_n0 } else { ustart_n0 }
          let idxn0 = skip_leading_space_tokens(ts, csn0, lex)
          let nlabel0 = line_tokens_to_string(ts, idxn0, lex)
          children0.push(
            Block::ListItem(nested_ordered0, Text::Single(nlabel0), []),
          )
          local_pos = nextx
          while local_pos < n {
            let (lsn, len, nextn, _) = read_line(ts, local_pos)
            if lsn == len {
              local_pos = nextn
              continue
            }
            let startn = skip_leading_space_tokens(ts, lsn, len)
            let has_indent_n = startn > lsn
            if !has_indent_n {
              break
            }
            let (nu1, csu1) = unordered_bullet_content_start(ts, lsn, len)
            let (no1, cso1) = if nu1 {
              (false, lsn)
            } else {
              ordered_bullet_content_start(ts, lsn, len)
            }
            let match_nested = if nested_ordered0 { no1 } else { nu1 }
            if !match_nested {
              break
            }
            let csn = if nested_ordered0 { cso1 } else { csu1 }
            let idxn = skip_leading_space_tokens(ts, csn, len)
            let nlabel = line_tokens_to_string(ts, idxn, len)
            children0.push(
              Block::ListItem(nested_ordered0, Text::Single(nlabel), []),
            )
            local_pos = nextn
          }
          continue
        }
        // 缩进的引用
        if has_indent && is_blockquote_line(ts, startx, lex) {
          let q_lines : Array[String] = []
          let mut curp = local_pos
          while curp < n {
            let (lsq, leq, nextq, _) = read_line(ts, curp)
            if lsq == leq {
              curp = nextq
              continue
            }
            let startq = skip_leading_space_tokens(ts, lsq, leq)
            if startq <= lsq {
              break
            }
            if !is_blockquote_line(ts, startq, leq) {
              break
            }
            let idxq = skip_leading_space_tokens(ts, startq + 1, leq)
            q_lines.push(line_tokens_to_string(ts, idxq, leq))
            curp = nextq
          }
          let mut inner_q : String = ""
          let mut qi = 0
          while qi < q_lines.length() {
            if qi > 0 {
              inner_q = inner_q + "\n"
            }
            inner_q = inner_q + q_lines[qi]
            qi += 1
          }
          inner_q = inner_q + "\n"
          let (q_children, _) = parse(inner_q)
          children0.push(Block::BlockQuote(q_children))
          local_pos = curp
          continue
        }
        // 缩进的段落
        if has_indent {
          let p_lines : Array[String] = []
          let mut curp2 = local_pos
          while curp2 < n {
            let (lsp, lep, nextp, _) = read_line(ts, curp2)
            if lsp == lep {
              curp2 = nextp
              break
            }
            let startp = skip_leading_space_tokens(ts, lsp, lep)
            if startp <= lsp {
              break
            }
            let (f_chk, _, _) = try_parse_fence_start(ts, lsp, lep)
            let (uu_chk, _) = unordered_bullet_content_start(ts, lsp, lep)
            let (oo_chk, _) = if uu_chk {
              (false, lsp)
            } else {
              ordered_bullet_content_start(ts, lsp, lep)
            }
            if f_chk || uu_chk || oo_chk || is_blockquote_line(ts, startp, lep) {
              break
            }
            p_lines.push(line_tokens_to_string(ts, startp, lep))
            curp2 = nextp
          }
          if p_lines.length() > 0 {
            let p_text = if p_lines.length() == 1 {
              Text::Single(p_lines[0])
            } else {
              Text::Multi(p_lines)
            }
            children0.push(Block::Paragraph(p_text))
            local_pos = curp2
            continue
          }
        }
        break
      }
      // 提交第一项
      blocks.push(
        Block::ListItem(ordered, Text::Single(first_label), children0),
      )
      // 将 pos 前移到 local_pos（已消耗的子块部分）
      pos = local_pos
      while pos < n {
        let (ls4, le4, next4, _) = read_line(ts, pos)
        // 允许列表项之间存在一个或多个空行：跳过空行后继续匹配下一项
        if ls4 == le4 {
          pos = next4
          continue
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
        // 收集该项的子块
        let children_i : Array[Block] = []
        // 将 pos 移动到下一行（列表行之后）
        pos = next4
        // 吸收空行
        if pos < n {
          let (lss2, lee2, nexts2, _) = read_line(ts, pos)
          if lss2 == lee2 {
            pos = nexts2
          }
        }
        // 若后续为缩进子块（fenced / 嵌套列表 / 引用 / 段落），则作为子块归入
        while pos < n {
          let (lsx2, lex2, nextx2, _) = read_line(ts, pos)
          if lsx2 == lex2 {
            pos = nextx2
            continue
          }
          let startx2 = skip_leading_space_tokens(ts, lsx2, lex2)
          let has_indent2 = startx2 > lsx2
          let (f_ok2, open_cnt2, lang2) = try_parse_fence_start(ts, lsx2, lex2)
          if has_indent2 && f_ok2 {
            // 解析 fenced 内容
            let lines_c2 : Array[String] = []
            pos = nextx2
            while pos < n {
              let (lsy2, ley2, nexty2, _) = read_line(ts, pos)
              let (endf3, close_cnt3, _) = try_parse_fence_start(ts, lsy2, ley2)
              if endf3 && close_cnt3 >= open_cnt2 {
                pos = nexty2
                break
              }
              lines_c2.push(line_tokens_to_string(ts, lsy2, ley2))
              pos = nexty2
            }
            let text_c2 = if lines_c2.length() <= 1 {
              if lines_c2.length() == 0 {
                Text::Single("")
              } else {
                Text::Single(lines_c2[0])
              }
            } else {
              Text::Multi(lines_c2)
            }
            children_i.push(Block::CodeBlock(lang2, text_c2))
            continue
          }
          // 嵌套列表
          let (nu_i, ustart_i0) = unordered_bullet_content_start(ts, lsx2, lex2)
          let (no_i, ostart_i0) = if nu_i {
            (false, lsx2)
          } else {
            ordered_bullet_content_start(ts, lsx2, lex2)
          }
          if has_indent2 && (nu_i || no_i) {
            let nested_ordered2 = if no_i { true } else { false }
            children_i.push(Block::List)
            let csn_i0 = if nested_ordered2 { ostart_i0 } else { ustart_i0 }
            let idxn_i0 = skip_leading_space_tokens(ts, csn_i0, lex2)
            let nlabel_i0 = line_tokens_to_string(ts, idxn_i0, lex2)
            children_i.push(
              Block::ListItem(nested_ordered2, Text::Single(nlabel_i0), []),
            )
            pos = nextx2
            while pos < n {
              let (lsn2, len2, nextn2, _) = read_line(ts, pos)
              if lsn2 == len2 {
                pos = nextn2
                continue
              }
              let startn2 = skip_leading_space_tokens(ts, lsn2, len2)
              let has_indent_n2 = startn2 > lsn2
              if !has_indent_n2 {
                break
              }
              let (nu_i2, csu_i2) = unordered_bullet_content_start(
                ts, lsn2, len2,
              )
              let (no_i2, cso_i2) = if nu_i2 {
                (false, lsn2)
              } else {
                ordered_bullet_content_start(ts, lsn2, len2)
              }
              let match_nested2 = if nested_ordered2 { no_i2 } else { nu_i2 }
              if !match_nested2 {
                break
              }
              let csn_i = if nested_ordered2 { cso_i2 } else { csu_i2 }
              let idxn_i = skip_leading_space_tokens(ts, csn_i, len2)
              let nlabel_i = line_tokens_to_string(ts, idxn_i, len2)
              children_i.push(
                Block::ListItem(nested_ordered2, Text::Single(nlabel_i), []),
              )
              pos = nextn2
            }
            continue
          }
          // 缩进的引用
          if has_indent2 && is_blockquote_line(ts, startx2, lex2) {
            let q_lines2 : Array[String] = []
            // 收集首行（去掉 '>' 与紧随空白）
            let idxq2 = skip_leading_space_tokens(ts, startx2 + 1, lex2)
            q_lines2.push(line_tokens_to_string(ts, idxq2, lex2))
            let mut curp = nextx2
            while curp < n {
              let (lsq2, leq2, nextq2, _) = read_line(ts, curp)
              if lsq2 == leq2 {
                curp = nextq2
                continue
              }
              let startq2 = skip_leading_space_tokens(ts, lsq2, leq2)
              let has_indent_q2 = startq2 > lsq2
              if !has_indent_q2 {
                break
              }
              if !is_blockquote_line(ts, startq2, leq2) {
                break
              }
              let idxq2b = skip_leading_space_tokens(ts, startq2 + 1, leq2)
              q_lines2.push(line_tokens_to_string(ts, idxq2b, leq2))
              curp = nextq2
            }
            let mut inner_q2 : String = ""
            let mut qi2 = 0
            while qi2 < q_lines2.length() {
              if qi2 > 0 {
                inner_q2 = inner_q2 + "\n"
              }
              inner_q2 = inner_q2 + q_lines2[qi2]
              qi2 += 1
            }
            inner_q2 = inner_q2 + "\n"
            let (q_children2, _) = parse(inner_q2)
            children_i.push(Block::BlockQuote(q_children2))
            pos = curp
            continue
          }
          // 缩进的段落
          if has_indent2 {
            let p_lines2 : Array[String] = []
            let mut curp2 = pos
            while curp2 < n {
              let (lsp2, lep2, nextp2, _) = read_line(ts, curp2)
              if lsp2 == lep2 {
                curp2 = nextp2
                break
              }
              let startp2 = skip_leading_space_tokens(ts, lsp2, lep2)
              if startp2 <= lsp2 {
                break
              }
              let (f_chk2, _, _) = try_parse_fence_start(ts, lsp2, lep2)
              let (uu_chk2, _) = unordered_bullet_content_start(ts, lsp2, lep2)
              let (oo_chk2, _) = if uu_chk2 {
                (false, lsp2)
              } else {
                ordered_bullet_content_start(ts, lsp2, lep2)
              }
              if f_chk2 ||
                uu_chk2 ||
                oo_chk2 ||
                is_blockquote_line(ts, startp2, lep2) {
                break
              }
              p_lines2.push(line_tokens_to_string(ts, startp2, lep2))
              curp2 = nextp2
            }
            if p_lines2.length() > 0 {
              let p_text2 = if p_lines2.length() == 1 {
                Text::Single(p_lines2[0])
              } else {
                Text::Multi(p_lines2)
              }
              children_i.push(Block::Paragraph(p_text2))
              pos = curp2
              continue
            }
          }
          break
        }
        blocks.push(Block::ListItem(ordered, Text::Single(label), children_i))
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
      let (h2, _) = is_heading_start(ts, ls3, le3)
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
      Block::BlockQuote(cs) => {
        let mut s2 : String = "BlockQuote(["
        let mut j = 0
        while j < cs.length() {
          if j > 0 {
            s2 = s2 + ", "
          }
          let cj = match cs[j] {
            Block::Paragraph(tt) => "Paragraph(" + debug_text(tt) + ")"
            Block::Heading(lv2, tt2) =>
              "Heading(" + lv2.to_string() + ", " + debug_text(tt2) + ")"
            Block::CodeBlock(lang3, tt3) =>
              "CodeBlock(\"" + lang3 + "\", " + debug_text(tt3) + ")"
            Block::BlockQuote(_) => "BlockQuote([...])"
            Block::List => "List"
            Block::ListItem(o3, t3, _) =>
              "ListItem(" + bool_str(o3) + ", " + debug_text(t3) + ", [...])"
          }
          s2 = s2 + cj
          j += 1
        }
        s2 = s2 + "])"
        s2
      }
      Block::List => "List"
      Block::ListItem(ord, t, cs) => {
        let mut s : String = "ListItem(" +
          bool_str(ord) +
          ", " +
          debug_text(t) +
          ", ["
        let mut j = 0
        while j < cs.length() {
          if j > 0 {
            s = s + ", "
          }
          let cj = match cs[j] {
            Block::Paragraph(tt) => "Paragraph(" + debug_text(tt) + ")"
            Block::Heading(lv2, tt2) =>
              "Heading(" + lv2.to_string() + ", " + debug_text(tt2) + ")"
            Block::CodeBlock(lang3, tt3) =>
              "CodeBlock(\"" + lang3 + "\", " + debug_text(tt3) + ")"
            Block::BlockQuote(_) => "BlockQuote([...])"
            Block::List => "List"
            Block::ListItem(o3, t3, _) =>
              "ListItem(" + bool_str(o3) + ", " + debug_text(t3) + ", [...])"
          }
          s = s + cj
          j += 1
        }
        s = s + "])"
        s
      }
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
