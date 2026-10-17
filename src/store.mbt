///|
/// `createStore` decisions. The host keeps the map, the pristine set, and listeners.
fn store_field(value : Json, key : String) -> Json? {
  match value {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn store_flag(value : Json, key : String) -> Bool {
  match store_field(value, key) {
    Some(True) => true
    _ => false
  }
}

///|
fn store_text(value : Json, key : String) -> String {
  match store_field(value, key) {
    Some(String(text)) => text
    _ => ""
  }
}

///|
fn store_count(value : Json, key : String) -> Double {
  match store_field(value, key) {
    Some(Number(number, ..)) => number
    _ => -1.0
  }
}

///|
fn store_eq(value : Json) -> Array[Bool] {
  match store_field(value, "eq") {
    Some(Array(items)) => {
      let flags : Array[Bool] = []
      for item in items {
        flags.push(
          match item {
            True => true
            _ => false
          },
        )
      }
      flags
    }
    _ => []
  }
}

///|
fn store_all(flags : Array[Bool]) -> Bool {
  let mut index = 0
  while index < flags.length() {
    if !flags[index] {
      return false
    }
    index = index + 1
  }
  true
}

///|
/// `keep` when `set` should leave the stored value in place.
pub fn store_keep(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    if store_flag(payload, "same") {
      "{\"op\":\"keep\"}"
    } else if !store_flag(payload, "plain") {
      "{\"op\":\"write\"}"
    } else {
      let width = store_count(payload, "n")
      let other = store_count(payload, "o")
      let flags = store_eq(payload)
      if width == other &&
        width == flags.length().to_double() &&
        store_all(flags) {
        "{\"op\":\"keep\"}"
      } else {
        "{\"op\":\"write\"}"
      }
    }
  } catch {
    _ => "{\"op\":\"write\"}"
  }
}

///|
/// One `initialize` key. `insert` adds a pristine default, `replace` overwrites, `write` stores persisted data.
pub fn store_init(payload_json : String) -> String {
  try {
    let payload = @json.parse(payload_json)
    match store_text(payload, "phase") {
      "persisted" =>
        if !store_flag(payload, "has") || !store_flag(payload, "same") {
          "{\"op\":\"write\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      "defaults" =>
        if !store_flag(payload, "has") {
          "{\"op\":\"insert\"}"
        } else if store_flag(payload, "pristine") &&
          !store_flag(payload, "same") {
          "{\"op\":\"replace\"}"
        } else {
          "{\"op\":\"skip\"}"
        }
      _ => "{\"op\":\"skip\"}"
    }
  } catch {
    _ => "{\"op\":\"skip\"}"
  }
}
