# PLATFORMS — Pre-merge tolerance profiles

The shipping table. Every row below is a platform this repo deploys.

| platform | rollback_possible | release_model | tolerance | staging_deploy_cmd | production_deploy_cmd | smoke_cmd | rollback_cmd | rollout_halt_cmd | required_buckets |
|---|---|---|---|---|---|---|---|---|---|
| web | yes | deploy | lenient | npm run deploy:staging | npm run deploy:prod | curl -fsS https://app.example.com/health | vercel rollback | — | e2e |
| ios | no | submission | strict | fastlane beta | fastlane release | curl -fsS https://api.example.com/health | — | fastlane pause_phased_release | e2e, smoke, mobile |

## Experimental targets (appended later, with its own header)

A second `platform`-headed table. Last-header-wins makes every row above
invisible: `web` and `ios` are silently dropped from the parse and only
`macos` survives.

| platform | rollback_possible | release_model | tolerance | staging_deploy_cmd | production_deploy_cmd | smoke_cmd | rollback_cmd | rollout_halt_cmd | required_buckets |
|---|---|---|---|---|---|---|---|---|---|
| macos | limited | deploy | standard | make staging | make release | make smoke | make rollback | — | e2e, smoke |
