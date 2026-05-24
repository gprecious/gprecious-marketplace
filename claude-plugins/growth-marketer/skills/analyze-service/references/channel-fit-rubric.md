# channel-fit-rubric (baseline v0)

> 하드코딩 baseline — Plan 2 research 가 출처와 함께 보강한다. analyze-service 가
> service-profile 의 속성을 아래 신호에 매핑해 0~5 점을 매기고 근거를 단다.

## 입력 신호 (service-profile 에서)
- product_type: mobile_app | web_saas
- market: kr | global | both
- price_model: free | freemium | paid | subscription
- target: b2c | b2b
- discovery_intent: high(사람들이 검색함) | low(수요 창출 필요)

## 채널별 점수 가이드 (0~5)
| 채널 | 강한 신호(+) | 약한 신호(-) |
|---|---|---|
| aso | mobile_app | web_saas only |
| google-ads | discovery_intent=high, global/both | 순수 수요창출만 필요 |
| naver | market=kr 또는 both | global only |
| meta | b2c, 시각적 소구, 수요창출 | b2b 니치 |
| seo | web_saas, 콘텐츠 여력, 장기 | 즉시 전환 필요 |
| retargeting | 트래픽 이미 있음 | 콜드 스타트(트래픽 0) |

## 산출 규칙
- 각 채널 score + 한 줄 rationale(어떤 신호 때문인지).
- recommendation.primary = 최고점 채널, secondary = 2~3순위, why = 종합 근거.
- 동점이면 product_type 주채널(mobile_app→aso, web_saas→seo) 우선.
