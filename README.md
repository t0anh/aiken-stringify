# Aiken Stringify

Converting anything to a String

## Motivation

Debugging in Aiken is not a happy part, because the only way to log a value is converting it to a `String` and then passing it to a `trace`. For example:

```aiken
trace @"here" // directly from a string
trace string.from_int(my_int) // convert to string
trace cbor.diagnostic(any_value) // diagnostic the value
```

The `cbor.diagnostic` helper works well, but not really readable for many cases, specially with encoded data. So this is why this library was born. For example, let's debug an output:

- With `cbor.diagnostic`:

```aiken
let input = Input {
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
trace cbor.diagnostic(input)
```

We get:

```shell
121([_ 121([_ 121([_ h'74785F30']), 0]), 121([_ 121([_ 122([_ h'7363726970745F68617368']), 122([])]), {_ h'': {_ h'': 111000000 }, h'706964': {_ h'6E616D65': 1 } }, 121([]), 122([])])])
```

- With `stringify.input`

```aiken
// ...
trace stringify.input(input)
```

We get:

```bash
Input {
     output_reference: OutputReference(TransactionId(tx_0), 0),
     output: Output {
       address: Address {
         payment_credential: ScriptCredential('script_hash')
         stake_credential: None
       },
       value: Value ([
           h'',
           h'',
           111000000
       ],[
           h'706964', # pid
           h'6E616D65', # name
           1
       ]),
       datum: NoDatum
    }
}
```

## Usage

More handy when wrapped by a custom logger. For example:

```aiken
fn log(self: a, serializer: fn(a) -> String) {
  trace serializer(self)
  self
}
```

So we can attach it to anywhere like this:

```diff
Input {
  output_reference: OutputReference(TransactionId(tx_0), 0),
  output: Output {
    address: Address {
      payment_credential: ScriptCredential('script_hash')
      stake_credential: None
    },
    value: Value ([
        h'',
        h'',
        111000000
    ],[
        h'706964', # pid
        h'6E616D65', # name
        1
    ]),
    datum: NoDatum
  }
}
+ |> log(stringify.input)
```

## Supported serializers

- [x] input
- [x] output
- [x] credential
- [x] value
- [x] minted_value
- [x] data
- [x] out_ref
- [x] tx
- [x] redeemers

## License

MIT
