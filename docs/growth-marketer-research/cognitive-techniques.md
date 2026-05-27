# 인지심리학 기반 CTR·전환 기법 리서치

이 문서는 `growth-marketer` 플러그인의 `generate-copy`, `channel-playbook`, `cro-audit` 스킬에 넣을 수 있는 실무형 reference이다. 각 기법은 광고, landing page, copy, CTR, conversion 판단에 바로 쓰기 위한 관점으로 정리했다. 심리학 개념은 강력한 "보장 공식"이 아니라 의사결정 heuristic, attention cue, 실험 가설의 원천으로 다루어야 한다. 실제 성과 판단은 A/B test 또는 holdout 기반 검증으로 닫는다. [Optimizely A/B testing](https://www.optimizely.com/optimization-glossary/ab-testing/), [Kohavi et al., Controlled experiments on the web](https://link.springer.com/article/10.1007/s10618-008-0114-1)

## 1. Cialdini 설득 6원칙

**무엇인가.** Robert B. Cialdini의 고전적 6원칙은 `reciprocity`, `commitment/consistency`, `social proof`, `authority`, `liking`, `scarcity`이다. Cialdini의 HBR 글은 설득이 인간의 깊은 욕구에 예측 가능하게 호소하며, 여섯 가지 원칙을 학습·적용할 수 있다고 설명한다. [Cialdini, Harnessing the Science of Persuasion](https://www.influenceatwork.com/wp-content/uploads/2014/05/Harvard-Business-Review-.pdf) Cornell Hospitality Quarterly에 실린 Cialdini/Goldstein 논문도 여섯 원칙을 `liking`, `reciprocation`, `consistency`, `scarcity`, `social validation`, `authority`로 정리한다. [Cialdini & Goldstein, The Science and Practice of Persuasion](https://www2.psych.ubc.ca/~schaller/308Readings/Cialdini2002.pdf)

**메커니즘 / 왜 작동하는가.** 6원칙은 정보가 부족하거나 빠른 판단이 필요한 상황에서 사람들이 쓰는 shortcut으로 작동한다. 예를 들어 `reciprocity`는 먼저 받은 가치에 보답하려는 압력을 만들고, `authority`는 전문성 신호를 판단 비용 절감 장치로 쓰게 하며, `social proof`는 나와 비슷한 타인의 선택을 불확실성 감소 신호로 읽게 한다. Cialdini는 social proof의 적용을 "similar others"의 lead를 쓰는 것으로, authority의 적용을 전문성이 자명하다고 가정하지 말고 노출하는 것으로 설명한다. [Cialdini, HBR](https://www.influenceatwork.com/wp-content/uploads/2014/05/Harvard-Business-Review-.pdf)

**구체 적용.** 광고 headline은 한 번에 한 원칙만 전면에 세운다. `authority`가 목표라면 "전문가가 설계한" 같은 빈 표현보다 자격, 데이터 출처, audit badge, 고객군을 명시한다. `reciprocity`는 "무료 템플릿"을 대가 요구 전에 제공하고, CTA는 "템플릿 받고 내 캠페인 점검하기"처럼 받은 가치와 다음 행동을 연결한다. `commitment/consistency`는 첫 CTA를 `무료 진단 보기`, `내 업종 선택하기`, `체크리스트 완료하기`처럼 작은 공개적 선택으로 만든 뒤, 다음 step에서 demo나 signup을 요청한다. `liking`은 브랜드 말투와 고객의 언어를 맞추는 데 쓰되, 조작적 친근감보다 segment-specific phrasing을 우선한다. [Cialdini & Goldstein](https://www2.psych.ubc.ca/~schaller/308Readings/Cialdini2002.pdf)

**예시.**

- B2B SaaS ad: "마케팅 리드가 매주 쓰는 CRO checklist 무료 제공"은 `reciprocity`를 쓰고, landing page에는 "다운로드 후 3분 진단"을 다음 micro-commitment로 둔다.
- Expert service landing: hero 아래에 "ex-Google Ads specialist", "최근 90일 audit 42건", "업종별 benchmark 포함"을 배치하면 `authority`와 `social proof`가 서로 보강된다.

**주의.** Cialdini 원칙은 copy ingredient이지 성과 보장이 아니다. 같은 원칙도 audience awareness, offer strength, price, traffic source에 따라 다르게 작동하므로 headline, CTA, proof block 단위로 실험해야 한다. [Optimizely A/B testing](https://www.optimizely.com/optimization-glossary/ab-testing/)

## 2. 손실회피 / prospect theory

**무엇인가.** Prospect theory는 사람들이 결과를 최종 자산 상태가 아니라 기준점(reference point) 대비 `gain`과 `loss`로 부호화한다고 설명한다. Kahneman과 Tversky는 decision maker가 outcome을 gain/loss로 인식하며, 기준점은 현재 상태뿐 아니라 기대나 문제 제시 방식에 의해 바뀔 수 있다고 정리했다. 또한 손실은 이익보다 더 크게 체감된다는 `losses loom larger than gains` 명제를 제시했다. [Kahneman & Tversky, Prospect Theory](https://studylib.net/doc/28016460/kahneman-tversky-1979-prospect-theory)

**메커니즘 / 왜 작동하는가.** 같은 변화라도 "얻는 것"과 "잃지 않는 것"의 frame이 다르면 기준점과 감정 강도가 달라진다. Prospect theory의 가치 함수는 기준점 주변에서 gain과 loss를 다르게 평가하며, loss 영역의 기울기가 더 가파르다는 설명을 둔다. 그래서 사용자는 "월 20시간 절약"보다 "매월 20시간을 계속 잃고 있음"에 더 강하게 반응할 수 있다. 단, loss framing은 불안 유발이 심하면 trust를 훼손할 수 있으므로 증거와 해결 경로가 붙어야 한다. [Kahneman & Tversky](https://studylib.net/doc/28016460/kahneman-tversky-1979-prospect-theory)

**구체 적용.** CTR용 ad copy에서는 현재 손실을 빠르게 인식시킨다. 예: "광고비가 새는 keyword를 아직 모른다면"처럼 loss를 특정한다. Landing page에서는 손실 frame 다음에 즉시 mitigation path를 제시한다. `Problem -> quantified loss -> product mechanism -> low-risk CTA` 순서가 적합하다. Pricing page에서는 annual discount를 "2개월 무료"로만 말하지 말고 "월 결제 대비 연간 $X 절약"처럼 기준점을 제시한다. Churn-save email에서는 "혜택 종료"보다 "저장한 자동화 12개와 리포트 history가 중단됨"처럼 사용자가 실제로 잃는 asset을 명시한다.

**예시.**

- Ad: "매주 보고서 취합에 4시간을 잃고 있다면" -> landing headline: "분산된 channel report를 10분 안에 한 화면으로 정리".
- Checkout: "오늘 annual로 바꾸면 월 결제 대비 $240 절약"은 기준점을 monthly plan으로 고정해 saving을 loss-avoidance로 읽게 한다.

**주의.** 손실회피는 fearmongering과 다르다. 제품이 실제로 줄이는 비용, 시간, 위험만 써야 하며, 검증되지 않은 "매출 손실" 수치를 만들면 안 된다. Prospect theory는 framing과 reference point의 영향은 설명하지만, 특정 copy가 항상 더 높은 conversion을 낸다는 증거는 아니다. [Kohavi et al.](https://link.springer.com/article/10.1007/s10618-008-0114-1)

## 3. 앵커링 / 프라이밍

**무엇인가.** Anchoring은 판단자가 처음 접한 숫자나 정보에 기대어 이후 추정치를 조정하지만, 조정이 충분하지 않아 bias가 남는 현상이다. Epley와 Gilovich는 anchoring-and-adjustment가 불확실한 판단에서 떠오른 정보에 고정한 뒤 plausible estimate까지 조정하는 방식이며, insufficient adjustment가 bias를 설명한다고 정리한다. [Epley & Gilovich, The Anchoring-and-Adjustment Heuristic](https://journals.sagepub.com/doi/abs/10.1111/j.1467-9280.2006.01704.x)

Priming은 먼저 노출된 stimulus가 이후 stimulus 처리나 반응에 영향을 주는 현상이다. Consumer behavior review는 priming을 초기 stimulus가 개인의 이후 반응에 영향을 주는 효과로 설명하고, 1990년대 이후 consumer behavior 연구에서도 tool, 연구 대상, marketing element의 작동 방식으로 쓰였다고 정리한다. [Pacheco Junior et al., Priming in consumer behavior research](https://pepsic.bvsalud.org/scielo.php?lng=en&pid=S1808-42812015000100016&script=sci_abstract)

**메커니즘 / 왜 작동하는가.** Anchoring은 숫자 판단에서 특히 유용하다. 사용자가 처음 본 가격, benchmark, inventory 수량, ROI 수치가 이후 선택지 평가의 기준점이 된다. Priming은 특정 category, emotion, goal을 먼저 활성화해 다음 copy나 CTA를 해석하는 틀을 바꾼다. 다만 priming은 맥락 의존적이고 연구상 열린 문제가 남아 있으므로, "무의식 조작"처럼 과장하면 안 된다. [Pacheco Junior et al.](https://pepsic.bvsalud.org/scielo.php?lng=en&pid=S1808-42812015000100016&script=sci_abstract)

**구체 적용.** Pricing table에서는 가장 비싼 enterprise plan을 왼쪽이나 위에 먼저 보여줄지, recommended plan을 중앙에 둘지에 따라 anchor가 달라진다. Discount copy에서는 정가, 업계 평균 비용, 기존 프로세스 비용을 먼저 제시하고 할인 가격이나 automation cost를 뒤에 둔다. Priming은 landing hero 전후의 label에 쓴다. 예를 들어 "for lean teams", "privacy-first", "no-code automation" 같은 cue를 H1보다 먼저 보이면 사용자가 다음 claim을 해석하는 frame이 달라진다.

**예시.**

- Pricing: "$499 agency audit"을 anchor로 제시한 뒤 "$79/month continuous audit"을 보여주면 subscription이 상대적으로 낮게 보인다.
- Landing: hero eyebrow를 "For solo founders"로 두면 같은 "launch 5 campaigns in a day" 문장이 enterprise automation보다 founder productivity로 해석된다.

**주의.** Anchor가 허위 정가, 가짜 benchmark, 임의 ROI이면 deceptive pricing이 된다. Priming도 제품과 무관한 감정 cue를 과도하게 쓰면 기대 불일치가 생긴다. 실무에서는 anchor 수치의 출처, 계산식, 표시 위치를 실험 변수로 분리한다. [Optimizely sample size calculator](https://www.optimizely.com/sample-size-calculator/)

## 4. 희소성 / FOMO

**무엇인가.** Scarcity는 Cialdini 6원칙 중 하나로, 사람들이 덜 이용 가능하다고 인식한 것을 더 원하게 되는 현상이다. Cialdini의 HBR 글은 scarcity의 적용을 unique benefits와 exclusive information을 강조하는 것으로 설명한다. [Cialdini, HBR](https://www.influenceatwork.com/wp-content/uploads/2014/05/Harvard-Business-Review-.pdf) FOMO는 Przybylski et al.이 "다른 사람들이 보상적인 경험을 하고 있는데 내가 빠져 있을지 모른다는 광범위한 염려"와 계속 연결되어 있으려는 욕구로 정의하고 측정 척도를 제안한 개념이다. [Przybylski et al., Fear of Missing Out](https://selfdeterminationtheory.org/wp-content/uploads/2014/04/2013_PrzybylskiMurayamaDeHaanGladwell_CIHB.pdf)

**메커니즘 / 왜 작동하는가.** Scarcity는 기회비용과 anticipated regret를 키운다. "지금 행동하지 않으면 나중에 같은 조건을 얻지 못한다"는 판단이 decision latency를 줄인다. FOMO는 social information과 연결되어 "남들은 이미 얻고 있는데 나는 빠지고 있다"는 gap을 만든다. Przybylski et al.은 social media가 실시간 social information을 풍부하게 제공하고, 이 환경이 FOMO에 대한 관심을 촉발했다고 설명한다. [Przybylski et al.](https://selfdeterminationtheory.org/wp-content/uploads/2014/04/2013_PrzybylskiMurayamaDeHaanGladwell_CIHB.pdf)

**구체 적용.** 광고에서는 "마감", "잔여 수량", "초대 전용"을 쓰기 전에 실제 제한 조건이 있어야 한다. Landing page에서는 scarcity를 CTA 근처에 배치하되, benefit 설명보다 앞세우지 않는다. Webinar, cohort, beta access는 "다음 cohort 대기"처럼 실제 운영 제약이 있을 때 강하다. Ecommerce에서는 inventory count가 실시간이면 구매 지연을 줄이는 cue가 될 수 있지만, fake countdown은 trust와 compliance risk를 만든다.

**예시.**

- Cohort course: "5월 cohort 12석 중 3석 남음" + "다음 live review는 6월 24일"은 시간과 좌석 제한을 모두 명확히 한다.
- Product-led growth beta: "Slack workflow builder beta: 이번 주 200팀만 onboarding"은 operational capacity를 근거로 scarcity를 만든다.

**주의.** Scarcity/FOMO는 urgency를 만들지만, 반복 노출되면 사용자가 학습해 무시한다. "항상 오늘 마감"인 countdown, 존재하지 않는 waitlist, 조작된 live activity feed는 쓰지 않는다. Social proof와 결합할 때는 FTC의 endorsement/review disclosure 및 fake review rule도 확인해야 한다. [FTC Endorsement Guides](https://www.ftc.gov/business-guidance/resources/ftcs-endorsement-guides-what-people-are-asking), [FTC Fake Reviews Final Rule](https://www.ftc.gov/news-events/news/press-releases/2024/08/federal-trade-commission-announces-final-rule-banning-fake-reviews-testimonials)

## 5. 사회적 증거 (social proof)

**무엇인가.** Social proof는 불확실한 상황에서 다른 사람, 특히 나와 비슷한 사람의 행동을 단서로 삼는 persuasion principle이다. Cialdini는 social proof를 "People follow the lead of similar others"로 설명하고, 만족 고객 testimonial은 prospective customer와 satisfied customer가 비슷한 상황을 공유할 때 더 잘 작동한다고 썼다. [Cialdini, HBR](https://www.influenceatwork.com/wp-content/uploads/2014/05/Harvard-Business-Review-.pdf)

**메커니즘 / 왜 작동하는가.** Social proof는 risk reduction cue다. 제품을 직접 써보기 전에는 vendor claim보다 peer behavior, review volume, recognizable logo, role-specific quote가 낮은 cognitive cost로 판단을 돕는다. 다만 FTC는 endorsement의 material connection disclosure를 요구할 수 있고, platform feature가 명확한 disclosure를 허용하지 않는 경우 advertiser가 그런 endorsement를 장려해서는 안 된다고 설명한다. [FTC Endorsement Guides](https://www.ftc.gov/business-guidance/resources/ftcs-endorsement-guides-what-people-are-asking)

**구체 적용.** 광고에는 "10,000 users" 같은 총량보다 segment match를 우선한다. 예: "Used by 320 Shopify Plus teams"는 ecommerce traffic에서 더 강한 cue다. Landing page의 proof block은 `logo strip -> role-specific quote -> measurable outcome -> review source` 순서가 좋다. CTA 주변에는 "이번 달 184팀이 onboarding 완료"처럼 최신성과 행동성을 주되, 집계 기간과 기준을 명시한다. CRO audit에서는 testimonial이 generic praise인지, buyer objection을 줄이는지, claim과 같은 화면에 있는지 확인한다.

**예시.**

- B2B landing: "CRM admins at 120+ seed-stage SaaS teams use this playbook"은 숫자보다 "나와 같은 팀" 신호를 준다.
- Checkout reassurance: "4.8/5 from 1,246 verified buyers" 옆에 refund policy를 두면 peer validation과 risk reversal이 함께 작동한다.

**주의.** Fake reviews, AI-generated fake testimonials, bought followers/views 같은 fake indicators는 FTC final rule의 금지 대상이다. Social proof는 실제 고객 경험, 검증 가능한 review source, 필요한 disclosure가 있을 때만 사용한다. [FTC Fake Reviews Final Rule](https://www.ftc.gov/news-events/news/press-releases/2024/08/federal-trade-commission-announces-final-rule-banning-fake-reviews-testimonials)

## 6. 시각적 위계 / 색채와 CTR

**무엇인가.** Visual hierarchy는 사용자의 시선을 페이지 안의 중요도 순서대로 유도하는 design principle이다. Nielsen Norman Group의 visual-design principles 자료는 scale을 중요도와 ranking 신호로, visual hierarchy를 눈이 다른 design element를 중요도 순서대로 보도록 유도하는 원칙으로 설명한다. 또한 중요한 항목에는 bright color, 덜 중요한 항목에는 muted color를 고려하라고 제안한다. [NN/g Visual Design Principles](https://media.nngroup.com/media/articles/attachments/Principles_Visual_Design-A4.pdf)

**메커니즘 / 왜 작동하는가.** CTR은 사용자가 CTA를 보고, 이해하고, 클릭할 이유를 느낄 때 올라간다. Visual hierarchy는 size, contrast, spacing, placement, color를 통해 "어디를 먼저 봐야 하는지"를 줄인다. 색 자체가 universal conversion color를 보장하지는 않는다. 더 중요한 것은 배경 대비, 주변 요소와의 contrast, CTA 주변 copy, intent match다. WCAG 2.2는 일반 text와 images of text의 contrast ratio를 최소 4.5:1, large-scale text를 3:1 이상으로 요구하며, color만 정보 전달 수단으로 쓰지 말라고 한다. [W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/)

**구체 적용.** Ad creative에서는 headline, product visual, CTA의 visual priority를 한 화면에서 3단계 이하로 만든다. Landing page에서는 primary CTA 색을 brand palette 안에서 가장 높은 functional contrast로 정하고, secondary CTA는 outline/text style로 낮춘다. Button color test는 "초록 vs 빨강"이 아니라 `CTA contrast`, `button label`, `section placement`, `surrounding whitespace`를 분리해 설계한다. Mobile에서는 first viewport에 H1, proof cue, primary CTA가 겹치지 않고 시각적 흐름이 명확해야 한다.

**예시.**

- Landing hero: H1 40px, subcopy 18px, primary CTA solid high-contrast, secondary CTA text-link로 두면 action priority가 명확하다.
- Ad thumbnail: 제품 화면을 가장 크게, discount badge를 두 번째, CTA chip을 세 번째로 두면 scan path가 단순해진다.

**주의.** "빨간 버튼이 항상 더 높다" 같은 보편 법칙은 검증하지 못했다. 색채는 contrast와 context의 함수로 다루고, 접근성 기준을 통과한 후보끼리 CTR test를 한다. [NN/g](https://media.nngroup.com/media/articles/attachments/Principles_Visual_Design-A4.pdf), [W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/)

## 7. 카피라이팅 공식 (AIDA, PAS, FAB 등)

**무엇인가.** Copywriting formula는 blank page 문제를 줄이는 message structure다. Practitioner reference는 AIDA를 `Attention -> Interest -> Desire -> Action`, PAS를 `Problem -> Agitate -> Solution`, FAB를 `Features -> Advantages -> Benefits`로 정리한다. [Kopywriting, 18 Copywriting Formulas](https://kopywriting.com/blogs/287-copywriting-formulas/) 이 공식들은 성과가 자동으로 보장되는 과학 법칙이 아니라 attention flow와 persuasion sequence를 빠르게 구성하는 template이다.

**메커니즘 / 왜 작동하는가.** AIDA는 처음에 attention을 확보하고, interest와 desire를 거쳐 action으로 이동시키는 funnel형 흐름이다. PAS는 problem-aware audience에서 pain salience를 높인 뒤 solution을 제시한다. FAB는 기능 설명을 buyer language로 번역한다. 즉, "무엇이 있는가(feature)"를 "그래서 어떻게 좋아지는가(advantage/benefit)"로 바꿔 cognitive effort를 줄인다. [Kopywriting](https://kopywriting.com/blogs/287-copywriting-formulas/)

**구체 적용.** Cold ad에는 AIDA가 적합하다. 첫 줄은 pattern interrupt, 둘째 줄은 relevance, 셋째 줄은 desired outcome, CTA는 next step이다. Search ad나 retargeting처럼 pain awareness가 높은 traffic에는 PAS가 빠르다. Product page, feature section, comparison page에는 FAB를 쓴다. CRO audit에서는 copy가 feature-only인지, problem만 있고 solution mechanism이 없는지, CTA가 action을 명확히 요구하는지 본다.

**예시.**

- AIDA ad: "보고서 취합이 금요일을 잡아먹나요?" -> "GA4, Meta, Google Ads를 한 화면에 묶습니다" -> "팀 미팅 전 10분 만에 weekly view 완성" -> "무료 workspace 만들기".
- FAB feature block: "Auto-tagging" -> "channel별 campaign naming을 자동 정리" -> "UTM 오류로 인한 attribution 누락을 줄임".

**주의.** PAS의 `Agitate`는 실제 pain을 명확히 하는 단계이지 공포를 과장하는 단계가 아니다. AIDA는 audience가 문제를 모르면 설명 공간이 더 필요하고, 이미 buying intent가 높으면 FAB나 comparison table이 더 유용할 수 있다. Copy formula 선택은 traffic temperature와 user awareness에 맞춘다. [Optimizely A/B testing](https://www.optimizely.com/optimization-glossary/ab-testing/)

## 8. A/B 테스트 실험 방법론

**무엇인가.** A/B testing은 webpage나 app의 두 version을 비교해 어느 쪽이 conversion goal에서 더 나은지 판단하는 방법론이다. Optimizely는 A/B test가 control(A)과 variation(B)을 만들고, traffic을 random split하며, engagement를 측정하고 결과를 분석하는 흐름이라고 설명한다. [Optimizely A/B testing](https://www.optimizely.com/optimization-glossary/ab-testing/) Kohavi et al.은 controlled experiment가 change와 user-observable behavior 사이의 causal relationship을 세우기 위한 과학적 설계라고 설명한다. [Kohavi et al.](https://link.springer.com/article/10.1007/s10618-008-0114-1)

**메커니즘 / 왜 작동하는가.** Randomization은 control과 treatment 간 사용자 차이를 평균적으로 균형화해 causal inference를 가능하게 한다. Statistical significance는 관측된 차이가 random chance인지 판단하는 도구이고, sample size와 statistical power는 작은 effect를 감지할 수 있는지 결정한다. Kohavi et al.은 web experiment에서 statistical power, sample size, variance reduction, randomization/hashing이 중요하다고 정리한다. [Kohavi et al.](https://link.springer.com/article/10.1007/s10618-008-0114-1)

**구체 적용.** 실험 전에는 `hypothesis`, `primary metric`, `guardrail metric`, `minimum detectable effect`, `sample size/runtime`, `stopping rule`을 문서화한다. CTR 실험은 impression-level randomization과 creative fatigue를 고려하고, landing conversion 실험은 user-level randomization과 session stitching을 확인한다. 한 번에 headline, offer, CTA color를 모두 바꾸면 어떤 요소가 원인인지 알기 어렵다. CTA color만 테스트한다면 label, 위치, traffic source를 고정한다. Segment 분석은 전체 결과가 나온 뒤 탐색적으로 보되, 작은 segment의 우연한 lift를 의사결정 근거로 쓰지 않는다.

**예시.**

- CTR test: Hypothesis "loss-framed headline이 benefit-framed headline보다 cold search ad CTR을 높인다." Primary metric CTR, guardrail CVR, split 50/50, runtime 7일 이상, creative 외 변수 고정.
- Landing test: Hypothesis "hero proof cue를 CTA 위에 두면 signup start rate가 오른다." Primary metric signup_start, guardrail paid_conversion, MDE 5%, user-level split.

**주의.** Optimizely는 statistical significance가 결과가 reliable한지 random chance인지 판단하는 데 쓰인다고 설명하며, sample size calculator는 관측하려는 effect에 따라 test duration planning에 쓰인다고 설명한다. Sequential testing이나 vendor-specific stats engine을 쓰지 않는다면 중간에 유리한 순간만 보고 멈추는 peeking은 false positive risk를 키울 수 있으므로 사전 stopping rule이 필요하다. [Optimizely A/B testing](https://www.optimizely.com/optimization-glossary/ab-testing/), [Optimizely sample size calculator](https://www.optimizely.com/sample-size-calculator/)

## 출처

1. Robert B. Cialdini, "Harnessing the Science of Persuasion", Harvard Business Review PDF: https://www.influenceatwork.com/wp-content/uploads/2014/05/Harvard-Business-Review-.pdf
2. Robert B. Cialdini and Noah J. Goldstein, "The Science and Practice of Persuasion", Cornell Hotel and Restaurant Administration Quarterly PDF: https://www2.psych.ubc.ca/~schaller/308Readings/Cialdini2002.pdf
3. Daniel Kahneman and Amos Tversky, "Prospect Theory: An Analysis of Decision under Risk": https://studylib.net/doc/28016460/kahneman-tversky-1979-prospect-theory
4. Nicholas Epley and Thomas Gilovich, "The Anchoring-and-Adjustment Heuristic: Why the Adjustments Are Insufficient": https://journals.sagepub.com/doi/abs/10.1111/j.1467-9280.2006.01704.x
5. Jose Carlos Schaidhauer Pacheco Junior, Claudio Damacena, Rafael Bronzatti, "Priming: the priming effect on consumer behavior research": https://pepsic.bvsalud.org/scielo.php?lng=en&pid=S1808-42812015000100016&script=sci_abstract
6. Andrew K. Przybylski, Kou Murayama, Cody R. DeHaan, Valerie Gladwell, "Motivational, emotional, and behavioral correlates of fear of missing out": https://selfdeterminationtheory.org/wp-content/uploads/2014/04/2013_PrzybylskiMurayamaDeHaanGladwell_CIHB.pdf
7. Federal Trade Commission, "FTC's Endorsement Guides: What People Are Asking": https://www.ftc.gov/business-guidance/resources/ftcs-endorsement-guides-what-people-are-asking
8. Federal Trade Commission, "Federal Trade Commission Announces Final Rule Banning Fake Reviews and Testimonials": https://www.ftc.gov/news-events/news/press-releases/2024/08/federal-trade-commission-announces-final-rule-banning-fake-reviews-testimonials
9. Nielsen Norman Group, "5 Visual-design Principles in UX" PDF: https://media.nngroup.com/media/articles/attachments/Principles_Visual_Design-A4.pdf
10. W3C, "Web Content Accessibility Guidelines (WCAG) 2.2": https://www.w3.org/TR/WCAG22/
11. Kopywriting, "18 Copywriting Formulas (Plus Examples of Each)": https://kopywriting.com/blogs/287-copywriting-formulas/
12. Optimizely, "What is A/B testing?": https://www.optimizely.com/optimization-glossary/ab-testing/
13. Optimizely, "Sample size calculator": https://www.optimizely.com/sample-size-calculator/
14. Ron Kohavi, Roger Longbotham, Dan Sommerfield, Randal M. Henne, "Controlled experiments on the web: survey and practical guide": https://link.springer.com/article/10.1007/s10618-008-0114-1
