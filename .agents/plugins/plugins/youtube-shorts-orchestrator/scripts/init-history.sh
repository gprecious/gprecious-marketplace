#!/bin/bash
# History 초기화 스크립트
# 사용법: ./init-history.sh

set -e

echo "📁 History 폴더 초기화"

# 폴더 생성
mkdir -p history/uploads history/sessions

# global-history.json 초기화 (없을 경우)
if [ ! -f "history/global-history.json" ]; then
    cat > history/global-history.json << 'EOF'
{
  "version": "1.0.0",
  "last_updated": null,
  "total_videos": 0,
  "videos": [],
  "topics_index": {},
  "keywords_index": []
}
EOF
    echo "  ✅ global-history.json 생성"
else
    echo "  ℹ️  global-history.json 이미 존재"
fi

# output 폴더 생성
mkdir -p output
echo "  ✅ output/ 폴더 확인"

echo ""
echo "✅ History 초기화 완료"
ls -la history/
