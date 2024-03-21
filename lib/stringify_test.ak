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
  ( 1 |> debug.int(@"int") ) == 1
}

test log_value() {
  let my_value =
    value.from_lovelace(111_000_000)
      |> value.add("pid", "name", 1)
  (
    my_value
      |> debug.value(@"value")
  ) == my_value
}

test log_input() {
  let my_input =
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
  (
    my_input
      |> debug.input(@"input")
  ) == my_input
}

test log_output() {
  let my_output =
    Output {
      value: value.from_lovelace(111_000_000) |> value.add("pid", "name", 1),
      address: Address {
        payment_credential: ScriptCredential("script_hash"),
        stake_credential: None,
      },
      datum: NoDatum,
      reference_script: None,
    }
  ( my_output |> debug.output(@"output") ) == my_output
}

type MyDatum {
  bytes: ByteArray,
  int: Int,
  str: String,
  int_list: List<Int>,
  bytes_list: List<ByteArray>,
}

test log_output_2() {
  let my_output =
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
  ( my_output |> debug.output(@"output with datum") ) == my_output
}

test log_data() {
  let struct =
    MyDatum {
      bytes: "bytes",
      int: 1,
      str: @"str",
      int_list: [1, 2, 3, 4],
      bytes_list: ["1", "2", "3"],
    }
  (
    struct
      |> debug.diagnostic(@"data", cbor.diagnostic(struct))
  ) == struct
}

fn script_purpose_compare(a: ScriptPurpose, b: ScriptPurpose) {
  bytearray.compare(
    a |> cbor.diagnostic |> string.to_bytearray,
    b |> cbor.diagnostic |> string.to_bytearray,
  )
}

test log_tx() {
  let t = transaction.placeholder()
  let tx =
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
            stake_credential: Some(
              Inline(VerificationKeyCredential("stake_key")),
            ),
          },
          datum: NoDatum,
          reference_script: None,
        },
      ],
    }
  ( tx |> debug.tx ) == tx
}
