# 아이폰 AI(Apple 온디바이스 모델) 품질 테스트

맥(macOS 26 이상, Apple Intelligence 켜짐)에서 아이폰과 같은 Apple 온디바이스 모델로 대표 6개 케이스를 돌립니다.
프롬프트·후보 구절은 Claude 테스트(prompt.mjs, verses.mjs)와 똑같이 씁니다.

```bash
node --input-type=module -e '...' # inputs.json 만들기 (아래 예시 참고)
swiftc -parse-as-library -O ondevice/run.swift -o /tmp/fmrun
/tmp/fmrun inputs.json out.json
```

inputs.json 형식: `{ "system": SYSTEM_PROMPT, "cases": [{ "id", "mode", "input", "user": buildUserMessage(...) }] }`
