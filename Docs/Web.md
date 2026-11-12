# Egg Dash Web

https://egg-dash-play.precioushelix2.chatgpt.site

브라우저에서 게임 시작 버튼을 눌러 플레이합니다. 휴대폰은 세로·가로 화면 모두에서 터치 이동·카메라·점프·달리기·USE 버튼을 사용합니다. 시작 화면의 **전체화면으로 시작** 또는 플레이 중 상단 **전체화면** 버튼으로 전환합니다. 화면 방향은 강제로 바꾸지 않습니다. 브라우저가 문서 전체화면 API를 지원하지 않으면 화면 채우기 모드를 사용하며 주소창은 남을 수 있습니다. 저장 데이터는 해당 브라우저의 사이트 저장 공간에 남고 PC/APK와 동기화하지 않습니다.

Godot 4.6.3 단일 스레드 WebAssembly 내보내기입니다. HTTPS, WebGL 2와 DecompressionStream을 지원하는 최신 브라우저가 필요합니다. 엔진은 gzip 약 9MB와 게임 데이터 약 2MB를 내려받습니다. 사이트는 Sites 소유자 전용으로 게시되어 ChatGPT 로그인이 필요할 수 있습니다.

## 재빌드

```bash
mkdir -p /absolute/path/dist/play
godot --headless --path Godot --export-release Web /absolute/path/dist/play/game.html
python Tools/package_web.py /absolute/path/dist
```

`package_web.py`는 엔진을 gzip으로 압축하고 시작 화면과 스트리밍 압축 해제 코드를 생성합니다. 한 번의 새 Godot export 이후 한 번 실행합니다. 모든 개별 정적 파일은 25MiB 미만입니다. 스레드/서비스 워커가 없어 COOP/COEP 헤더가 필요하지 않습니다.

## 검증

웹 내보내기 성공, JavaScript 구문 검사, 압축 무결성, WebAssembly 모듈 유효성 검사 및 Sites 배포 성공을 확인했습니다. 관리형 환경의 브라우저 조작 도구가 제공되지 않아 **실제 브라우저 플레이 검증은 수행하지 못했습니다.**

배포 소스는 별도 Sites 저장소이며, 이 GitHub 저장소에는 Godot 원본과 재현 가능한 웹 빌드 설정을 보관합니다.

세로 화면은 1080×1920, 가로 화면은 1920×1080 논리 해상도를 기준으로 배치합니다. 화면 크기 변경 시 자동 전환됩니다. 전체화면 진입·해제·WebKit API·미지원·거절 시 대체 동작은 Node 기반 DOM 모의 테스트로 검증했습니다. Godot 네이티브 렌더러에서도 세로 화면 배치를 확인했습니다. 실제 휴대폰 브라우저 검증은 아직 수행하지 못했습니다.
