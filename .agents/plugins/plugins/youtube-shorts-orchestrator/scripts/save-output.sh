#!/bin/bash
# 결과물 저장 스크립트
# 사용법: ./save-output.sh <event_id> <session_id> <lang> <channel> <score> <source_dir>

set -e

EVENT_ID="${1:?event_id 필요}"
SESSION_ID="${2:?session_id 필요}"
LANG="${3:-ko}"
CHANNEL="${4:-unknown}"
SCORE="${5:-0}"
SOURCE_DIR="${6:?source_dir 필요}"

DATE=$(date +%Y%m%d)
OUTPUT_DIR="output/${DATE}_${EVENT_ID}"

echo "📁 결과물 저장 시작: ${OUTPUT_DIR}"

# 1. 폴더 생성
mkdir -p "${OUTPUT_DIR}"
mkdir -p "history/uploads" "history/sessions"

# 2. 파일 복사
COPIED=0
MISSING=""

# scenario.json
if [ -f "${SOURCE_DIR}/scenario.json" ]; then
    cp "${SOURCE_DIR}/scenario.json" "${OUTPUT_DIR}/"
    COPIED=$((COPIED + 1))
else
    MISSING="$MISSING scenario.json"
fi

# script.md
if [ -f "${SOURCE_DIR}/script.md" ]; then
    cp "${SOURCE_DIR}/script.md" "${OUTPUT_DIR}/"
    COPIED=$((COPIED + 1))
else
    MISSING="$MISSING script.md"
fi

# script_{lang}.md (선택)
if [ -f "${SOURCE_DIR}/script_${LANG}.md" ]; then
    cp "${SOURCE_DIR}/script_${LANG}.md" "${OUTPUT_DIR}/"
    COPIED=$((COPIED + 1))
fi

# final.mp4 (필수)
FINAL_MP4=""
if [ -f "${SOURCE_DIR}/output/final.mp4" ]; then
    FINAL_MP4="${SOURCE_DIR}/output/final.mp4"
elif [ -f "${SOURCE_DIR}/final.mp4" ]; then
    FINAL_MP4="${SOURCE_DIR}/final.mp4"
fi

if [ -n "$FINAL_MP4" ]; then
    cp "$FINAL_MP4" "${OUTPUT_DIR}/"
    COPIED=$((COPIED + 1))
    FILE_SIZE=$(du -h "${OUTPUT_DIR}/final.mp4" | cut -f1)
    echo "  ✅ final.mp4 (${FILE_SIZE})"
else
    MISSING="$MISSING final.mp4"
    echo "  ❌ final.mp4 없음"
fi

# 3. 메타데이터 생성
cat > "${OUTPUT_DIR}/metadata.json" << EOF
{
  "event_id": "${EVENT_ID}",
  "created_at": "$(date -Iseconds)",
  "language": "${LANG}",
  "channel": "${CHANNEL}",
  "quality_score": ${SCORE},
  "uploaded": false,
  "session_id": "${SESSION_ID}"
}
EOF
COPIED=$((COPIED + 1))

# 4. 결과 출력
echo ""
echo "📊 저장 결과:"
echo "  - 경로: ${OUTPUT_DIR}"
echo "  - 파일 수: ${COPIED}"

if [ -n "$MISSING" ]; then
    echo "  - 누락:${MISSING}"
fi

ls -la "${OUTPUT_DIR}/"

# 5. final.mp4 없으면 실패
if [ ! -f "${OUTPUT_DIR}/final.mp4" ]; then
    echo ""
    echo "❌ FAIL: final.mp4 파일이 저장되지 않음"
    exit 1
fi

echo ""
echo "✅ PASS: 결과물 저장 완료"
exit 0
