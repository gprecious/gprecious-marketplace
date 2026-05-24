#!/bin/bash
# 환경 변수 체크 스크립트
# 사용법: ./env-check.sh [--upload]

UPLOAD=false
[ "$1" = "--upload" ] && UPLOAD=true

# 1. .env 파일 탐색 (현재 디렉토리 → git root → 스크립트 위치 기준)
ENV_FILE=""

# 현재 디렉토리
if [ -f ".env" ]; then
    ENV_FILE=".env"
fi

# git root 확인
if [ -z "$ENV_FILE" ]; then
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$GIT_ROOT" ] && [ -f "$GIT_ROOT/.env" ]; then
        ENV_FILE="$GIT_ROOT/.env"
    fi
fi

# 스크립트 위치 기준 상위 탐색
if [ -z "$ENV_FILE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SEARCH_DIR="$SCRIPT_DIR"
    for _ in 1 2 3 4 5; do
        SEARCH_DIR="$(dirname "$SEARCH_DIR")"
        if [ -f "$SEARCH_DIR/.env" ]; then
            ENV_FILE="$SEARCH_DIR/.env"
            break
        fi
    done
fi

if [ -z "$ENV_FILE" ]; then
    echo "❌ FAIL: .env 파일을 찾을 수 없습니다"
    echo ""
    echo "📋 탐색 위치:"
    echo "  - 현재 디렉토리: $(pwd)"
    echo "  - Git root: ${GIT_ROOT:-없음}"
    echo ""
    echo "📋 설정 방법:"
    echo "  cp .env.example .env"
    echo "  vi .env"
    exit 1
fi

echo "📂 .env 로드: $ENV_FILE"

# 2. .env 로드
set -a
source "$ENV_FILE"
set +a

MISSING=""
AVAILABLE=""

# 3. 필수 변수 검증

# TTS (필수)
if [ -z "$ELEVENLABS_API_KEY" ]; then
    MISSING="$MISSING\n  ❌ ELEVENLABS_API_KEY (TTS 음성 생성)"
else
    AVAILABLE="$AVAILABLE\n  ✅ ELEVENLABS_API_KEY"
fi

# AI 영상 (하나 이상)
if [ -z "$OPENAI_API_KEY" ] && [ -z "$GCP_PROJECT_ID" ]; then
    MISSING="$MISSING\n  ❌ OPENAI_API_KEY 또는 GCP_PROJECT_ID (AI 영상)"
else
    [ -n "$OPENAI_API_KEY" ] && AVAILABLE="$AVAILABLE\n  ✅ OPENAI_API_KEY (Sora)"
    [ -n "$GCP_PROJECT_ID" ] && AVAILABLE="$AVAILABLE\n  ✅ GCP_PROJECT_ID (Veo)"
fi

# 스톡 영상 (하나 이상)
if [ -z "$PEXELS_API_KEY" ] && [ -z "$PIXABAY_API_KEY" ]; then
    MISSING="$MISSING\n  ❌ PEXELS_API_KEY 또는 PIXABAY_API_KEY (스톡 영상)"
else
    [ -n "$PEXELS_API_KEY" ] && AVAILABLE="$AVAILABLE\n  ✅ PEXELS_API_KEY"
    [ -n "$PIXABAY_API_KEY" ] && AVAILABLE="$AVAILABLE\n  ✅ PIXABAY_API_KEY"
fi

# 업로드 시 추가 확인
if [ "$UPLOAD" = true ]; then
    if [ -z "$YOUTUBE_CLIENT_ID" ]; then
        MISSING="$MISSING\n  ❌ YOUTUBE_CLIENT_ID"
    else
        AVAILABLE="$AVAILABLE\n  ✅ YOUTUBE_CLIENT_ID"
    fi
    if [ -z "$YOUTUBE_CLIENT_SECRET" ]; then
        MISSING="$MISSING\n  ❌ YOUTUBE_CLIENT_SECRET"
    else
        AVAILABLE="$AVAILABLE\n  ✅ YOUTUBE_CLIENT_SECRET"
    fi
fi

# 4. 결과 출력
if [ -n "$MISSING" ]; then
    echo "❌ FAIL: 환경 변수 누락"
    echo -e "$MISSING"
    echo ""
    echo "📋 API 키 발급:"
    echo "  - ElevenLabs: https://elevenlabs.io"
    echo "  - OpenAI (Sora): https://platform.openai.com"
    echo "  - Pexels: https://www.pexels.com/api/"
    echo "  - YouTube: https://console.cloud.google.com"
    exit 1
fi

echo "✅ PASS: 환경 변수 검증 완료"
echo -e "$AVAILABLE"
exit 0
