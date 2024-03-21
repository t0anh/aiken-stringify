use aiken/builtin
use aiken/bytearray
use aiken/cbor
use aiken/dict.{Dict}
use aiken/list
use aiken/string
use aiken/transaction.{
  Datum, InlineDatum, Input, Mint, NoDatum, Output, OutputReference, Publish,
  Redeemer, ScriptPurpose, Spend, Transaction, TransactionId, WithdrawFrom,
}
use aiken/transaction/credential.{
  Address, Credential, Inline, ScriptCredential, StakeCredential,
  VerificationKeyCredential,
}
use aiken/transaction/value.{MintedValue,
  Value, flatten, from_minted_value} as value_utils

pub fn int(val) -> String {
  string.from_int(val)
}

fn credential(cred: Credential) -> String {
  when cred is {
    VerificationKeyCredential(hash) ->
      string.concat(
        @"VerificationKeyCredential",
        string.from_bytearray(hash) |> with_single_quotes |> with_parentheses,
      )
    ScriptCredential(hash) ->
      string.concat(
        @"ScriptCredential",
        string.from_bytearray(hash) |> with_single_quotes |> with_parentheses,
      )
  }
}

pub fn stake_credential(self: Option<StakeCredential>) {
  when self is {
    None -> @"None"
    Some(Inline(cred)) -> credential(cred)
    _ -> fail @"Unsupported type of stake credential"
  }
}

pub fn out_ref(self: OutputReference) {
  do_out_ref(self) |> indent
}

fn do_out_ref(self: OutputReference) {
  let OutputReference(TransactionId(tx_hash), index) = self
  @"OutputReference(TransactionId({}), {})"
    |> apply_params(
         [
           string.from_bytearray(tx_hash) |> with_single_quotes,
           string.from_int(index),
         ],
       )
}

pub fn address(self: Address) {
  do_address(self) |> indent
}

fn do_address(self: Address) {
  @"Address {\npayment_credential: {},\nstake_credential: {},\n}"
    |> apply_params(
         [
           credential(self.payment_credential),
           stake_credential(self.stake_credential),
         ],
       )
}

pub fn value(self: Value) {
  do_value(self) |> indent
}

fn do_value(self: Value) {
  @"Value"
    |> string.concat(
         self
           |> flatten
           |> list.map(
                fn(asset) {
                  let (pid, name, qty) = asset
                  [
                    to_safe_string(pid) |> with_single_quotes,
                    to_safe_string(name) |> with_single_quotes,
                    string.from_int(qty),
                  ]
                    |> string.join(@", ")
                    |> with_parentheses
                },
              )
           |> string.join(
                @",\n",
              )
           |> as_block
           |> with_square_brackets
           |> with_parentheses,
       )
}

pub fn minted_value(self: MintedValue) {
  value(from_minted_value(self))
}

pub fn data(self: Data) -> String {
  cbor.diagnostic(self)
    |> format_cbor
    |> indent
}

pub fn datum(self: Datum) {
  when self is {
    NoDatum -> @"NoDatum"
    InlineDatum(dtm) ->
      @"InlineDatum({})"
        |> apply_params(
             [
               cbor.diagnostic(dtm)
                 |> format_cbor,
             ],
           )
    _ -> fail @"unsupported datum"
  }
}

pub fn output(self: Output) {
  do_output(self) |> indent
}

fn do_output(self: Output) {
  @"Output {\naddress: {},\nvalue: {},\ndatum: {}\n}"
    |> apply_params([address(self.address), value(self.value), datum(self.datum)])
}

pub fn input(self: Input) {
  do_input(self) |> indent
}

fn do_input(self: Input) {
  @"Input {\noutput_reference: {},\noutput: {}\n}"
    |> apply_params([do_out_ref(self.output_reference), do_output(self.output)])
}

pub fn redeemers(self: Dict<ScriptPurpose, Redeemer>) {
  do_redeemers(self) |> indent
}

fn do_redeemers(self: Dict<ScriptPurpose, Redeemer>) {
  list.map(
    dict.keys(self),
    fn(purpose) {
      string.concat(
        @"Purpose",
        when purpose is {
          Spend(ref) ->
            @"Spend"
              |> string.concat(
                   out_ref(ref)
                     |> with_parentheses,
                 )
          Mint(pid) ->
            @"Mint"
              |> string.concat(
                   string.from_bytearray(pid)
                     |> with_single_quotes
                     |> with_parentheses,
                 )
          WithdrawFrom(cred) ->
            string.concat(
              @"WithdrawFrom",
              stake_credential(Some(cred)) |> with_parentheses,
            )
          Publish(cert) ->
            string.concat(@"Publish", cbor.diagnostic(cert) |> with_parentheses)
        }
          |> with_parentheses,
      )
    },
  )
    |> string.join(
         @",\n",
       )
    |> as_block
    |> with_square_brackets
}

pub fn tx(self: Transaction) {
  @"Transaction {\nredeemers: {},\nextra_signatories: {},\nmint: {},\nreference_inputs: {},\ninputs: {},\noutputs: {},\n}"
    |> apply_params(
         [
           do_redeemers(self.redeemers),
           self.extra_signatories
             |> list.map(
                  fn(sig) {
                    string.from_bytearray(sig)
                      |> with_single_quotes
                  },
                )
             |> string.join(@", ")
             |> with_square_brackets,
           value(self.mint |> from_minted_value),
           when self.reference_inputs is {
             [] -> @"[]"
             _ ->
               list.map(self.reference_inputs, fn(inp) { do_input(inp) })
                 |> string.join(
                      @",\n",
                    )
                 |> as_block
                 |> with_square_brackets
           },
           when self.inputs is {
             [] -> @"[]"
             _ ->
               list.map(self.inputs, fn(inp) { do_input(inp) })
                 |> string.join(
                      @",\n",
                    )
                 |> as_block
                 |> with_square_brackets
           },
           when self.outputs is {
             [] -> @"[]"
             _ ->
               list.map(self.outputs, fn(out) { do_output(out) })
                 |> string.join(
                      @",\n",
                    )
                 |> as_block
                 |> with_square_brackets
           },
         ],
       )
    |> indent
}

// ========== utils ============
fn tab(lvl: Int) {
  list.repeat(@"  ", lvl) |> string.join(@"")
}

pub fn indent(str: String) {
  do_indent(string.to_bytearray(str), 0) |> bytearray.to_string
}

pub fn log(self: a, msg: String, serializer: fn(a) -> String) -> a {
  builtin.debug(string.concat(msg, serializer(self)), self)
}

fn do_indent(bytes: ByteArray, lvl: Int) {
  let next_newline_cursor = bytearray.index_of(bytes, "\n")
  when next_newline_cursor is {
    Some((_, cursor)) -> {
      let left = bytearray.take(bytes, cursor)
      let right = bytearray.slice(bytes, cursor + 1, bytearray.length(bytes))
      let indent_lvl =
        bytearray.foldl(
          left,
          lvl,
          fn(byte, cur) {
            if is_open(to_bytearray(byte)) {
              cur + 1
            } else if is_close(to_bytearray(byte)) {
              cur - 1
            } else {
              cur
            }
          },
        )
      left
        |> bytearray.concat("\n")
        |> bytearray.concat(
             tab(
               if is_close(bytearray.slice(bytes, cursor + 1, cursor + 1)) {
                 indent_lvl - 1
               } else {
                 indent_lvl
               },
             )
               |> bytearray.from_string,
           )
        |> bytearray.concat(do_indent(right, indent_lvl))
    }
    None -> bytes
  }
}

fn apply_params(template: String, params: List<String>) -> String {
  do_apply_params(template |> string.to_bytearray, params)
    |> bytearray.to_string
}

fn do_apply_params(template: ByteArray, params: List<String>) -> ByteArray {
  when params is {
    [param, ..rest_params] ->
      when bytearray.index_of(template, "{}") is {
        None -> template
        Some((from, to)) ->
          bytearray.slice(template, 0, from - 1)
            |> bytearray.concat(bytearray.from_string(param))
            |> bytearray.concat(
                 do_apply_params(bytearray.drop(template, to + 1), rest_params),
               )
      }
    [] -> template
  }
}

fn with_single_quotes(builder: String) {
  [@"'", @"'"] |> string.join(builder)
}

fn with_parentheses(builder: String) {
  [@"(", @")"] |> string.join(builder)
}

fn with_square_brackets(builder: String) {
  [@"[", @"]"] |> string.join(builder)
}

fn as_block(builder: String) {
  [
    @"\n",
    @"\n",
  ]
    |> string.join(builder)
}

pub fn first_of_quad(quad: (a, b, c, d)) {
  quad.1st
}

pub fn first_of_triple(tuple: (a, b, c)) {
  tuple.1st
}

pub fn pop_back(self: ByteArray, qty: Int) {
  bytearray.take(self, builtin.length_of_bytearray(self) - qty)
}

pub fn last_char(self: ByteArray) {
  bytearray.drop(self, builtin.length_of_bytearray(self) - 1)
}

pub fn is_open(chr: ByteArray) {
  or {
    chr == "[",
    chr == "{",
  }
}

pub fn is_close(chr: ByteArray) {
  or {
    chr == "]",
    chr == "}",
  }
}

pub fn newline(self: ByteArray) {
  self |> bytearray.concat("\n")
}

pub fn to_decimal(byte: Int) {
  if byte >= 97 && byte <= 102 {
    byte - 97 + 10
  } else if byte >= 65 && byte <= 70 {
    byte - 65 + 10
  } else if byte >= 48 && byte <= 57 {
    byte - 48
  } else {
    fail @"invalid digit"
  }
}

pub fn hex_to_string(hex: ByteArray) {
  bytearray.foldl(
    // pushing a dummy byte to flush the last character 
    hex |> bytearray.concat("0"),
    ("", 0, 0),
    fn(byte, results) {
      let (acc, code, idx) = results
      let dec = to_decimal(byte)
      if idx > 0 && idx % 2 == 0 {
        (
          acc
            |> bytearray.concat(code |> to_safe_code |> to_bytearray),
          dec,
          idx + 1,
        )
      } else {
        (acc, code * 16 + dec, idx + 1)
      }
    },
  )
    |> first_of_triple
}

fn format_cbor(cbr: String) {
  cbr
    |> bytearray.from_string
    |> do_format_cbor
    |> bytearray.to_string
}

pub fn to_bytearray(byte: Int) {
  #"" |> bytearray.push(byte)
}

pub fn do_format_cbor(bytes) {
  bytes
    |> bytearray.foldl(
         ("", 0, False, ""),
         fn(byte, results) {
           let (builder, level, has_token, token) = results
           let chr = to_bytearray(byte)
           if is_open(chr) {
             (
               builder
                 |> bytearray.concat(chr),
               level + 1,
               has_token,
               token,
             )
           } else if is_close(chr) {
             (
               builder
                 |> fn(builder) {
                      if !has_token && builtin.length_of_bytearray(token) > 0 {
                        builder
                          |> bytearray.concat(", # ")
                          |> bytearray.concat(
                               token
                                 |> hex_to_string,
                             )
                      } else {
                        builder
                      }
                    }
                 |> fn(builder) {
                      // pretty empty struct to be inline
                      let last_chr = builder |> pop_back(level + 1) |> last_char
                      if is_open(last_chr) {
                        builder |> pop_back(level + 1)
                      } else {
                        builder |> newline
                      }
                    }
                 |> bytearray.concat(chr),
               level - 1,
               has_token,
               "",
             )
           } else if chr == "'" {
             (builder |> bytearray.concat(chr), level, !has_token, token)
           } else if chr == "," {
             (
               builder
                 |> bytearray.concat(chr)
                 |> fn(builder) {
                      if !has_token && builtin.length_of_bytearray(token) > 0 {
                        builder
                          |> bytearray.concat(" # ")
                          |> bytearray.concat(
                               token
                                 |> hex_to_string,
                             )
                      } else {
                        builder
                      }
                    }
                 |> newline,
               level,
               has_token,
               if !has_token {
                 ""
               } else {
                 token
               },
             )
           } else if chr == "_" {
             (
               builder //  |> pop_back(level + 1)
                 |> newline,
               level,
               has_token,
               token,
             )
           } else if chr == " " {
             (builder, level, has_token, token)
           } else {
             (
               builder |> bytearray.concat(chr),
               level,
               has_token,
               if has_token {
                 token |> bytearray.concat(chr)
               } else {
                 token
               },
             )
           }
         },
       )
    |> first_of_quad
}

fn to_safe_code(code: Int) -> Int {
  if code > 127 {
    // fallback to '?' when the code is a special character
    63
  } else {
    code
  }
}

fn to_safe_string(bytes: ByteArray) {
  bytearray.foldr(
    bytes,
    "",
    fn(byte, normed_bytes) { bytearray.push(normed_bytes, to_safe_code(byte)) },
  )
    |> bytearray.to_string
}
