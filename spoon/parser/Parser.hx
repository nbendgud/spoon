package spoon.parser;

import hxparse.Position;
import hxparse.Parser.parse as _;
import hxparse.LexerTokenSource;
import spoon.log.Message;
import spoon.log.Logger;
import spoon.log.LogParser;
import spoon.lexer.Lexer;
import spoon.lexer.Token;
import spoon.parser.Expression;

using StringTools;

class Parser extends hxparse.Parser<LexerTokenSource<Token>, Token> {
  public function new(logParser : LogParser, input:String, sourceName:String) {
    var lexer = new Lexer(byte.ByteData.ofString(input), sourceName);
    var ts = new LexerTokenSource(lexer, Lexer.tok);
    Logger.intialize(logParser, byte.ByteData.ofString(input));
    super(ts);
  }

  public function run() : Expressions {
    var v = new Expressions();

    try {
      while(true) _(switch stream {
        case [TEof(_)]: break;
        case [e = parseExpression()]: v.push(e);
      });
    } catch (e : hxparse.NoMatch<Dynamic>) {
      Logger.self.log({
        type: NoMatch,
        severity: Error,
        position: e.pos,
        description: Type.enumConstructor(e.token)
      });
    } catch (e : hxparse.Unexpected<Dynamic>) {
      Logger.self.log({
        type: Unexpected,
        severity: Error,
        position: e.pos,
        description: Type.enumConstructor(e.token)
      });
    } catch (e : hxparse.UnexpectedChar) {
      Logger.self.log({
        type: Unexpected,
        severity: Error,
        position: e.pos,
        description: e.char
      });
    }

    return v;
  }

  function parseExpression() : Expression return {
    _(switch stream {
      case [e = parseBlock()]: e;
      case [e = parseCondition()]: e;
      case [e = parseFor()]: e;
      case [e = parseWhile()]: e;
      case [e = parseConst()]: e;
    });
  }

  function parseConst() : Expression return {
    var v : Constant;
    var p : Position;

    _(switch stream {
      case [TTrue(tp)]: p = tp; v = CBool("true");
      case [TFalse(tp)]: p = tp; v = CBool("false");
      case [TNull(tp)]: p = tp; v = CNull;
      case [TInt(tp, tv)]: p = tp; v = CInt(tv);
      case [TFloat(tp, tv)]: p = tp; v = CFloat(tv);
      case [TString(tp, tv)]: p = tp; v = CString(tv);
      case [TIdent(tp, tv)]: p = tp; v = CIdent(tv);
      case [TType(tp, tv)]: p = tp; v = CType(tv);
    });

    {
      expr: Const(v),
      pos: p
    }
  }

  function parseBlock() : Expression return {
    var v = new Expressions();
    var p : Position;

    _(switch stream {
      case [TIndent(tp)]:
        p = tp;

        while(true) switch stream {
          case [TDedent(_) | TEof(_)]: break;
          case [e = parseExpression()]: v.push(e);
        }
    });

    {
      expr: Block(v),
      pos: p
    }
  }

  function parseCondition() : Expression return {
    var vIf : Expression;
    var vElse : Null<Expression> = null;
    var vElsIf : Null<Expressions> = null;

    _(switch stream {
      case [TIf(tp)]:
        vIf = {
          expr: If(parseExpression(), parseExpression()),
          pos: tp
        }

        while(true) switch stream {
          case [TElsIf(tp), condition = parseExpression(), body = parseExpression()]:
            vElsIf.push({
              expr: If(condition, body),
              pos: tp
            });
          case [TElse(tp), e = parseExpression()]:
            vElse = {
              expr: Else(e),
              pos: tp
            }
          default: break;
        }
    });

    {
      expr: Condition(vIf, vElsIf, vElse),
      pos: vIf.pos
    }
  }

  function parseFor() : Expression return {
    _(switch stream {
      case [TFor(tp)]:
        {
          expr: For(parseExpression(), parseExpression()),
          pos: tp
        }
    });
  }

  function parseWhile() : Expression return {
    _(switch stream {
      case [TWhile(tp)]:
        {
          expr: While(parseExpression(), parseExpression()),
          pos: tp
        }
    });
  }
}