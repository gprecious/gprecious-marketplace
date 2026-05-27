# 마케팅 채널 리서치: growth-marketer 참조 문서

이 문서는 `growth-marketer` 플러그인의 `generate-copy`, `channel-playbook`, `cro-audit` 스킬이 광고 채널별 의사결정에 재사용할 수 있도록, 2026-05 기준으로 확인 가능한 공식 문서와 공개 자료를 바탕으로 정리했다. 검증 가능한 출처가 없는 운영 팁은 제외했으며, 각 섹션은 채널의 정의, 작동 원리, 실제 적용법, 예시를 포함한다.

## 1. Meta Ads (Facebook/Instagram) - 캠페인 목표, 타겟팅, 크리에이티브 베스트프랙티스

**무엇인가**: Meta Ads는 Facebook, Instagram, Messenger, WhatsApp, Meta Audience Network 같은 Meta 생태계 지면에 노출되는 유료 광고 시스템이며, Ads Manager에서 `Awareness`, `Traffic`, `Engagement`, `Leads`, `App promotion`, `Sales` 같은 캠페인 objective를 선택해 광고 전달 목표를 정의한다.[S1] Meta는 선택한 objective에 맞는 행동을 할 가능성이 높은 사람을 찾도록 auction system을 사용한다고 설명한다.[S1]

**메커니즘 / 왜 작동하는가**: objective는 단순한 리포팅 분류가 아니라 Meta의 delivery optimization 방향을 정하는 입력값이다.[S1] 예를 들어 `Traffic`은 클릭 또는 방문 가능성이 높은 사람을 찾는 데 맞고, `Sales`는 구매 또는 전환 가능성이 높은 사람을 찾는 데 맞다.[S1] 타겟팅은 지역, 연령, 성별, 언어 같은 제약과 관심사, 행동, Custom Audience, Lookalike, Advantage+ audience를 조합하는 방식이며, Advantage+ audience는 광고주가 준 audience suggestion을 우선 참고하되 더 넓은 범위에서 성과 가능성이 높은 사용자를 찾는다.[S2][S4] Advantage+ placements는 Facebook Feed, Reels, Instagram Stories, Instagram Feed, Messenger, Meta Audience Network 등 여러 placement에 자동 배분해 reach와 cost per result를 개선할 수 있다고 Meta가 설명한다.[S5]

**광고/랜딩/카피/CTR/CVR 적용법**: 전환을 원하는 캠페인에서 `Traffic`을 쓰면 저렴한 클릭은 늘어도 구매 학습 신호가 약해질 수 있으므로, 구매/가입/리드가 목표라면 objective를 `Sales` 또는 `Leads`로 맞추고 pixel 또는 Conversions API 이벤트를 landing page의 핵심 action에 연결한다.[S1][S7] audience는 초기에 지나치게 좁히기보다 핵심 제약과 high-signal source audience를 주고 Advantage+ audience 또는 broad delivery가 학습할 공간을 남긴다.[S2][S4] creative는 placement마다 비율과 문맥이 다르므로 정사각형, 세로형, 짧은 영상, 명확한 product shot, benefit-first headline을 여러 버전으로 넣고, Advantage+ creative의 image expansion, text generation, background generation 같은 자동 변형을 성과 실험의 후보로 다룬다.[S3][S6] landing page는 광고 promise와 첫 화면 메시지를 맞춰야 하며, `Sales` 캠페인에서는 가격, 배송, 보증, social proof, CTA를 fold 안에서 확인 가능하게 배치해 conversion event까지의 마찰을 줄인다.[S1][S7]

**예시**:

- D2C skincare 브랜드가 `Traffic` objective로 "피부 장벽 회복 루틴" 클릭을 모으는 대신, `Sales` objective와 `ViewContent`, `AddToCart`, `Purchase` pixel event를 연결하고, "민감 피부 2주 진정 루틴" 세로 영상, 전후 비교 이미지, 리뷰형 UGC를 각각 테스트한다.[S1][S3][S7]
- B2B SaaS가 `Leads` objective에서 broad audience에 직무 관심사 suggestion만 넣고, creative는 "엑셀 취합 4시간을 10분으로"처럼 outcome 중심으로 쓰며, landing page 첫 CTA를 "데모 예약" 하나로 고정한다.[S1][S2][S4]

## 2. Google Ads / App campaigns(UAC) - 검색, 디스플레이, 앱설치

**무엇인가**: Google Ads는 Search, Display, YouTube, Gmail, Discover, Google Play 등 Google 지면과 파트너 지면에 광고를 노출하는 플랫폼이다.[S8][S11][S12] Search campaign은 사용자의 검색어와 keyword가 관련될 때 검색 결과 주변에 광고를 노출하고, Display campaign은 Google Display Network의 웹사이트, 앱, YouTube, Gmail 등에서 시각 광고를 노출한다.[S8][S9][S11] App campaigns는 앱 설치, 앱 참여, 사전등록 목표를 위해 Search, Google Play, YouTube, Discover, Display Network에 자동으로 광고를 조합하고 최적화한다.[S12]

**메커니즘 / 왜 작동하는가**: Search는 사용자가 이미 문제나 상품을 검색하는 순간에 노출되므로 intent capture에 강하고, keyword와 search term의 관련성이 핵심이다.[S8][S9] Responsive search ads는 여러 headline과 description을 입력하면 Google Ads가 조합을 테스트해 성과가 좋은 조합을 학습한다.[S10] Display는 사용자가 검색하기 전 또는 구매 여정 초반에 visually engaging ad로 도달하고, targeting, bidding, format 최적화에 Google AI를 사용한다.[S11] App campaigns는 광고주가 text, bid, budget, location, language, image, video, store listing asset을 제공하면 여러 네트워크와 형식에서 조합을 테스트해 best-performing ads를 노출한다.[S12]

**광고/랜딩/카피/CTR/CVR 적용법**: Search에서는 campaign/ad group을 intent별로 쪼개고, keyword와 ad copy, landing page H1을 같은 문제 언어로 맞춘다.[S8][S9] 예를 들어 "invoice automation software"와 "free invoice template"은 구매 의도와 정보 의도가 다르므로 별도 ad group, 별도 CTA, 별도 landing page를 쓰는 것이 좋다.[S8][S9] Responsive search ads에는 동일한 문구 반복보다 pain, outcome, proof, offer, CTA를 각기 다른 headline으로 넣고, asset report에서 낮은 성과 asset을 교체한다.[S10][S11] Display는 cold prospecting에서는 제품 카테고리와 problem recognition에 맞춘 benefit visual을, remarketing에서는 본 상품/카테고리/장바구니 context에 맞춘 offer를 쓴다.[S11][S29] App campaigns는 설치 볼륨 목표면 target CPI와 충분한 daily budget을 설정하고, 가치 있는 in-app action 최적화 목표라면 해당 action이 충분히 발생하는지 먼저 확인한다.[S13]

**예시**:

- 검색광고 예시: "법인카드 정산 자동화" keyword ad group에는 headline을 "법인카드 정산 자동화", "영수증 누락 알림", "월말 마감 시간 단축"처럼 검색어, 기능, outcome으로 나누고 landing page 첫 화면에 동일한 용어와 demo CTA를 둔다.[S8][S9][S10]
- 앱설치 예시: 명상 앱은 App campaign for installs에서 10-30초 세로 영상, 정사각형 이미지, 짧은 text asset을 모두 채우고, 이후 `trial_start` 같은 in-app action이 하루 최소 10건 이상 안정적으로 발생하면 install volume에서 in-app action 최적화로 분리한다.[S12][S13]

## 3. Naver - 검색광고(파워링크), GFA(성과형 디스플레이), 한국 시장 특성

**무엇인가**: Naver는 한국 시장에서 검색, 쇼핑, 콘텐츠, 지도, 페이, 커뮤니티 지면을 갖춘 대형 포털이며, Naver Corp.는 광고 서비스로 사이트검색, 쇼핑검색, 콘텐츠검색, 브랜드검색, 플레이스, 성과형 디스플레이 광고, ADVoost 등을 제공한다고 설명한다.[S14] 파워링크는 네이버 통합검색에 노출되는 사이트검색광고 영역이며, 노출 순위는 검색어와 사이트 콘텐츠의 연관성, 입찰가, 소재 품질 등 종합 결과로 결정된다고 네이버 도움말이 설명한다.[S15] GFA(성과형 디스플레이 광고)는 마케팅 목적에 맞는 audience를 대상으로 실시간 입찰 방식으로 광고를 노출하고, CPM, CPC, CPV 같은 과금 방식을 선택할 수 있는 성과형 display 상품이다.[S16]

**메커니즘 / 왜 작동하는가**: 한국에서는 Naver 검색 점유율이 여전히 높으며, Korea Times는 InternetTrend 자료를 인용해 2026년 3월 국내 웹 검색 점유율이 Naver 63.8%, Google 28.7%였다고 보도했다.[S18] Naver 검색광고는 검색어 기반 intent capture에 강하고, 쇼핑검색/플레이스/콘텐츠검색처럼 Naver 내부 서비스와 연결된 지면이 많기 때문에 한국 소비자의 탐색 동선과 결제/예약/지도 행동에 맞춰야 한다.[S14][S15] GFA는 Naver 모바일/PC 메인, 주요 서비스, 패밀리 서비스, 퍼포먼스 네트워크에 배너와 동영상 소재를 노출하고, 서비스 이용 이력, 인구통계, 관심사/구매의도, 광고주 보유 데이터 기반 맞춤 타겟, AI 기반 audience 추천을 제공한다.[S16]

**광고/랜딩/카피/CTR/CVR 적용법**: 파워링크는 Google Search처럼 keyword intent를 잡되, Naver 사용자에게 익숙한 한국어 카테고리명, 가격 조건, 지역명, 네이버페이/예약/스마트스토어 연결 여부를 카피와 landing flow에 반영해야 한다.[S14][S15] 소재 품질과 사이트 콘텐츠 연관성이 순위 요소에 포함되므로, 광고문안의 핵심 키워드와 landing page 제목/상품명/설명 문구를 일치시키고 과장 headline보다 검색 의도에 직접 답하는 headline을 우선한다.[S15] GFA는 prospecting에서는 관심사/구매의도 audience와 broad creative test를 쓰고, conversion 목적에서는 충분한 event collection과 리포트 기반 소재 교체가 중요하다.[S16][S19] 앱 전환은 MMP 연동을 통한 MAT 전환 추적이 필요하며, 수집된 전환 데이터가 전환 최적화 자동 입찰과 MAT target 생성에 사용될 수 있다고 네이버가 안내한다.[S19]

**예시**:

- 로컬 피부과는 파워링크에서 "강남 여드름 흉터 치료", "강남 피부과 가격" 같은 지역+문제 keyword를 분리하고, 광고문안은 "강남역 3분", "시술 전 상담", "네이버 예약 가능"처럼 Naver 사용자의 비교 기준을 직접 제시한다.[S14][S15]
- 스마트스토어 브랜드는 GFA에서 "첫구매 할인" 배너와 "장바구니 이탈 고객"용 프로모션 소재를 분리하고, MAT 또는 쇼핑 target이 충분히 쌓인 뒤 전환 최적화 자동 입찰의 학습 신호로 사용한다.[S16][S19]

## 4. ASO (App Store Optimization) - Apple App Store + Google Play 리스팅 최적화

**무엇인가**: ASO는 App Store와 Google Play에서 app listing의 발견 가능성과 설치 전환율을 높이기 위해 app name/title, subtitle 또는 short description, keyword metadata, icon, screenshots, preview video, promotional text, localization, rating/review를 최적화하는 작업이다.[S20][S23][S24] Apple은 product page에서 app icon, name, subtitle, preview, screenshot, description, keyword 같은 요소를 사용자가 앱을 이해하고 발견하는 데 쓰는 정보로 설명한다.[S20] Google Play는 store listing이 사용자가 앱을 browse 또는 search할 때 처음 보는 요소이며, short description은 80자 이내로 앱 메시지를 전달해야 한다고 안내한다.[S23]

**메커니즘 / 왜 작동하는가**: 앱스토어 검색과 탐색 지면은 사용자의 query, category, visual asset, store listing metadata, conversion behavior가 결합된 발견 환경이므로, listing은 keyword relevance와 install confidence를 동시에 처리해야 한다.[S20][S23] Apple Product Page Optimization은 icon, screenshot, app preview video를 최대 3개 treatment로 테스트하고 App Analytics에서 impression, conversion rate, confidence를 비교해 가장 좋은 variant를 적용할 수 있게 한다.[S21] Apple Custom Product Pages는 최대 70개의 추가 product page를 만들고 각 page에 고유 URL, screenshot, promotional text, app preview를 설정해 audience별 메시지를 다르게 보여줄 수 있다.[S22] Google Play는 title, short description, full description, graphic assets, screenshots, video 등을 store listing setup의 일부로 다룬다.[S23][S24]

**광고/랜딩/카피/CTR/CVR 적용법**: Apple App Store에서는 brand keyword와 category keyword를 app name/subtitle/keyword field에 과도하지 않게 배치하고, screenshot 첫 1-3장은 기능 나열보다 사용자가 얻는 outcome을 보여줘야 한다.[S20][S21] paid campaign에서는 모든 유입을 기본 product page로 보내지 말고, 문제별 Custom Product Page를 만들어 ad creative와 screenshot promise를 맞춘다.[S22] Google Play에서는 short description 80자 안에 핵심 value proposition과 primary keyword를 넣고, full description은 search intent, 주요 기능, 신뢰 요소, 업데이트된 benefit을 자연스럽게 설명한다.[S23][S24] ASO 실험은 install CVR만 보지 말고 downstream metric인 trial start, purchase, day-7 retention과 함께 평가해야 하며, Apple PPO의 treatment 적용은 테스트가 baseline 대비 충분한 confidence를 보일 때까지 기다리는 것이 좋다.[S21]

**예시**:

- 영어학습 앱은 Apple 기본 product page에는 "AI 영어회화 연습"을 전면에 두고, 직장인 광고용 Custom Product Page는 screenshot 첫 장을 "회의 영어 10분 연습"으로, 여행자 광고용 page는 "공항/호텔 표현 즉시 연습"으로 바꾼다.[S22]
- 홈트 앱은 Google Play short description을 "집에서 10분, 장비 없이 맞춤 운동 루틴"처럼 80자 이내 value proposition으로 쓰고, screenshot은 "오늘 루틴", "자세 가이드", "진척도 기록", "초보자 플랜" 순으로 conversion anxiety를 낮춘다.[S23][S24]

## 5. SEO / 콘텐츠 마케팅 - 오가닉 검색 유입

**무엇인가**: SEO는 검색엔진이 사이트와 콘텐츠를 crawl, index, understand하기 쉽게 만들고, 사용자가 검색 결과에서 선택할 만한 helpful content를 제공해 organic search traffic을 얻는 활동이다.[S25][S26] Google Search Central은 SEO를 검색엔진이 콘텐츠를 더 잘 발견하고 이해하도록 돕는 활동으로 설명하며, 이 활동은 people-first content에 적용될 때 유용하다고 설명한다.[S26]

**메커니즘 / 왜 작동하는가**: Google은 automated ranking systems가 사람에게 도움이 되고 신뢰할 수 있는 정보를 우선하도록 설계되어 있으며, 원본 정보, 완전한 설명, 명확한 sourcing, 전문성, 좋은 page experience 같은 질문으로 콘텐츠 품질을 평가하라고 안내한다.[S26] SEO Starter Guide는 title link, headings, internal links, structured data, crawlable link, image alt text 같은 기본 요소가 Google이 페이지를 이해하고 검색 결과에 표시하는 데 도움을 준다고 설명한다.[S25] Google은 title link 생성에 `<title>` element, heading, 페이지의 prominent text, 웹상의 reference 등 여러 신호를 사용한다고 안내한다.[S27]

**광고/랜딩/카피/CTR/CVR 적용법**: 콘텐츠 주제는 keyword volume만 보고 고르지 말고 search intent를 `정보 탐색`, `비교`, `구매`, `문제 해결`, `브랜드 탐색`으로 나눈 뒤 page type을 결정한다.[S25][S26] article은 "정의-비교-체크리스트-실행법-FAQ"처럼 query의 후속 질문까지 답하도록 구성하고, landing page로 전환시키는 내부 링크는 문맥상 자연스러운 anchor text를 쓴다.[S25][S26] CTR을 높이려면 title은 과장보다 페이지 내용을 정확히 요약해야 하고, meta description은 ranking factor로 오해하기보다 search result snippet에서 사용자의 선택을 돕는 concise promise로 다룬다.[S25][S27] CRO 관점에서는 organic page의 CTA를 무조건 상단에 반복하기보다 intent depth에 맞춰 "템플릿 다운로드", "가격표 보기", "데모 예약", "무료 진단"처럼 다음 행동을 세분화한다.[S25][S26]

**예시**:

- B2B 회계 SaaS는 "전자세금계산서 발행 방법" article에서 절차와 오류 해결을 설명하고, 중간 CTA는 "발행 체크리스트 다운로드", 하단 CTA는 "월말 마감 자동화 데모"로 나눠 정보 탐색 사용자를 바로 sales demo로 밀지 않는다.[S25][S26]
- 이커머스 브랜드는 "여드름 패치 추천" page를 단순 상품 리스트로 만들지 않고, 피부 타입별 선택 기준, 성분 차이, 사용 순서, 자사 제품이 맞는 경우와 맞지 않는 경우를 제시해 original information과 trust signal을 강화한다.[S26]

## 6. 리타게팅/리마케팅 - 픽셀, 오디언스, 시퀀스

**무엇인가**: 리타게팅/리마케팅은 웹사이트, 앱, 동영상, CRM, 구매 데이터 등에서 이미 브랜드와 상호작용한 사용자를 audience segment로 만들고 다시 광고를 노출하는 방식이다.[S7][S28][S30] Google은 "remarketing" 용어를 "your data segments"로 바꾸었으며, website/app visitor, Customer Match, Google-engaged audience 같은 세그먼트로 기존 사용자에게 재도달할 수 있다고 설명한다.[S30] Meta는 website visitor, app user, customer list, Facebook Page engagement 등을 Custom Audience로 만들어 remarketing campaign에 활용할 수 있다고 안내한다.[S7]

**메커니즘 / 왜 작동하는가**: 이미 제품을 본 사용자, 장바구니에 담은 사용자, 앱을 설치한 사용자, trial을 시작한 사용자는 cold audience보다 문제 인식과 브랜드 인지가 높기 때문에, 같은 impression이라도 더 구체적인 objection 처리와 offer 제시가 가능하다.[S7][S28][S29] Google Analytics remarketing은 사용자가 앱 또는 사이트에서 특정 행동 profile에 맞으면 audience에 추가하고, Google Ads와 연결하면 Search, Display, YouTube remarketing에 사용할 수 있다.[S28] Dynamic remarketing은 사용자가 본 product ID, price 같은 dynamic attribute를 Google Ads로 보내 특정 상품 정보를 포함한 광고를 만들 수 있게 한다.[S28][S29]

**광고/랜딩/카피/CTR/CVR 적용법**: 기본 audience는 `all visitors`, `product viewers`, `add-to-cart no purchase`, `checkout abandoners`, `past purchasers`, `high-LTV customers`, `trial started no activation`, `app installed no purchase`처럼 funnel stage별로 나눈다.[S28][S30] sequence는 1-3일차에는 reminder와 핵심 benefit, 4-7일차에는 review/proof, 8-14일차에는 comparison/FAQ, 15-30일차에는 offer 또는 새로운 angle을 쓰는 식으로 intent decay를 반영한다.[S28][S29] 구매 완료자와 lead 제출자는 acquisition retargeting에서 제외하고, cross-sell 또는 onboarding sequence로 별도 분리해야 예산 낭비와 메시지 충돌을 줄일 수 있다.[S7][S30] 개인정보와 정책 측면에서는 personalized advertising policy, consent, hashed customer data, sensitive category 제한을 확인해야 하며, Google은 user-provided data와 hashed customer data가 cookie나 identifier가 없을 때 coverage를 보완할 수 있다고 설명한다.[S28][S30][S32]

**예시**:

- 쇼핑몰은 `ViewContent 7일`, `AddToCart 7일 no Purchase`, `Purchase 180일` audience를 만들고, 장바구니 이탈자에게는 본 상품 이미지와 "오늘 출고 / 무료교환" proof를, 구매자에게는 14일 뒤 보완재 추천을 노출한다.[S28][S29][S30]
- SaaS는 `pricing page viewed no signup`, `trial started no activation`, `activated no paid` audience를 나누고, pricing viewer에게는 "ROI 계산기", trial no activation에게는 "5분 설정 가이드", activated no paid에게는 "팀 권한/보안 기능" 카피를 보여준다.[S28][S30]

## 출처

- [S1] Meta for Business, "Ad objectives" - https://www.facebook.com/business/ads/ad-objectives?locale=en_GB
- [S2] Meta for Business, "Audience ad targeting" - https://www.facebook.com/business/ads/ad-targeting
- [S3] Meta for Business, "Ad creative" - https://www.facebook.com/business/ads/ad-creative
- [S4] Meta for Business, "Advantage+ audience" - https://www.facebook.com/business/ads/meta-advantage-plus/audience
- [S5] Meta for Business, "Advantage+ placements" - https://www.facebook.com/business/ads/meta-advantage-plus/placements
- [S6] Meta for Business, "Advantage+ creative" - https://www.facebook.com/business/ads/meta-advantage-plus/creative
- [S7] Meta for Business, "Retargeting" - https://www.facebook.com/business/goals/retargeting
- [S8] Google Ads Help, "About the Google Search Network" - https://support.google.com/google-ads/answer/1722047?hl=en-EN
- [S9] Google Ads Help, "About keywords in Search Network campaigns" - https://support.google.com/google-ads/answer/1704371?hl=en-EN
- [S10] Google Ads Help, "About responsive search ads" - https://support.google.com/google-ads/answer/7684791?hl=en-uk
- [S11] Google Ads Help, "About Display ads and the Google Display Network" - https://support.google.com/google-ads/answer/2404190?hl=en
- [S12] Google Ads Help, "About App campaigns" - https://support.google.com/google-ads/answer/6247380?hl=en-CA
- [S13] Google Ads Help, "Best practices guide: Setting up your App campaigns" - https://support.google.com/google-ads/answer/6167162?hl=en
- [S14] NAVER Corp., "광고 서비스" - https://www.navercorp.com/service/advertisement
- [S15] 네이버 광고주센터, "파워링크 네이버 통합검색에 광고가 노출되는 순위는 어떻게 결정되나요?" - https://ads.naver.com/help/faq/189?t=1772436056050
- [S16] 네이버 광고주센터, "성과형 디스플레이 광고 플랫폼 알아보기" - https://ads.naver.com/help/faq/831?t=1773313403173
- [S17] 네이버 광고주센터, "성과형 디스플레이 광고 광고 등록 프로세스 알아보기" - https://ads.naver.com/help/faq/832?t=1743429714265
- [S18] The Korea Times, "Naver remains dominant player in Korea's search market" - https://www.koreatimes.co.kr/business/tech-science/20260416/naver-remains-dominant-player-in-koreas-search-market
- [S19] 네이버 광고주센터, "모바일 앱(MAT) 전환 추적 설정하기" - https://ads.naver.com/help/faq/895?t=1750701058470
- [S20] Apple Developer, "Creating Your Product Page" - https://developer.apple.com/app-store/product-page/
- [S21] Apple Developer, "Product Page Optimization" - https://developer.apple.com/app-store/product-page-optimization/
- [S22] Apple Developer, "Custom Product Pages" - https://developer.apple.com/app-store/custom-product-pages/?cid=developer80
- [S23] Play Console Help, "Best practices for your store listing" - https://support.google.com/googleplay/android-developer/answer/13393723?hl=en-GB
- [S24] Play Console Help, "Create and set up your app" - https://support.google.com/googleplay/android-developer/answer/9859152?hl=en-EN
- [S25] Google Search Central, "SEO Starter Guide" - https://developers.google.com/search/docs/fundamentals/seo-starter-guide
- [S26] Google Search Central, "Creating helpful, reliable, people-first content" - https://developers.google.com/search/docs/fundamentals/creating-helpful-content
- [S27] Google Search Central, "Influencing title links in Google Search" - https://developers.google.com/search/docs/advanced/appearance/good-titles-snippets?hl=en
- [S28] Analytics Help, "Enable remarketing with Google Analytics data" - https://support.google.com/analytics/answer/9313634?hl=en
- [S29] Google Ads Help, "About dynamic remarketing for retail" - https://support.google.com/google-ads/answer/6099158?hl=en
- [S30] Google Ads Help, "About audience segments" - https://support.google.com/google-ads/answer/2497941?hl=en
- [S31] Google Ads Help, "Set up dynamic remarketing with Display, Performance Max, and App campaigns" - https://support.google.com/google-ads/answer/6287125?hl=en
- [S32] Google Ads Help, "About setting up your data segments" - https://support.google.com/google-ads/answer/2454000?hl=en-EN
