///|
// Markdown 词法 Token 定义（MoonBit enum）
// 先只提供稳定类型，后续分步实现 tokenizer 与 parser。

pub enum Token {
  Text(String)
  Newline
  Hash(Int) // # 的数量（用于标题）
  Star(Int) // * 的数量（1=em, 2=strong）
  Backtick(Int) // ` 的数量（1=inline, 3=fenced）
  OpenBracket
  CloseBracket
  OpenParen
  CloseParen
  Bang
  GreaterThan
  Dash
  Dot
  Digit(Int)
}

///|
// 基础 Tokenizer：按字符扫描，生成 Array[Token]
// 说明：
// - 兼容 CRLF 与 LF，将其统一为单个 Newline。
// - 连续的 #、*、` 计数为一个 Token（Hash/Star/Backtick）。
// - 数字串聚合为一个 Digit(Int)。
// - 其余字符以单字符 Text 输出（后续可再聚合连续文本以提效）。
pub fn tokenize(s : String) -> (Array[Token], String?) {
  let tokens : Array[Token] = []
  let mut i = 0
  let n = s.length()
  while i < n {
    let c = s[i]
    if c == '\r' {
      if i + 1 < n && s[i + 1] == '\n' {
        tokens.push(Token::Newline)
        i += 2
      } else {
        tokens.push(Token::Newline)
        i += 1
      }
      continue
    }
    if c == '\n' {
      tokens.push(Token::Newline)
      i += 1
      continue
    }
    if c == '\\' {
      // 反斜杠转义：将下一字符作为普通文本
      if i + 1 < n {
        tokens.push(Token::Text(s[i + 1].to_string()))
        i += 2
      } else {
        tokens.push(Token::Text('\\'.to_string()))
        i += 1
      }
      continue
    }
    if c == '#' {
      let mut count = 0
      while i + count < n && s[i + count] == '#' {
        count += 1
      }
      tokens.push(Token::Hash(count))
      i += count
      continue
    }
    if c == '*' {
      let mut count = 0
      while i + count < n && s[i + count] == '*' {
        count += 1
      }
      tokens.push(Token::Star(count))
      i += count
      continue
    }
    if c == '`' {
      let mut count = 0
      while i + count < n && s[i + count] == '`' {
        count += 1
      }
      tokens.push(Token::Backtick(count))
      i += count
      continue
    }
    if c == '[' {
      tokens.push(Token::OpenBracket)
      i += 1
      continue
    }
    if c == ']' {
      tokens.push(Token::CloseBracket)
      i += 1
      continue
    }
    if c == '(' {
      tokens.push(Token::OpenParen)
      i += 1
      continue
    }
    if c == ')' {
      tokens.push(Token::CloseParen)
      i += 1
      continue
    }
    if c == '!' {
      tokens.push(Token::Bang)
      i += 1
      continue
    }
    if c == '>' {
      tokens.push(Token::GreaterThan)
      i += 1
      continue
    }
    if c == '-' {
      tokens.push(Token::Dash)
      i += 1
      continue
    }
    if c == '.' {
      tokens.push(Token::Dot)
      i += 1
      continue
    }
    if c >= '0' && c <= '9' {
      let mut num = 0
      while i < n && s[i] >= '0' && s[i] <= '9' {
        num = num * 10 + (s[i] - '0')
        i += 1
      }
      tokens.push(Token::Digit(num))
      continue
    }

    // 文本 run 聚合：直到遇到特殊字符或换行/回车
    let mut run : String = ""
    while i < n {
      let ch = s[i]
      if ch == '\r' ||
        ch == '\n' ||
        ch == '#' ||
        ch == '*' ||
        ch == '`' ||
        ch == '[' ||
        ch == ']' ||
        ch == '(' ||
        ch == ')' ||
        ch == '!' ||
        ch == '>' ||
        ch == '-' ||
        ch == '.' ||
        (ch >= '0' && ch <= '9') ||
        ch == '\\' {
        break
      }
      run = run + ch.to_string()
      i += 1
    }
    if run.length() == 0 {
      // 理论上不会到这里，但兜底：作为单字符文本
      run = c.to_string()
      i += 1
    }
    tokens.push(Token::Text(run))
  }
  (tokens, None)
}

///|
// 调试辅助：把 Token 列表转换为字符串数组，方便测试快照
fn token_to_string(t : Token) -> String {
  match t {
    Token::Text(s) => "Text(\"" + s + "\")"
    Token::Newline => "Newline"
    Token::Hash(n) => "Hash(" + n.to_string() + ")"
    Token::Star(n) => "Star(" + n.to_string() + ")"
    Token::Backtick(n) => "Backtick(" + n.to_string() + ")"
    Token::OpenBracket => "OpenBracket"
    Token::CloseBracket => "CloseBracket"
    Token::OpenParen => "OpenParen"
    Token::CloseParen => "CloseParen"
    Token::Bang => "Bang"
    Token::GreaterThan => "GreaterThan"
    Token::Dash => "Dash"
    Token::Dot => "Dot"
    Token::Digit(n) => "Digit(" + n.to_string() + ")"
  }
}

///|
pub fn debug_tokens(ts : Array[Token]) -> Array[String] {
  let out : Array[String] = []
  let mut i = 0
  while i < ts.length() {
    out.push(token_to_string(ts[i]))
    i += 1
  }
  out
}