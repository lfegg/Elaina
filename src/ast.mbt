///|
// 文本节点：区分单行与多行
pub enum Text {
  Single(String) // 单行文本（不包含换行）
  Multi(Array[String]) // 多行文本（每项为一行）
}

///|
// 行内节点（Inline）
enum Inline {
  Text(Text)
  Strong
  Em
  Code(String) // 行内代码通常为单行
  Link(String, String) // title, url（文本子节点可在后续扩展）
  Image(String, String) // alt, src
}

///|
// 块级节点（Block）
pub enum Block {
  Paragraph(Text) // 段落文本：可单行或多行
  Heading(Int, Text) // 标题文本：一般单行，但用 Text 以统一模型
  CodeBlock(String, Text) // language, code：代码块通常多行
  BlockQuote
  List
  ListItem(Bool, Text) // is_ordered, label：标签文本
}
