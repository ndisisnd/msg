# PLATFORMS — Pre-merge tolerance profiles

`template-PLATFORMS.md` invites custom rows ("add your own row for anything
else"), so this file declares one. The resolver's known-platform set is
hardcoded, so `desktop`'s checks are scheduled by nobody and it raises no
coverage gap — silently, before A19.

The `—` row and the `[USER: …]` row are the exempt cell markers: they mean
"not configured", not "an unknown platform".

## Tolerance profiles (a second, unrelated table — must never warn)

| Profile | Buckets |
|---|---|
| strict | all |
| lenient | e2e |

## The platform table

| platform | rollback_possible | release_model | tolerance | required_buckets |
|---|---|---|---|---|
| web | yes | deploy | lenient | e2e |
| desktop | limited | deploy | standard | e2e, smoke |
| — | — | — | — | — |
| [USER: name the platform] | | | | |
| server | yes | deploy | standard | api |
