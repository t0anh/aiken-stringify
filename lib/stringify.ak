use aiken/bytearray
use aiken/cbor
use aiken/dict
use aiken/list
use aiken/string
use aiken/transaction.{
  Datum, InlineDatum, Input, Mint, NoDatum, Output, OutputReference, Spend,
  Transaction, TransactionId,
}
use aiken/transaction/credential.{
  Address, Credential, Inline, ScriptCredential, StakeCredential,
  VerificationKeyCredential,
}
use aiken/transaction/value.{MintedValue,
  Value, flatten, from_minted_value} as value_utils
use utils.{format_cbor, is_close, is_open, to_bytearray}

pub fn int(val) -> String {
  string.from_int(val)
}

fn credential(cred: Credential) -> String {
  when cred is {
    VerificationKeyCredential(hash) ->
      string.concat(
        @"VerificationKeyCredential(",
        string.from_bytearray(hash) |> with_single_quotes,
      )
        |> string.concat(@")")
    ScriptCredential(hash) ->
      string.concat(
        @"ScriptCredential(",
        string.from_bytearray(hash) |> with_single_quotes,
      )
        |> string.concat(@")")
  }
    |> indent
}

pub fn stake_credential(self: Option<StakeCredential>) {
  when self is {
    None -> @"None"
    Some(Inline(cred)) -> credential(cred)
    _ -> fail @"Unsupported type of stake credential"
  }
    |> indent
}

pub fn out_ref(self: OutputReference) {
  let OutputReference(TransactionId(tx_hash), index) = self
  @"OutputReference(TransactionId({}), {})"
    |> apply_params(
         [
           string.from_bytearray(tx_hash) |> with_single_quotes,
           string.from_int(index),
         ],
       )
    |> indent
}

pub fn address(self: Address) {
  @"Address {\npayment_credential: {},\nstake_credential: {},\n}"
    |> apply_params(
         [
           credential(self.payment_credential),
           stake_credential(self.stake_credential),
         ],
       )
    |> indent
}

pub fn value(self: Value) {
  [@"Value(", @")"]
    |> string.join(
         self
           |> flatten
           |> list.map(fn(asset) { asset |> cbor.diagnostic |> format_cbor })
           |> string.join(@","),
       )
    |> indent
}

pub fn minted_value(self: MintedValue) {
  value(from_minted_value(self))
}

pub fn data(self: Data) {
  cbor.diagnostic(self) |> format_cbor
}

pub fn datum(self: Datum) {
  when self is {
    NoDatum -> @"NoDatum"
    InlineDatum(dtm) ->
      @"InlineDatum({})"
        |> apply_params([cbor.diagnostic(dtm) |> format_cbor])
    _ -> fail @"unsupported datum"
  }
}

pub fn output(self: Output) {
  @"Output {\naddress: {},\nvalue: {},\ndatum: {}\n}"
    |> apply_params([address(self.address), value(self.value), datum(self.datum)])
    |> indent
}

pub fn input(self: Input) {
  @"Input {\noutput_reference: {},\noutput: {}\n}"
    |> apply_params([out_ref(self.output_reference), output(self.output)])
    |> indent
}

pub fn tx(self: Transaction) {
  @"Transaction {\nredeemers: {},\nextra_signatories: {},\nmint: {},\nreference_inputs: {},\ninputs: {},\noutputs: {},\n}"
    |> apply_params(
         [
           list.map(
             dict.keys(self.redeemers),
             fn(purpose) {
               @"Purpose"
                 |> string.concat(
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
                        _ -> @"<TBD>"
                      }
                        |> with_parentheses,
                    )
             },
           )
             |> string.join(
                  @",\n",
                )
             |> as_block
             |> with_square_brackets,
           self.extra_signatories
             |> list.map(
                  fn(sig) {
                    string.from_bytearray(sig)
                      |> with_single_quotes
                  },
                )
             |> string.join(@", ")
             |> with_square_brackets,
           minted_value(self.mint),
           when self.reference_inputs is {
             [] -> @"[]"
             _ ->
               list.map(self.reference_inputs, fn(inp) { input(inp) })
                 |> string.join(
                      @",\n",
                    )
                 |> as_block
                 |> with_square_brackets
           },
           when self.inputs is {
             [] -> @"[]"
             _ ->
               list.map(self.inputs, fn(inp) { input(inp) })
                 |> string.join(
                      @",\n",
                    )
                 |> as_block
                 |> with_square_brackets
           },
           when self.outputs is {
             [] -> @"[]"
             _ ->
               list.map(self.outputs, fn(out) { output(out) })
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

// ==========private fn============
fn tab(lvl: Int) {
  list.repeat(@"  ", lvl) |> string.join(@"")
}

pub fn indent(str: String) {
  do_indent(string.to_bytearray(str), 0) |> bytearray.to_string
}

pub fn log(self: a, serializer: fn(a) -> String) {
  trace serializer(self)
  self
}

fn do_indent(bytes: ByteArray, lvl: Int) {
  let next_newline_cursor = bytearray.index_of(bytes, "\n")
  when next_newline_cursor is {
    Some((_, cursor)) -> {
      let left = bytearray.take(bytes, cursor)
      let right = bytearray.drop(bytes, cursor + 1)
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
