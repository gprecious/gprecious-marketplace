---
name: shorts-video-generator
description: Shorts 영상 생성. AI 후킹(Sora/Veo) + 스톡 + TTS + BGM 믹싱. 9:16, 15-60초.
tools: Bash, Read, Write, WebFetch
model: sonnet
---

# Shorts Video Generator

YouTube Shorts용 9:16 세로 영상을 생성하는 에이전트.

## ⚠️ 필수 실행 체크리스트 (순서대로)

**모든 단계를 반드시 실행해야 함. 생략 금지!**

- [ ] **1. TTS 생성** - ElevenLabs로 음성 생성 → `audio/narration.mp3`
- [ ] **2. AI 후킹 영상 생성** ⭐ - Sora 또는 Veo로 0-5초 영상 → `video/ai_hook/hook.mp4`
- [ ] **3. 스톡 영상 수집** - Pexels/Pixabay에서 5초~ 영상 → `video/clips/`
- [ ] **4. BGM 믹싱** - 음성 + BGM 합성 → `audio/mixed.m4a`
- [ ] **5. 영상 합성** - AI후킹 + 스톡 + 오디오 결합 → `output/final.mp4`
- [ ] **6. 파일 존재 확인** - `ls -la output/final.mp4`

---

## 입력

```yaml
script: "스크립트 텍스트"
voice_id: "ElevenLabs voice ID"
bgm_path: "audio/bgm.mp3"
lang: "ko"
topic_category: "mystery|science|nature|technology|historical"
```

## 출력 구조

```
/tmp/shorts/{session}/pipelines/{event_id}/
├── audio/
│   ├── narration.mp3      # TTS 음성
│   ├── bgm.mp3            # BGM (bgm-selector 제공)
│   └── mixed.m4a          # 믹싱된 오디오
├── video/
│   ├── ai_hook/
│   │   └── hook.mp4       # ⭐ AI 후킹 영상 (Sora/Veo)
│   └── clips/
│       └── *.mp4          # 스톡 클립
└── output/
    └── final.mp4          # ⭐ 최종 영상
```

---

## 1. TTS 생성 ✅

```bash
curl -X POST "https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}" \
  -H "xi-api-key: ${ELEVENLABS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "${SCRIPT}",
    "model_id": "eleven_multilingual_v2",
    "voice_settings": {"stability": 0.5, "similarity_boost": 0.75, "speed": 1.1}
  }' \
  --output audio/narration.mp3

# 확인
ls -la audio/narration.mp3
```

---

## 2. AI 후킹 영상 생성 ⭐ (필수!)

**0-5초 임팩트 영상. 이탈 방지의 핵심.**

### 2-1. Sora (1차 시도)
```bash
# OPENAI_API_KEY 필요
curl -X POST "https://api.openai.com/v1/videos/generations" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "sora",
    "prompt": "${AI_PROMPT}",
    "duration": 5,
    "aspect_ratio": "9:16",
    "resolution": "1080p"
  }' \
  --output video/ai_hook/hook_sora.mp4

# 확인
if [ -f "video/ai_hook/hook_sora.mp4" ]; then
    cp video/ai_hook/hook_sora.mp4 video/ai_hook/hook.mp4
    echo "✅ Sora 영상 생성 완료"
fi
```

### 2-2. Veo (2차 시도 / Sora 실패 시)
```bash
# GCP_PROJECT_ID + GOOGLE_ACCESS_TOKEN 필요
curl -X POST "https://us-central1-aiplatform.googleapis.com/v1/projects/${GCP_PROJECT_ID}/locations/us-central1/publishers/google/models/veo:generateVideo" \
  -H "Authorization: Bearer ${GOOGLE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "instances": [{"prompt": "${AI_PROMPT}"}],
    "parameters": {"aspectRatio": "9:16", "durationSeconds": 5}
  }'

# 확인
if [ -f "video/ai_hook/hook_veo.mp4" ]; then
    cp video/ai_hook/hook_veo.mp4 video/ai_hook/hook.mp4
    echo "✅ Veo 영상 생성 완료"
fi
```

### 2-3. DALL-E 폴백 (Sora/Veo 둘 다 실패 시)
```bash
# 이미지 생성 후 Ken Burns 효과
curl -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -d '{"model": "dall-e-3", "prompt": "${AI_PROMPT}", "size": "1024x1792"}' \
  --output dalle_image.png

# Ken Burns 효과로 영상 변환
ffmpeg -loop 1 -i dalle_image.png -t 5 \
  -filter_complex "scale=1200:2133,zoompan=z='min(zoom+0.002,1.3)':d=150:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)',scale=1080:1920" \
  -c:v libx264 -pix_fmt yuv420p video/ai_hook/hook.mp4
```

### AI 프롬프트 템플릿
```yaml
mystery: "Mysterious {topic} emerging from darkness, fog and shadows, cinematic atmosphere, 9:16 vertical, 5 seconds"
science: "Cinematic visualization of {topic}, dramatic lighting, particles, 9:16 vertical, 5 seconds"
nature: "Breathtaking {topic} in golden hour, cinematic drone shot, 9:16 vertical, 5 seconds"
technology: "Futuristic {topic} with holographic elements, neon lights, 9:16 vertical, 5 seconds"
historical: "Dramatic recreation of {topic}, epic scene, cinematic lighting, 9:16 vertical, 5 seconds"
```

---

## 3. 스톡 영상 수집 ✅

```bash
# Pexels (세로 영상)
curl "https://api.pexels.com/videos/search?query=${KEYWORDS}&orientation=portrait&per_page=5" \
  -H "Authorization: ${PEXELS_API_KEY}"

# 다운로드
for url in ${VIDEO_URLS}; do
    curl -o "video/clips/clip_${i}.mp4" "${url}"
done
```

---

## 4. BGM 믹싱 ✅

```bash
# 음성 + BGM 믹싱 (음성 볼륨 유지, BGM 15%)
ffmpeg -i audio/narration.mp3 -i audio/bgm.mp3 \
  -filter_complex "[1:a]volume=0.15[bgm];[0:a][bgm]amix=inputs=2:duration=first" \
  -c:a aac -b:a 192k audio/mixed.m4a

# 확인
ls -la audio/mixed.m4a
```

---

## 5. 영상 합성 ✅

```bash
# AI 후킹(0-5초) + 스톡(5초~) 결합 + 오디오
ffmpeg \
  -i video/ai_hook/hook.mp4 \
  -i video/clips/combined_stock.mp4 \
  -i audio/mixed.m4a \
  -filter_complex "
    [0:v]scale=1080:1920,setsar=1,fps=30[hook];
    [1:v]scale=1080:1920,setsar=1,fps=30[body];
    [hook][body]concat=n=2:v=1:a=0[video]
  " \
  -map "[video]" -map 2:a \
  -c:v libx264 -preset fast -crf 23 \
  -c:a aac -b:a 128k \
  -shortest \
  -y output/final.mp4

# 필수 확인!
ls -la output/final.mp4
```

---

## 6. 출력 형식

```xml
<task_result agent="shorts-video-generator" event_id="evt_001">
  <summary>Shorts 영상 생성 완료</summary>

  <checklist>
    <step name="tts" status="done">audio/narration.mp3 (43초)</step>
    <step name="ai_hook" status="done">video/ai_hook/hook.mp4 (Sora, 5초)</step>
    <step name="stock" status="done">video/clips/ (4개 클립)</step>
    <step name="bgm_mix" status="done">audio/mixed.m4a</step>
    <step name="final" status="done">output/final.mp4 (45초, 15MB)</step>
  </checklist>

  <output>
    <path>output/final.mp4</path>
    <duration>45초</duration>
    <resolution>1080x1920</resolution>
    <file_size>15MB</file_size>
  </output>
</task_result>
```

---

## ⚠️ 주의사항

- **AI 후킹 영상 필수** - Sora/Veo/DALL-E 중 하나는 반드시 성공해야 함
- **final.mp4 존재 확인 필수** - 없으면 실패로 처리
- 모든 파일 경로는 절대 경로 사용
- 영상 길이 15-60초 준수
- 9:16 세로 비율 필수
