module thBase.boolexpr;
import thBase.container.hashmap;
import thBase.policies.hashing;
import thBase.conv;
import thBase.format;

struct Value
{
  enum Type
  {
    _bool,
    symbol,
    _int
  }
  Type type;
  union
  {
    bool b;
    const(char)[] sym;
    int i;
  }

  this(bool value)
  {
    this.b = value;
    this.type = Type._bool;
  }

  this(const(char)[] value)
  {
    this.sym = value;
    this.type = Type.symbol;
  }

  this(int value)
  {
    this.i = value;
    this.type = Type._int;
  }
}

alias Context = Hashmap!(const(char)[], Value, StringHashPolicy);

class EvalError : RCException
{
  this(rcstring msg, string file = __FILE__, size_t line = __LINE__)
  {
    super(msg, file, line);
  }
}

class ParseError : RCException
{
  this(rcstring msg, string file = __FILE__, size_t line = __LINE__)
  {
    super(msg, file, line);
  }
}

class AstNode
{
public:
  abstract Value eval(Context) const;
}

class DefinedNode : AstNode
{
private:
  AstNode symbol;

public:
  this(AstNode symbol)
  {
    this.symbol = symbol;
  }

  ~this()
  {
    Delete(symbol);
  }

  override Value eval(Context context) const
  {
    auto sym = cast(ValueNode)symbol;
    if(sym is null || sym.value.type != Value.Type.symbol)
    {
      throw New!EvalError(format("'defined' expected a symbol but got a '%s'", (sym is null) ? typeid(symbol).toString()[] : EnumToString(sym.value.type)));
    }
    return Value(context.exists(sym.value.sym));
  }
}

class ValueNode : AstNode
{
private:
  Value value;

public:
  this(Value value)
  {
    this.value = value;
  }

  override Value eval(Context context) const
  {
    if(value.type == Value.Type.symbol)
    {
      Value temp;
      if(!context.tryGet(value.sym, temp))
        throw New!EvalError(format("'%s' does not exist", value.sym));
      return temp;
    }
    return value;
  }
}

class BinaryOperatorNode : AstNode
{
protected:
  AstNode lhs, rhs;
}

class BinaryOperatorNodeImpl(string op, Value.Type expectedType) : BinaryOperatorNode
{


public:
  ~this()
  {
    Delete(lhs);
    Delete(rhs);
  }

  override Value eval(Context context) const
  {
    auto vlhs = lhs.eval(context);
    auto vrhs = rhs.eval(context);
    if(vlhs.type != expectedType)
      throw New!EvalError(format(op ~ " left hand side is not a %s value but a '%s'", EnumToString(expectedType), EnumToString(vlhs.type)));
    if(vrhs.type != expectedType)
      throw New!EvalError(format(op ~ " right hand side is not a %s value but a '%s'", EnumToString(expectedType), EnumToString(vrhs.type)));
    return Value(mixin("vlhs.b " ~ op ~  " vrhs.b"));
  }
}

class NotNode : AstNode
{
private:
  AstNode value;

public:
  this(AstNode value)
  {
    this.value = value;
  }

  ~this()
  {
    Delete(value);
  }

  override Value eval(Context context) const
  {
    auto v = value.eval(context);
    if(v.type != Value.Type._bool)
      throw New!EvalError(format("not expected a boolean value but got a '%s'", EnumToString(v.type)));
    return Value(!v.b);
  }
}

private
{
  struct ParserState
  {
    const(char)[] expr;
    int i;
  }

  void skipWhitespace(ref ParserState s)
  {
    while(s.i < s.expr.length && (s.expr[s.i] == ' ' || s.expr[s.i] == '\t' || s.expr[s.i] == '\r' || s.expr[s.i] == '\n'))
    {
      s.i++;
    }
  }

  size_t countUntil(string cond)(ref ParserState s)
  {
    auto j = s.i;
    while(j < s.expr.length)
    {
      auto curChar = s.expr[j];
      if(mixin(cond))
        break;
      j++;
    }
    return j - s.i;
  }

  void unexpectedClosingBracket()
  {
    throw New!ParseError(_T("unexpected ')'"));
  }

  void expectedBracket()
  {
    throw New!ParseError(_T("expected ')'"));
  }

  void unexpectedEndOfInput()
  {
    throw New!ParseError(_T("unexpected end of input"));
  }

  AstNode parseHelper(ref ParserState s)
  {
    skipWhitespace(s);
    char curChar = s.expr[s.i];
    if(curChar >= '0' && curChar <= '9')
      return parseInt(s);
    if(curChar == '(')
      return parseGroup(s);
    if(curChar == ')')
      unexpectedClosingBracket();
    if(curChar == '!')
      return parseNot(s);
    if(curChar == 'd' && s.expr.length - s.i >= "defined".length && s.expr[s.i .. s.i + "defined".length] == "defined")
    {
      s.i += "defined".length;
      skipWhitespace(s);
      if(s.expr[s.i] != '(')
        throw New!ParseError(_T("expected '(' after 'defined'"));
      s.i++; // consume (
      skipWhitespace(s);
      auto symbol = parseSymbol(s);
      skipWhitespace(s);
      if(s.i >= s.expr.length)
        unexpectedEndOfInput();
      if(s.expr[s.i] != ')')
        expectedBracket();
      s.i++; // consume )
      return New!DefinedNode(symbol);
    }
    return parseSymbol(s);
  }

  AstNode parseInt(ref ParserState s)
  {
    skipWhitespace(s);
    auto end = countUntil!"curChar < '0' || curChar > '9'"(s);
    auto str = s.expr[s.i..s.i+end];
    s.i += end;
    int result;
    if(to!int(str, result) != thResult.SUCCESS)
    {
      throw New!ParseError(format("'%s' is not a valid integer", str));
    }
    return New!ValueNode(Value(result));
  }

  BinaryOperatorNode parseOperator(ref ParserState s)
  {
    skipWhitespace(s);
    auto curChar = s.expr[s.i];
    switch(curChar)
    {
      case '&':
        if(s.i + 1 >= s.expr.length)
          unexpectedEndOfInput();
        if(s.expr[s.i+1] == '&')
        {
          s.i += 2;
          return New!(BinaryOperatorNodeImpl!("&&", Value.Type._bool))();
        }
        break;
      case '|':
        if(s.i + 1 >= s.expr.length)
          unexpectedEndOfInput();
        if(s.expr[s.i+1] == '|')
        {
          s.i += 2;
          return New!(BinaryOperatorNodeImpl!("||", Value.Type._bool))();
        }
        break;
      case '<':
        s.i++;
        return New!(BinaryOperatorNodeImpl!("<", Value.Type._int))();
      case '>':
        s.i++;
        return New!(BinaryOperatorNodeImpl!(">", Value.Type._int))();
      case '=':
        if(s.i + 1 >= s.expr.length)
          unexpectedEndOfInput();
        if(s.expr[s.i+1] == '=')
        {
          s.i += 2;
          return New!(BinaryOperatorNodeImpl!("==", Value.Type._int))();
        }
        break;
      case '!':
        if(s.i + 1 >= s.expr.length)
          unexpectedEndOfInput();
        if(s.expr[s.i+1] == '=')
        {
          s.i += 2;
          return New!(BinaryOperatorNodeImpl!("!=", Value.Type._int))();
        }
        break;
      default:
    }

    auto end = countUntil!"curChar == ' ' || curChar == '\\t' || curChar == '\\r' || curChar == '\\n'"(s);
    throw New!ParseError(format("unkown operator '%s'", s.expr[s.i..s.i+end])); 
  }

  AstNode parseGroup(ref ParserState s)
  {
    assert(s.expr[s.i] == '(');
    s.i++; // consume '('
    auto op = parseBinaryExpr(s);
    skipWhitespace(s);
    if(s.i >= s.expr.length)
      unexpectedEndOfInput();
    while(s.expr[s.i] != ')')
    {
      auto op2 = parseOperator(s);
      auto rhs = parseHelper(s);
      op2.lhs = op;
      op2.rhs = rhs;
      op = op2;
      skipWhitespace(s);
      if(s.i >= s.expr.length)
        unexpectedEndOfInput();
    }
    if(s.expr[s.i] != ')')
      expectedBracket();
    s.i++; // consume ')'
    return op;
  }

  BinaryOperatorNode parseBinaryExpr(ref ParserState s)
  {
    auto lhs = parseHelper(s);
    auto op = parseOperator(s);
    auto rhs = parseHelper(s);
    op.lhs = lhs;
    op.rhs = rhs;
    return op;
  }

  NotNode parseNot(ref ParserState s)
  {
    assert(s.expr[s.i] == '!');
    s.i++; // consume !
    return New!NotNode(parseHelper(s));
  }

  ValueNode parseSymbol(ref ParserState s)
  {
    auto end = countUntil!"curChar == ' ' || curChar == '\\t' || curChar == '\\r' || curChar == '\\n' || curChar == ')'"(s);
    auto str = s.expr[s.i..s.i+end];
    s.i += end;
    return New!ValueNode(Value(str));
  }
}

AstNode parse(const(char)[] expr)
{
  auto s = ParserState(expr, 0);

  auto result = parseHelper(s);
  skipWhitespace(s);
  while(s.i < s.expr.length)
  {
    auto op = parseOperator(s);
    auto rhs = parseHelper(s);
    op.lhs = result;
    op.rhs = rhs;
    result = op;
    skipWhitespace(s);
  }
  return result;
}

unittest
{
  auto context = composite!Context(defaultCtor);

  context["SYM1"] = Value(true);
  context["SYM2"] = Value(1);
  context["SYM3"] = Value(false);
  context["SYM4"] = Value(true);

  void test(const(char)[] expression, bool expectedResult)
  {
    try
    {
      auto ast = parse(expression);
      scope(exit) Delete(ast);
      auto result = ast.eval(context);
      assert(result.type == Value.Type._bool, "result is not a boolean");
      assert(result.b == expectedResult, "result is not correct");
    }
    catch(RCException ex)
    {
      assert(false, ex.msg);
      Delete(ex);
    }
  }

  test("defined(SYM1)", true);
  test("defined(NOT)", false);
  test("!defined(NOT)", true);
  test(" defined ( SYM1 ) ", true);
  test("SYM1 && SYM3", false);
  test("SYM1 || SYM3", true);
  test("(SYM1 && SYM3)", false);
  test("(SYM1 || SYM3)", true);
  test("!(SYM1 && SYM3)", true);
  test("(SYM1 && SYM3) || (SYM3 || SYM1)", true);
  test("SYM1 && SYM3 && SYM4", false);
  test("SYM1 && SYM3 && SYM4 && SYM1", false);
  test("defined(SYM1) && defined(SYM3) && defined(SYM4)", true);
  test("SYM2 == 1", true);
  test("SYM2 != 1", false);
  test("SYM2 < 2", true);
  test("SYM2 > 2", false);
}