import gleam/io
import gleeth/crypto/keccak

/// Compute and display function selector or event topic
pub fn execute(signature: String, is_event: Bool) -> Result(Nil, String) {
  case is_event {
    True -> {
      let topic = keccak.event_topic(signature)
      io.println("Event: " <> signature)
      io.println("Topic: " <> topic)
      Ok(Nil)
    }
    False -> {
      case keccak.function_selector(signature) {
        Ok(selector) -> {
          io.println("Function: " <> signature)
          io.println("Selector: " <> selector)
          Ok(Nil)
        }
        Error(msg) -> Error(msg)
      }
    }
  }
}
