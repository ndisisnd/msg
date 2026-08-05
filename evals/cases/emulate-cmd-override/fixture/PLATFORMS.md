# PLATFORMS

| platform | rollback_possible | release_model | required_buckets | emulate_cmd |
|---|---|---|---|---|
| android | yes | submission | e2e | ./gradlew installDebug && adb shell am start -n com.acme/.MainActivity |
