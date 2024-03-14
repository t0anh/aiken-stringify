use aiken/builtin
use aiken/bytearray
use aiken/list

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
    chr == "(",
  }
}

pub fn is_close(chr: ByteArray) {
  or {
    chr == "]",
    chr == "}",
    chr == ")",
  }
}

fn indent(self: ByteArray, level: Int) {
  self
    |> bytearray.concat(
         list.repeat("\t", level)
           |> list.reduce("", bytearray.concat),
       )
}

pub fn newline(self: ByteArray, indent_lvl: Int) {
  self |> bytearray.concat("\n") |> indent(indent_lvl)
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

pub fn format_cbor(cbr: String) {
  cbr |> bytearray.from_string |> do_format_cbor |> bytearray.to_string
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
                 |> bytearray.concat(chr)
                 |> newline(level + 1),
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
                        builder |> newline(level - 1)
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
                 |> newline(level),
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
               builder
                 |> pop_back(level + 1)
                 |> newline(level),
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

pub fn to_safe_code(code: Int) -> Int {
  if code > 127 {
    // fallback to '?' when the code is a special character
    63
  } else {
    code
  }
}
