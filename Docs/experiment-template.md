# Tower behavior experiment record

Copy this file for one feature/action after rights and live-access gates are satisfied. Keep raw recordings and sensitive data outside the GitDesk repository. An unrun template is not evidence.

```yaml
record_id: T18-0000
matrix_id: WC-00
status: planned # planned | run | reproduced | inconclusive | blocked
evidence_level: documented # documented | observed | inferred
target:
  tower_version: '18.0'
  tower_build: '564'
  executable_sha256: 166e5391e640cbdd3a2885fc2feed6ba050766b89a73f6f42cde80b54d0ef00e
  macos: '27.2 (26B123)'
  architecture: arm64
  entitlement_record: private-reference-only
  analysis_rights_record: private-reference-only
fixture:
  generator_version: ''
  repository_hash: ''
  remote_type: local-bare # or test provider account
  starting_head: ''
  starting_refs: ''
  starting_index_stages: ''
  starting_worktree_hashes: ''
  starting_reflog: ''
  starting_config: ''
action:
  entry_point: '' # menu, toolbar, shortcut, drag, CLI
  exact_steps: []
  options: {}
  cancel_or_error_case: ''
observation:
  ui_before: ''
  ui_after: ''
  git_operations_if_permitted: []
  ref_changes: []
  index_changes: []
  worktree_changes: []
  reflog_changes: []
  config_changes: []
  network_effects_if_permitted: []
  messages_and_recovery: []
  timing_ms: {}
  sanitized_recording: ''
interpretation:
  behavior_spec: ''
  inference_separated_from_observation: ''
  competing_explanations: []
  confidence: low # low | medium | high
  next_discriminating_experiment: ''
gitdesk:
  acceptance_fixture: ''
  result: pending # pending | pass | fail
  relevant_commit: ''
review:
  observer: ''
  reviewer: ''
  date: ''
```

## Procedure

1. Confirm the rights/entitlement record, Tower build hash and disposable fixture. Do not use a personal or work repository.
2. Capture initial Git state from outside Tower. Record sensitive paths and accounts using aliases; never paste credentials or raw private network payloads into this repository.
3. Perform exactly one Tower action. Record UI control, shortcut and option values. If permitted, observe launched Git operations and system effects. Do not attach a debugger or inspect private resources unless the recorded rights scope permits it.
4. Capture the final Git state and UI. Repeat with clean, dirty, failure, cancel and restart cases as relevant. Where results are ambiguous, design the next experiment rather than guessing.
5. Write an independent behavior spec and GitDesk acceptance fixture. Have a reviewer check that copied Tower code/assets and unsupported parity claims did not enter GitDesk.
