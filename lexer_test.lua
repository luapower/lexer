local lexer = require'lexer'
lexer.LEXERPATH = 'media/lexers/?.lua'
local c = lexer.load('ansi_c')
local tokens = c:lex('int void main() { return 0; }')
for i = 1, #tokens, 2 do print(tokens[i], tokens[i+1]) end
