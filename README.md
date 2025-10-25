## Markdown 解析器
### 介绍 
这是一个用 moonbit 语言编写用于解析 Markdown 文本的轻量解析器
- 支持常见的 Markdown 语法
- 把 Markdown 格式的文本转换为 HTML 格式
- 运行主函数能把 Markdown 文件转换为 HTML 文件并输出出来
- 使用了 fs 库进行文件操作（更新内容）
### 使用方法
1. 克隆代码库到本地
2. 传入 Markdown 文件路径作为参数， 修改输出文件路径
3. 运行主函数进行转换，打开生成的 HTML 文件
```shell
    moon run ./src/main.mbt
```
### 示例
在 README.md 同目录下删除 output.html 文件（如果存在的话）  
运行主函数后会生成 output.html 文件，打开即可看在浏览器中看到本文档的 HTML 渲染效果