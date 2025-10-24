///|
// Markdown 词法 Token 定义（MoonBit enum）
// 先只提供稳定类型，后续分步实现 tokenizer 与 parser。
// duplicate Token enum removed; using definition in tokenizer.mbt

///|
// 基础 Tokenizer：按字符扫描，生成 Array[Token]
// 说明：
// - 兼容 CRLF 与 LF，将其统一为单个 Newline。
// - 连续的 #、*、` 计数为一个 Token（Hash/Star/Backtick）。
// - 数字视为普通文本的一部分（保留原文，如中文和数字）。
// - 其余字符以单字符 Text 输出（后续可再聚合连续文本以提效）。
// duplicate tokenize removed; using implementation in tokenizer.mbt

///|
// 调试辅助：把 Token 列表转换为字符串数组，方便测试快照
// duplicate debug helper removed

///|
// duplicate debug helper removed
