import { getAppStoreVersion } from "./lib/asc-client";
import { getInternalTrackInfo } from "./lib/play-client";
import { emitJson } from "./lib/logger";

interface RejectionAnalysis {
  platform: string;
  status: string;
  isRejected: boolean;
  category: "metadata" | "binary" | "policy" | "unknown";
  autoFixable: boolean;
  details: string;
  suggestions: string[];
}

const METADATA_KEYWORDS = [
  "screenshot", "description", "metadata", "privacy", "keyword",
  "subtitle", "release note", "what's new", "스크린샷", "설명", "개인정보",
];

const BINARY_KEYWORDS = [
  "crash", "performance", "bug", "binary", "permission",
  "entitlement", "충돌", "성능",
];

const POLICY_KEYWORDS = [
  "guideline", "policy", "payment", "in-app purchase",
  "content", "rating", "정책", "결제",
];

function categorizeRejection(reason: string): {
  category: RejectionAnalysis["category"];
  autoFixable: boolean;
} {
  const lower = reason.toLowerCase();

  if (METADATA_KEYWORDS.some((kw) => lower.includes(kw))) {
    return { category: "metadata", autoFixable: true };
  }
  if (BINARY_KEYWORDS.some((kw) => lower.includes(kw))) {
    return { category: "binary", autoFixable: false };
  }
  if (POLICY_KEYWORDS.some((kw) => lower.includes(kw))) {
    return { category: "policy", autoFixable: false };
  }
  return { category: "unknown", autoFixable: false };
}

function getSuggestions(category: RejectionAnalysis["category"]): string[] {
  switch (category) {
    case "metadata":
      return [
        "release.config.json의 store 섹션의 해당 필드를 수정하세요",
        "/release-metadata 로 dry-run 후 --apply 로 적용하세요",
        "스크린샷 문제라면 /release-screenshots 로 재생성하세요",
      ];
    case "binary":
      return [
        "코드 수정이 필요합니다 — 자동 수정 불가",
        "크래시 로그를 확인하세요",
        "수정 후 /release 로 새 바이너리를 제출하세요",
      ];
    case "policy":
      return [
        "Apple/Google 정책 가이드라인을 확인하세요",
        "결제 관련이라면 IAP 설정을 검토하세요",
        "콘텐츠 등급 문제라면 release.config.json의 store.apple.advisory를 수정하세요",
      ];
    default:
      return [
        "거절 사유를 App Store Connect / Play Console에서 직접 확인하세요",
        "상세 사유 파악 후 /release-fix 를 다시 실행하세요",
      ];
  }
}

async function analyzeIos(): Promise<RejectionAnalysis> {
  const version = await getAppStoreVersion();
  if (!version) {
    return {
      platform: "ios",
      status: "NO_VERSION",
      isRejected: false,
      category: "unknown",
      autoFixable: false,
      details: "No app store version found",
      suggestions: [],
    };
  }

  const isRejected = version.appStoreState === "REJECTED";
  const details = `iOS version ${version.versionString} state: ${version.appStoreState}`;

  if (!isRejected) {
    return {
      platform: "ios",
      status: version.appStoreState,
      isRejected: false,
      category: "unknown",
      autoFixable: false,
      details,
      suggestions: [],
    };
  }

  const { category, autoFixable } = categorizeRejection(details);

  return {
    platform: "ios",
    status: version.appStoreState,
    isRejected,
    category,
    autoFixable,
    details,
    suggestions: getSuggestions(category),
  };
}

async function analyzeAndroid(): Promise<RejectionAnalysis> {
  const internal = await getInternalTrackInfo();
  const latest = internal.releases?.[0];
  if (!latest) {
    return {
      platform: "android",
      status: "NO_RELEASE",
      isRejected: false,
      category: "unknown",
      autoFixable: false,
      details: "No internal track release found",
      suggestions: [],
    };
  }

  const isRejected = latest.status === "draft" || latest.status === "halted";
  const details = `Android version ${latest.versionCodes?.[0] ?? "?"} status: ${latest.status}`;

  return {
    platform: "android",
    status: latest.status,
    isRejected,
    category: "unknown",
    autoFixable: false,
    details,
    suggestions: isRejected ? getSuggestions("unknown") : [],
  };
}

async function main() {
  const [ios, android] = await Promise.all([
    analyzeIos().catch((e: any) => ({
      platform: "ios" as const,
      status: "error",
      isRejected: false,
      category: "unknown" as const,
      autoFixable: false,
      details: e.message,
      suggestions: [],
    })),
    analyzeAndroid().catch((e: any) => ({
      platform: "android" as const,
      status: "error",
      isRejected: false,
      category: "unknown" as const,
      autoFixable: false,
      details: e.message,
      suggestions: [],
    })),
  ]);

  emitJson({ ios, android });
}

main();
