//// smallest practical demo of supervior use

import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/otp/supervision

pub fn main() {
  let worker_name = process.new_name("worker1")
  let user_name = process.new_name("user1")

  // worker
  let worker_child_spec =
    supervision.worker(run: fn() { start_worker_actor(worker_name) }// yeah, a little anonymous closure here to capture the worker_name
    // could have had all the start_worker_actor() code right in that run: function but it looked bad
    )

  let _worker_supervisor =
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.add(worker_child_spec)
    |> static_supervisor.start

  // user
  let user_child_spec =
    supervision.worker(run: fn() { start_user_actor(user_name, worker_name) }// gets both names
    )
  let _user_supervisor =
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.add(user_child_spec)
    |> static_supervisor.start

  // nothing more for main to do
  process.sleep_forever()
}

// ---- worker actor things ----
pub type WorkerMessage {
  Add
  Get(Subject(Int))
  // yeah, this is a mind-bender
}

fn start_worker_actor(name) {
  echo "worker actor starting"
  let assert Ok(_actor) =
    actor.new(0)
    // 0 is the initial state state is simply an int for this Actor
    |> actor.named(name)
    |> actor.on_message(worker_handle_message)
    |> actor.start
}

pub fn worker_handle_message(
  state: Int,
  message: WorkerMessage,
) -> actor.Next(Int, WorkerMessage) {
  case message {
    Add -> {
      let state = state + 1
      case state {
        3 -> panic as "worker actor crashing"
        _ -> Nil
      }
      actor.continue(state)
      // this gets the new state from the 'let' above
    }
    Get(reply) -> {
      actor.send(reply, state)
      actor.continue(state)
    }
  }
}

/// this worker counts up as you add numbers and crashes at 3
// the original function I wanted running in a process...

fn user_cycle(worker_name) {
  let worker_subj = process.named_subject(worker_name)
  actor.send(worker_subj, Add)
  let answer = actor.call(worker_subj, waiting: 100, sending: Get)
  // Get is a constructor function!  call is clever.
  echo "user cycle got " <> int.to_string(answer)
  process.sleep(1000)
  user_cycle(worker_name)
  // tail-call recursive loop...
}

// ---- user actor things ----
pub type UserMessage {
  Start
}

fn user_handle_message(state, msg) {
  case msg {
    Start -> {
      user_cycle(state)
      // never ends
    }
  }
}

fn start_user_actor(user_name, worker_name) {
  echo "user actor starting"
  let assert Ok(user_actor) =
    actor.new(worker_name)
    // pass the *worker_name* as the state
    |> actor.named(user_name)
    |> actor.on_message(user_handle_message)
    |> actor.start
  actor.send(user_actor.data, Start)
  // start the loop, and since the subject is right here use it not the named one
  Ok(user_actor)
  // need to return this
}
