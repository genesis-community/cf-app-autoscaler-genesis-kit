[Improvements]

* Added `ocfp` feature which encodes the opensource cloud foundry platform reference architecture. `ocfp` specifies that **inputs for features come from vault**.

  The reference architecture specifies the `network`, `vm_type`, `disk_type`, and `azs` based on `dev` vs `prod` environment scales.

  Naming scheme is entirely based on environment name, and is designed to work with the `ocfp-ops-scripts` `ocfp` cli in order to generate configs, initialize and test environments.

