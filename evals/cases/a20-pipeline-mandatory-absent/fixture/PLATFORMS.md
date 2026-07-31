# PLATFORMS — Pre-merge tolerance profiles

One row per shipping platform. Trimmed to the columns the resolver reads
(`script-pipeline-resolve.py` only ever reads the first column).

| platform | rollback_possible | release_model | tolerance | required_buckets |
|---|---|---|---|---|
| web | yes | deploy | lenient | e2e |
| ios | no | submission | strict | e2e, smoke, mobile |
