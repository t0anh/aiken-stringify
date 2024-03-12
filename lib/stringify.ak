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
use utils.{format_cbor}

pub fn int(val) -> String {
  string.from_int(val)
}

fn credential(cred: Credential) -> String {
  when cred is {
    VerificationKeyCredential(hash) ->
      string.concat(
        @"VerificationKeyCredential(",
        string.from_bytearray(hash) |> with_single_quote_surrounded,
      )
        |> string.concat(@")")
    ScriptCredential(hash) ->
      string.concat(
        @"ScriptCredential(",
        string.from_bytearray(hash) |> with_single_quote_surrounded,
      )
        |> string.concat(@")")
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
  let OutputReference(TransactionId(tx_hash), index) = self
  @"OutputReference(TransactionId({}), {})"
    |> apply_params(
         [
           string.from_bytearray(tx_hash) |> with_single_quote_surrounded,
           string.from_int(index),
         ],
       )
}

pub fn address(self: Address) {
  @"Address {\n\tpayment_credential: {},\n\tstake_credential: {},\n}"
    |> apply_params(
         [
           credential(self.payment_credential),
           stake_credential(self.stake_credential),
         ],
       )
    |> with_indent(1)
}

pub fn value(self: Value) {
  [@"Value(", @")"]
    |> string.join(
         self
           |> flatten
           |> list.map(fn(asset) { asset |> cbor.diagnostic |> format_cbor })
           |> string.join(@","),
       )
    |> with_indent(1)
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
    |> apply_params(
         [
           address(self.address) |> with_indent(1),
           value(self.value) |> with_indent(1),
           datum(self.datum) |> with_indent(1),
         ],
       )
    |> with_indent(1)
}

pub fn input(self: Input) {
  @"Input {\noutput_reference: {},\noutput: {}\n}"
    |> apply_params(
         [
           out_ref(self.output_reference) |> with_indent(1),
           output(self.output) |> with_indent(1),
         ],
       )
    |> with_indent(1)
}

pub fn tx(self: Transaction) {
  @"Transaction {\n\tredeemers: {},\n\textra_signatories: {},\n\tmint: {},\n\treference_inputs: {},\n\tinputs: {},\n\toutputs: {},\n}"
    |> apply_params(
         [
           [
             @"[",
             @"\n\t]",
           ]
             |> string.join(
                  dict.foldr(
                    self.redeemers,
                    @"",
                    fn(purpose, _datum, builder) {
                      string.concat(
                        builder,
                        when purpose is {
                          Spend(ref) ->
                            [
                              @"\nSpend(", @"),",
                            ]
                              |> string.join(out_ref(ref))
                          Mint(pid) ->
                            [
                              @"\nMint(", @"),",
                            ]
                              |> string.join(
                                   string.from_bytearray(pid)
                                     |> with_single_quote_surrounded,
                                 )
                          _ -> @"<TBD>"
                        }
                          |> with_indent(2),
                      )
                    },
                  ),
                ),
           [@"[", @"]"]
             |> string.join(
                  self.extra_signatories
                    |> list.map(
                         fn(sig) {
                           string.from_bytearray(sig)
                             |> with_single_quote_surrounded
                         },
                       )
                    |> string.join(@", "),
                ),
           minted_value(self.mint) |> with_indent(1),
           when self.reference_inputs is {
             [] -> @"[]"
             _ ->
               @"[\n"
                 |> string.concat(
                      list.map(self.reference_inputs, fn(inp) { input(inp) })
                        |> string.join(
                             @",\n",
                           ),
                    )
                 |> string.concat(
                      @"\n]",
                    )
           },
           when self.inputs is {
             [] -> @"[]"
             _ ->
               [
                 @"[\n",
                 @"\n]",
               ]
                 |> string.join(
                      list.map(self.inputs, fn(inp) { input(inp) })
                        |> string.join(
                             @",\n",
                           ),
                    )
                 |> with_indent(1)
           },
           when self.outputs is {
             [] -> @"[]"
             _ ->
               [
                 @"[\n",
                 @"\n]",
               ]
                 |> string.join(
                      list.map(self.outputs, fn(out) { output(out) })
                        |> string.join(
                             @",\n",
                           ),
                    )
                 |> with_indent(1)
           },
         ],
       )
    |> with_indent(1)
}

// ==========private fn============
fn indent(lvl: Int) {
  list.repeat(@"\t", lvl) |> string.join(@"")
}

pub fn with_indent(str: String, lvl: Int) {
  do_with_indent(string.to_bytearray(str), lvl) |> bytearray.to_string
}

fn do_with_indent(bytes: ByteArray, lvl: Int) {
  when bytearray.index_of(bytes, "\n") is {
    Some((_from, to)) ->
      bytearray.slice(bytes, 0, to)
        |> bytearray.concat(
             indent(lvl)
               |> bytearray.from_string,
           )
        |> bytearray.concat(bytes |> bytearray.drop(to + 1) |> do_with_indent(lvl))
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

fn with_single_quote_surrounded(builder: String) {
  [@"'", @"'"] |> string.join(builder)
}
