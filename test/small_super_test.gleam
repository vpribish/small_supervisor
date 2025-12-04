import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  let name = "friend"
  let greeting = "Hello, " <> name <> "!"

  assert greeting == "Hello, friend!"
}
