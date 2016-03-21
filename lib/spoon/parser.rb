require "parslet"
require "parslet/convenience"

require "spoon/util/indent_parser"

module Spoon
  # Monkey-patch the parser to include some common methods
  class Spoon::Util::IndentParser
    # Matches string and skips space after it
    def sym(value) str(value) >> space? end

    # Matches keyword and skips space after it
    def key(value) keyword(value) >> space? end

    # Matches string or keyword, based on if it is word or not
    def op(value) trim(/\w/.match(value) ? key(value) : sym(value)) end

    # Trims all whitespace around value
    def trim(value) whitespace? >> value >> whitespace? end

    # Matches value in parens or not in parens
    def parens(value) (op("(") >> value.maybe >> op(")")) | value end

    # Matches single or multiple end of lines
    rule(:newline)     { match["\n\r"].repeat(1) }
    rule(:newline?)    { newline.maybe }

    # Matches single or multiple spaces, tabs and comments
    rule(:space)       { (match("\s") | comment).repeat(1) }
    rule(:space?)      { space.maybe }

    # Matches all whitespace (tab, end of line, space, comments)
    rule(:whitespace)  { (match["\s\n\r"] | comment).repeat(1) }
    rule(:whitespace?) { whitespace.maybe }

    # Matches all lowercase words except keys, then skips space after them
    # example: abc
    rule(:name)        { skip_key >> match["a-z"].repeat(1).as(:name) >> space? }

    # Matches simple numbers
    # example: 123
    rule(:number)      { match["0-9"].repeat(1).as(:number) }

    # Matches everything until end of line
    rule(:stop)        { match["^\n"].repeat }

    # Matches everything that starts with '#' until end of line
    # example: # abc
    rule(:comment)     { str("#") >> stop.as(:comment) }
  end

  class Parser < Spoon::Util::IndentParser
    # Matches entire file, skipping all whitespace at beginning and end
    rule(:root)      { trim(expressions | statement.repeat(1)) }

    # Matches value
    rule(:value)     { condition | closure | name | number }

    # Matches statement (unassignable and unmovable value)
    rule(:statement) { function }

    # Matches indented block and consumes newlines at start and in between
    # but not at end
    rule(:block) {
      newline? >> indent >>
        (expression >>
          (newline? >> samedent >> expression).repeat).maybe.as(:block) >>
      dedent
    }

    # Matches expression or indented block and skips end of line at end
    rule(:body)     { (block | expression) >> newline? }

    # FIXME: Should match chain of expressions
    # example: abc(a).def(b).efg
    rule(:chain)    { ((name | call) >> (sym(".") >> name | call).repeat(0)).maybe.as(:chain) }

    # FIXME: Should match function call
    # example: a(b, c, d, e, f)
    rule(:call)     { name >> sym("(").maybe >> expression_list >> sym(")").maybe }

    # Matches function definition
    # example: def (a) b
    rule(:function) {
      (key("def") >> name.as(:name) >>
        (body.as(:body) | parens(parameter_list).maybe >> body.as(:body))).as(:function)
    }

    # Matches closure
    # example: (a) -> b
    rule(:closure)  { (parens(parameter_list).maybe >> sym("->") >> body.as(:body)).as(:closure) }

    # Matches function parameter
    # example a = 1
    rule(:parameter) { name.as(:name) >> (op("=") >> expression.as(:value)).maybe }

    # Matches comma delimited function parameters
    # example: (a, b)
    rule(:parameter_list)   { (parameter >> (sym(",") >> parameter).repeat(0)).maybe.as(:parameters) }

    # Matches if-else if-else in recursive structure
    # example: if (a) b else if(c) d else e
    rule(:condition) {
      (key("if") >> parens(expression.as(:body)) >>
          body.maybe.as(:if_true) >>
      (key("else") >> body.maybe.as(:if_false)).maybe).as(:condition)
    }

    rule(:operator) {
        (op("or") | op("and") | op("<=") |
        op(">=") | op("!=") | op("==") |
        trim(match['\+\-\*\/%\^><\|&'])).as(:op)
    }

    rule(:assign) { sym("=") >> expression_list.as(:assign) }

    rule(:update) {
      ((op("+=") | op("-=") | op("*=") | op("/=") |
      op("%=") | op("or=") | op("and=")).as(:op) >> expression).as(:update)
    }

    # Matches one or more exressions
    rule(:expressions?) { expressions.maybe }
    rule(:expressions) { expression.repeat(1) }
    rule(:expression) { value.as(:left) >> (operator >> value.as(:right)).maybe }

    # Matches comma delimited expressions
    # example: a(b), c(d), e
    rule(:expression_list) { (expression >> (sym(",") >> expression).repeat(0)) }
  end
end
