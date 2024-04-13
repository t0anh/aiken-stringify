use aiken/bytearray
use aiken/cbor
use aiken/dict
use aiken/string
use aiken/transaction.{
  InlineDatum, Input, Mint, NoDatum, Output, OutputReference, ScriptPurpose,
  Spend, Transaction, TransactionId,
}
use aiken/transaction/credential.{
  Address, Inline, ScriptCredential, VerificationKeyCredential,
}
use aiken/transaction/value
use debug

test log_int() {
  1 |> debug.int(@"int")
  True
}

test log_value() {
  value.from_lovelace(111_000_000)
    |> value.add("pid", "name", 1)
    |> debug.value(@"value")
  True
}

test log_input() {
  Input {
    output_reference: OutputReference(TransactionId("tx_0"), 0),
    output: Output {
      value: value.from_lovelace(111_000_000) |> value.add("pid", "name", 1),
      address: Address {
        payment_credential: ScriptCredential("script_hash"),
        stake_credential: None,
      },
      datum: NoDatum,
      reference_script: None,
    },
  }
    |> debug.input(@"input")
  True
}

test log_output() {
  Output {
    value: value.from_lovelace(111_000_000) |> value.add("pid", "name", 1),
    address: Address {
      payment_credential: ScriptCredential("script_hash"),
      stake_credential: None,
    },
    datum: NoDatum,
    reference_script: None,
  }
    |> debug.output(@"output")
  True
}

type MyDatum {
  bytes: ByteArray,
  int: Int,
  str: String,
  int_list: List<Int>,
  bytes_list: List<ByteArray>,
}

test log_output_2() {
  Output {
    value: value.from_lovelace(111_000_000) |> value.add("pid", "name", 1),
    address: Address {
      payment_credential: ScriptCredential("script_hash"),
      stake_credential: None,
    },
    datum: InlineDatum(
      MyDatum {
        bytes: "bytes",
        int: 1,
        str: @"str",
        int_list: [1, 2, 3, 4],
        bytes_list: ["1", "2", "3"],
      },
    ),
    reference_script: None,
  }
    |> debug.output(@"output with datum")
  True
}

test log_data() {
  MyDatum {
    bytes: "bytes",
    int: 1,
    str: @"str",
    int_list: [1, 2, 3, 4],
    bytes_list: ["1", "2", "3"],
  }
    |> debug.data(@"data")
  True
}

fn script_purpose_compare(a: ScriptPurpose, b: ScriptPurpose) {
  bytearray.compare(
    a |> cbor.diagnostic |> string.to_bytearray,
    b |> cbor.diagnostic |> string.to_bytearray,
  )
}

test log_tx() {
  let t = transaction.placeholder()
  Transaction {
    ..t,
    redeemers: t.redeemers
      |> dict.insert(
          Spend(OutputReference(TransactionId("tx_1"), 12)),
          Void,
          script_purpose_compare,
        )
      |> dict.insert(
          Mint("policy"),
          MyDatum {
            bytes: "bytes",
            int: 1,
            str: @"str",
            int_list: [1, 2, 3, 4],
            bytes_list: ["1", "2", "3"],
          },
          script_purpose_compare,
        ),
    extra_signatories: ["sig1", "sig2"],
    mint: value.from_asset("policy_id", "asset_name", 112)
      |> value.add("policy_id", "asset_name_2", 1)
      |> value.to_minted_value,
    inputs: [
      Input {
        output_reference: OutputReference(TransactionId("tx_1"), 12),
        output: Output {
          value: value.from_lovelace(2_000_000),
          address: Address {
            payment_credential: VerificationKeyCredential("public_key"),
            stake_credential: Some(
              Inline(VerificationKeyCredential("stake_key")),
            ),
          },
          datum: NoDatum,
          reference_script: None,
        },
      },
    ],
    outputs: [
      Output {
        value: value.from_lovelace(111_000_000) |> value.add("pid", "name", 1),
        address: Address {
          payment_credential: ScriptCredential("script_hash"),
          stake_credential: None,
        },
        datum: InlineDatum(
          MyDatum {
            bytes: "bytes",
            int: 1,
            str: @"str",
            int_list: [1, 2, 3, 4],
            bytes_list: ["1", "2", "3"],
          },
        ),
        reference_script: None,
      },
      Output {
        value: value.from_lovelace(2_000_000),
        address: Address {
          payment_credential: VerificationKeyCredential("public_key"),
          stake_credential: Some(Inline(VerificationKeyCredential("stake_key"))),
        },
        datum: NoDatum,
        reference_script: None,
      },
    ],
  }
    |> debug.tx
  True
}

test any_1() {
  1 |> debug.data(@"int")
  None |> debug.data(@"None")
  Some(1) |> debug.data(@"Some(1)")
  value.from_lovelace(123_456)
    |> value.add("pid", "name", -1)
    |> value.to_dict
    |> debug.data(@"Dict")
  (1, 2, [1, 2, 3]) |> debug.data(@"Tuple")
  [1, 2, 3] |> debug.data(@"List")
  True
}

test bytearray_1() {
  "627974656172726179" |> debug.bytearray(@"ByteArray")
  True
}

test bytearray_2() {
  #"fab2208123" |> debug.bytearray(@"ByteArray")
  True
}
