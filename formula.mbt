///|
priv enum Expr {
  Constant(Double)
  Variable
  Negative(Expr)
  Binary(Char, Expr, Expr)
  Call(String, Array[Expr])
}

///|
priv struct FormulaParser {
  chars : Array[Char]
  mut pos : Int32
}

///|
fn skip_space(p : FormulaParser) -> Unit {
  while p.pos < p.chars.length() &&
        (
          p.chars[p.pos] == ' ' ||
          p.chars[p.pos] == '\t' ||
          p.chars[p.pos] == '\n' ||
          p.chars[p.pos] == '\r'
        ) {
    p.pos += 1
  }
}

///|
fn peek(p : FormulaParser) -> Char {
  skip_space(p)
  if p.pos < p.chars.length() {
    p.chars[p.pos]
  } else {
    '\u0000'
  }
}

///|
fn digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn decimal(p : FormulaParser) -> Double raise MdfError {
  let literal_start = p.pos
  let mut count = 0
  while p.pos < p.chars.length() && digit(p.chars[p.pos]) {
    p.pos += 1
    count += 1
  }
  if p.pos < p.chars.length() && p.chars[p.pos] == '.' {
    p.pos += 1
    while p.pos < p.chars.length() && digit(p.chars[p.pos]) {
      p.pos += 1
      count += 1
    }
  }
  if count == 0 {
    raise InvalidFormula("expected number")
  }
  if p.pos < p.chars.length() &&
    (p.chars[p.pos] == 'e' || p.chars[p.pos] == 'E') {
    p.pos += 1
    if p.pos < p.chars.length() &&
      (p.chars[p.pos] == '+' || p.chars[p.pos] == '-') {
      p.pos += 1
    }
    let mut exponent = 0
    let start = p.pos
    while p.pos < p.chars.length() && digit(p.chars[p.pos]) {
      exponent = exponent * 10 + p.chars[p.pos].to_int() - 48
      if exponent > 1000 {
        raise InvalidFormula("numeric exponent limit")
      }
      p.pos += 1
    }
    if start == p.pos {
      raise InvalidFormula("missing exponent digits")
    }
  }
  // Lex the restricted grammar first, then round the complete decimal once.
  // Scaling a rounded mantissa by pow(10, exponent) loses subnormals and can
  // overflow before a compensating negative exponent is applied.
  let literal = String::from_array(p.chars[literal_start:p.pos])
  let v = @string.parse_double(literal[:]) catch {
    _ => raise InvalidFormula("non-finite literal")
  }
  if !finite(v) {
    raise InvalidFormula("non-finite literal")
  }
  v
}

///|
fn parse_expr(
  p : FormulaParser,
  min_bp : Int32,
  depth : Int32,
) -> Expr raise MdfError {
  if depth > 64 {
    raise InvalidFormula("expression nesting limit")
  }
  let c = peek(p)
  let mut left = if c == '+' || c == '-' {
    p.pos += 1
    let arg = parse_expr(p, 25, depth + 1)
    if c == '-' {
      Negative(arg)
    } else {
      arg
    }
  } else if c == '(' {
    p.pos += 1
    let arg = parse_expr(p, 0, depth + 1)
    if peek(p) != ')' {
      raise InvalidFormula("missing closing parenthesis")
    }
    p.pos += 1
    arg
  } else if digit(c) || c == '.' {
    Constant(decimal(p))
  } else if alpha(c) {
    let start = p.pos
    while p.pos < p.chars.length() &&
          (alpha(p.chars[p.pos]) || digit(p.chars[p.pos])) {
      p.pos += 1
    }
    let name = String::from_array(p.chars[start:p.pos])
    if name == "X" || name == "X1" {
      Variable
    } else if name == "PI" || name == "pi" {
      Constant(3.141592653589793)
    } else if name == "e" {
      Constant(2.718281828459045)
    } else {
      if peek(p) != '(' {
        raise InvalidFormula("unknown variable \{name}")
      }
      p.pos += 1
      let args : Array[Expr] = []
      if peek(p) != ')' {
        args.push(parse_expr(p, 0, depth + 1))
        while peek(p) == ',' {
          p.pos += 1
          args.push(parse_expr(p, 0, depth + 1))
        }
      }
      if peek(p) != ')' {
        raise InvalidFormula("missing function closing parenthesis")
      }
      p.pos += 1
      Call(name, args)
    }
  } else {
    raise InvalidFormula("expected operand at \{p.pos}")
  }
  for ;; {
    let mut op = peek(p)
    let power_pair = op == '*' &&
      p.pos + 1 < p.chars.length() &&
      p.chars[p.pos + 1] == '*'
    if power_pair {
      op = '^'
    }
    let bp = match op {
      '+' | '-' => 10
      '*' | '/' => 20
      '^' => 30
      _ => -1
    }
    if bp < min_bp {
      break
    }
    p.pos += if power_pair { 2 } else { 1 }
    let rhs = parse_expr(p, if op == '^' { bp } else { bp + 1 }, depth + 1)
    left = Binary(op, left, rhs)
  }
  left
}

///|
fn evaluate(e : Expr, x : Double, depth : Int32) -> Double raise MdfError {
  if depth > 256 {
    raise InvalidFormula("AST depth limit")
  }
  let y = match e {
    Constant(c) => c
    Variable => x
    Negative(a) => -evaluate(a, x, depth + 1)
    Binary(op, a, b) => {
      let a = evaluate(a, x, depth + 1)
      let b = evaluate(b, x, depth + 1)
      match op {
        '+' => a + b
        '-' => a - b
        '*' => a * b
        '/' => a / b
        '^' => @math.pow(a, b)
        _ => raise InvalidFormula("unknown operator")
      }
    }
    Call(name, args) => {
      if args.length() < 1 || args.length() > 2 {
        raise InvalidFormula("function arity")
      }
      let a = evaluate(args[0], x, depth + 1)
      if args.length() == 2 {
        let b = evaluate(args[1], x, depth + 1)
        match name {
          "min" => if a < b { a } else { b }
          "max" => if a > b { a } else { b }
          "pow" => @math.pow(a, b)
          _ => raise InvalidFormula("unknown binary function \{name}")
        }
      } else {
        match name {
          "sin" => @math.sin(a)
          "cos" => @math.cos(a)
          "tan" => @math.tan(a)
          "asin" => @math.asin(a)
          "acos" => @math.acos(a)
          "atan" => @math.atan(a)
          "exp" => @math.exp(a)
          "ln" | "log" => @math.ln(a)
          "log10" => @math.log10(a)
          "sqrt" => a.sqrt()
          "abs" => a.abs()
          "floor" => @math.floor(a)
          "ceil" => @math.ceil(a)
          _ => raise InvalidFormula("unknown unary function \{name}")
        }
      }
    }
  }
  if !finite(y) {
    raise InvalidFormula("domain/non-finite expression result")
  }
  y
}

///|
fn eval_formula(f : String, x : Double) -> Double raise MdfError {
  if f.length() > 4096 {
    raise InvalidFormula("expression length limit")
  }
  let p = { chars: f.to_array(), pos: 0, }
  let e = parse_expr(p, 0, 0)
  skip_space(p)
  if p.pos != p.chars.length() {
    raise InvalidFormula("trailing expression input")
  }
  evaluate(e, x, 0)
}
