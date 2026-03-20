//! Prompt hooks for observing and controlling agent behavior.

pub mod cortex;
pub mod loop_guard;
pub mod agentspace;

pub use cortex::CortexHook;
pub use loop_guard::{LoopGuard, LoopGuardConfig, LoopGuardVerdict};
pub use agentspace::{AgentspaceHook, ToolNudgePolicy};
