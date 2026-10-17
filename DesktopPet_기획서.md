우사기 데스크톱 펫 기획서 (macOS)
2026년 10월 15일 · @경태
1. 개요
우사기 데스크톱 펫은 macOS 화면 위에 항상 떠 있는 투명 배경 캐릭터로, 클릭하면 옆에 ChatGPT 말풍선 창이 열리는 상주형 앱이다. 포토샵·유니티 작업 중에도 앱 전환 없이 ChatGPT를 바로 부르는 것이 목표다.
항목
결정
플랫폼
macOS 전용
기술
Swift 네이티브 (AppKit + SwiftUI)
ChatGPT 연결
chatgpt.com 웹뷰 임베드, 각자 본인 구독 계정으로 로그인
캐릭터
투명 배경 PNG 정지 이미지 1장 (usagi.png). GIF 애니메이션(usagi.gif)은 파일만 추가하면 지원
배포
지인 공유 (앱스토어·공개 배포 없음)
범위 밖: Windows 지원, 상태별/반응형 애니메이션(GIF 한 개 반복 재생만), OpenAI API 연동, 유료·공개 배포.
2. 핵심 기능
요청한 6가지 기능에, Dock 아이콘 없이 앱을 끄고 설정할 수단인 메뉴바 메뉴 하나를 더한다.
#
기능
동작
구현 포인트
1
항상 화면 위
포토샵·유니티 등 어떤 앱을 켜도 우사기가 위에 떠 있음. 데스크톱(Space)을 바꿔도 따라옴
NSPanel + level = .floating, collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary], 클릭해도 다른 앱 포커스를 뺏지 않도록 .nonactivatingPanel
2
배경 투명
우사기 이미지만 보이고 주변 사각형·그림자 없음. 투명한 부분은 클릭이 뒤 창으로 통과
테두리 없는 창, isOpaque = false, backgroundColor = .clear, hasShadow = false. 투명 픽셀 클릭 통과가 부족하면 이미지 알파값 기준 hit-test로 보완
3
자유 이동
우사기를 잡고 끌어 원하는 위치에 둠. 다음 실행 때 같은 자리에 나타남
mouseDragged로 이동, 이동 거리 4pt 이하면 클릭으로 판정. 위치는 UserDefaults에 저장, 모니터가 빠져 화면 밖이면 보이는 화면 안으로 보정
4
클릭하면 말풍선
우사기를 클릭하면 옆에 말풍선 모양 ChatGPT 창이 열림. 우사기를 옮기면 창도 따라감
별도 NSPanel(키 입력 가능) 안에 WKWebView로 chatgpt.com 로드. WKWebsiteDataStore.default()로 로그인 쿠키 유지. 화면 여백이 넓은 쪽(좌/우)에 배치
5
채팅창 닫기
닫기 버튼·Esc·우사기 재클릭으로 채팅창만 숨김. 우사기는 그대로
창을 파괴하지 않고 orderOut으로 숨김 → 다시 열면 보던 대화가 그대로 남음
6
부팅 시 자동 실행
로그인하면 자동으로 우사기가 나타남. 메뉴바에서 켜고 끔
SMAppService.mainApp.register() (macOS 13 이상). 첫 실행 때 기본값 켜짐
+
메뉴바 메뉴
Dock에 아이콘이 없으므로 메뉴바 아이콘으로 제어
LSUIElement = YES로 Dock 숨김. 메뉴: 우사기 보이기/숨기기, 크기, 로그인 시 실행, 위치 초기화, 종료
사용 흐름
1. Mac을 켜고 로그인하면 우사기가 마지막 위치에 나타난다.
2. 우사기를 끌어 작업에 방해되지 않는 구석에 둔다.
3. 우사기를 클릭하면 옆에 ChatGPT 창이 열린다. 처음 한 번만 ChatGPT에 로그인한다.
4. 질문하고, Esc나 우사기 클릭으로 창을 닫는다. 우사기는 그 자리에 남는다.
5. 다시 클릭하면 이전 대화가 그대로 열린다.
3. 기술 스택과 구조
외부 라이브러리 없이 Apple 기본 프레임워크만으로 만든다. 창 제어는 AppKit, 설정 화면처럼 단순한 UI만 SwiftUI로 쓴다.
항목
선택
이유
언어 / IDE
Swift, Xcode
네이티브 창 제어와 가벼운 상주 실행
최소 macOS
13 Ventura
자동 실행용 SMAppService가 13부터 지원. 2017년형 인텔 맥북프로도 Ventura까지 지원
빌드
Universal (Apple Silicon + Intel)
지인 Mac 칩 종류와 무관하게 실행
창
AppKit NSPanel 2개
투명·항상 위·포커스 비활성 등 세부 제어가 SwiftUI만으로는 어려움
채팅
WebKit WKWebView
구독 계정 그대로 chatgpt.com 사용
저장
UserDefaults
위치·크기·자동 실행 설정 정도라 DB 불필요
폴더 구조
UsagiPet/
├── App/            UsagiPetApp.swift, AppDelegate.swift (메뉴바, 앱 수명)
├── Character/      CharacterPanel.swift, CharacterView.swift (투명 창, 드래그, 클릭)
├── Chat/           ChatPanel.swift, ChatWebView.swift, BubbleShape.swift
├── Services/       LoginItemService.swift, PositionStore.swift
└── Resources/      usagi.png (또는 usagi.gif), Info.plist
캐릭터 이미지는 usagi.png 한 파일로 분리해, 파일만 바꾸면 다른 캐릭터로 교체되게 한다.
4. 화면과 조작
화면은 우사기 창, 말풍선 채팅창, 메뉴바 메뉴 세 가지뿐이다.
우사기 창
• 기본 크기 160pt, 메뉴에서 작게(120) · 보통(160) · 크게(220) 선택
• 첫 실행 위치는 주 모니터 오른쪽 아래, 이후엔 마지막 위치
• 마우스를 올리면 커서가 손 모양으로 바뀌어 잡을 수 있음을 알림
말풍선 채팅창
• 기본 크기 420 × 640pt, 가장자리를 끌어 크기 조절, 크기는 저장
• 우사기 옆 여백이 넓은 쪽에 열리고, 우사기를 가리키는 꼬리가 붙음
• 화면 아래로 넘치면 위로 밀어 올려 화면 안에 맞춤
• 상단 바: 새 대화 · 새로고침 · 닫기
조작 정리
동작
결과
우사기 클릭
채팅창 열기 / 닫기 토글
우사기 드래그
우사기 이동, 열린 채팅창도 함께 이동
채팅창에서 Esc 또는 닫기
채팅창만 숨김, 대화 유지
메뉴바 아이콘 클릭
보이기/숨기기, 크기, 로그인 시 실행, 위치 초기화, 종료
채팅 안 외부 링크 클릭
기본 브라우저에서 열림
5. 리스크와 대응
가장 큰 변수는 웹뷰 안에서의 ChatGPT 로그인이고, 다음이 지인 Mac에서의 첫 실행 경고다.
리스크
영향
대응
Google 계정 로그인 차단
Google은 2021년부터 WKWebView 안의 Google 로그인을 차단함(disallowed_useragent 오류). Google로 가입한 ChatGPT 계정은 이메일 로그인으로 바꿀 수 없음
1안 Safari User-Agent 지정, 실패 시 2안 공식 ChatGPT 앱 연동 (아래 상세)
봇 확인·로그인 반복
chatgpt.com 보안 확인 화면이 자주 뜨거나 로그인이 풀림
기본 데이터 저장소로 쿠키 영구 보관, Safari User-Agent 사용
파일 첨부 안 됨
웹뷰는 기본 설정만으론 이미지·파일 선택 창이 뜨지 않음
WKUIDelegate의 파일 선택(runOpenPanelWith) 구현
음성 대화 안 됨
마이크 권한이 없으면 음성 모드 실패
Info.plist에 마이크 사용 설명 추가, 웹뷰 미디어 권한 처리 (필요 시)
새 창 링크 무시
target=_blank 링크가 아무 반응 없음
새 창 요청은 기본 브라우저로 열기
전체화면 앱 위에 안 보임
유니티·포토샵 전체화면 시 우사기가 사라짐
.fullScreenAuxiliary + 포커스 비활성 패널
지인 Mac 첫 실행 경고
공증 안 된 앱은 "확인되지 않은 개발자"로 실행이 막힘
무료: 받는 사람이 시스템 설정 → 개인정보 보호 및 보안 → "그래도 열기". 유료 개발자 계정(연 $99) 시 서명·공증으로 경고 없음
캐릭터 저작권
우사기는 치이카와(나가노) 캐릭터
지인 소규모 비상업 공유로 한정, 판매·공개 배포 안 함. 이미지 파일 교체로 다른 캐릭터 사용 가능하게 설계
chatgpt.com 화면 변경
OpenAI가 웹 UI를 바꿈
웹을 그대로 띄우는 구조라 영향 적음. 말풍선 폭이 좁아 모바일 레이아웃으로 보일 수 있음
Google 로그인 대응 (Google 계정 사용 확정)
Google 로그인은 웹뷰에서 정책상 막혀 있고 로그인 방식도 바꿀 수 없으므로, 1안을 먼저 검증하고 실패하면 2안으로 전환한다.

1안: Safari User-Agent 지정 (기본)
2안: 공식 ChatGPT 앱 연동 (대안)
방식
웹뷰가 Safari인 것처럼 User-Agent를 바꿔 Google 로그인 화면 통과
우사기 클릭 시 ChatGPT 앱 창을 띄우고, 손쉬운 사용 권한으로 그 창을 우사기 옆으로 이동
로그인
웹뷰 안에서 처음 한 번
ChatGPT 앱이 처리, 문제 없음
말풍선 모양
그대로 유지
불가, ChatGPT 앱 창 그대로
지인 준비물
없음
ChatGPT 앱 설치 + 손쉬운 사용 권한 허용
위험
정책 우회라 Google이 감지 방식을 바꾸면 언제든 막힘
ChatGPT 앱 업데이트로 창 구조가 바뀌면 위치 이동이 어긋날 수 있음
1안이 통하는지는 코드 몇 줄로 바로 확인되므로, M2의 첫 작업으로 검증한다.
6. 개발 단계와 미결 사항
네 단계로 나눠, 각 단계가 끝날 때마다 실제로 써볼 수 있는 상태를 만든다. 기간은 개발용 Mac과 작업 시간이 정해지면 붙인다.
1. M1 우사기 창 — 투명 배경, 항상 위, 드래그 이동, 위치 저장
2. M2 채팅 말풍선 — 웹뷰로 chatgpt.com, Google 로그인 1안 검증(첫 작업), 로그인 유지, 클릭 토글, 우사기 따라 이동, 파일 첨부·새 창 링크 처리
3. M3 상주 앱화 — 메뉴바 메뉴, Dock 아이콘 숨김, 로그인 시 자동 실행
4. M4 다듬기와 배포 — 멀티 모니터·전체화면 대응, 앱 아이콘, Universal 빌드, 지인용 설치 안내
미결 사항
[ ] 우사기 투명 PNG 전달 → Resources/usagi.png 에 넣고 ./build.sh (512px 이상 권장). 나중에 GIF로 바꿀 땐 usagi.gif 추가 후 png 삭제
[ ] 개발에 쓸 Mac 기종과 macOS 버전 (Ventura면 Xcode 15까지 사용 가능)
[ ] Apple 유료 개발자 계정 사용 여부 (공증 여부 결정)
[ ] Google 로그인 1안 통과 여부 검증 → 실패 시 2안으로 기획 수정
[ ] 단축키로 우사기 부르기 등 추가 기능 필요 여부